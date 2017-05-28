
'''
        .=====================================.
       /         Algorithm Optimizer:          \
      {            MA reversed Slope            }
       \             by Edorenta               /
        '====================================='
'''
#in this version of my optimizer we will focus on a mean-reversion strategy:
#we get into the market as soon as a certain divergence degree is reached between the instrument selected price and its moving average
#the results are then ploted using pylab and matplot lib

#libs to include
import pandas as pd
import numpy as np
import numpy.random as nrand
import talib as ta
from math import sqrt
import matplotlib.pyplot as plt
from pylab import *
import datetime

#import risklib as rsk

#input variables
import_dir = "data_frame\\historical_data\\"
export_dir = "data_frame\\technical_analysis\\"
file_name = "DAXEUR_M5.csv" #instrument historical dt ohlc vol to load
digits = 5
spread_pts = 20
timeframe = 5 #in minutes to annualize

#download data into DataFrame and create moving averages columns
histo = pd.read_csv(import_dir + file_name, names=['datetime','open','high','low','close','volume'], header=0, index_col=0)

start_date = histo.index[0]
end_date = histo.index[-1]
dt_window = (pd.to_datetime(end_date, infer_datetime_format=True, format = '%M') - pd.to_datetime(start_date, infer_datetime_format=True, format = '%M')).total_seconds()
dt_window = dt_window/(60*timeframe)
histo_len = len(histo.index)
#print(histo.head(), histo_len)

#time_frame_mutliplier = np.round(dt_window/histo_len,5)
nb_histo_y = dt_window/((365*24*(60/timeframe))) #years on test in the history
data_per_year = round(histo_len/nb_histo_y,0) #ohlc per tradable year (rougly 252 days) => necessary for annualization

#other way:
#>> least_recent_date = df['StartDate'].min()
#>> recent_date = df['StartDate'].max()

#spread conversion
spread = spread_pts/(10^digits) #the bid/ask will only be computed on testing not to waste CPU

#dt = histo['datetime']
open = histo['open']
high = histo['high']
low = histo['low']
close = histo['close']
volume = histo['volume']
diff = close-open

'''   .-----------------------.
      |    RISKLIB EXTRACT    | => optimization criteria lay on these indicators
      '-----------------------'
'''
#Sharpe Ratio function - Risk free rate excluded for simplicity
def annualised_sharpe(returns, tradable_days):
    vol = np.std(returns)
    if (vol == 0):
        vol = 0.01
    return np.sqrt(tradable_days) * (np.mean(returns) / vol) #annualized (expected return)/vol

#DD & Max DD
def max_dd(returns):
    #Returns the maximum draw-down for any ti in (0, T) where T is the length of the return sRpies
    max_DD = float('-inf')
    for i in range(0, len(returns)):
        drawdown_i = dd(returns, i)
        if drawdown_i > max_DD:
            max_DD = drawdown_i
    #Max draw-down should be positive
    return abs(max_DD)

def dd(returns, ti): #local max drawdown
    #Returns the draw-down given time pRpiod ti
    values = prices(returns, 100)
    pos = len(values) - 1
    pre = pos - ti
    drawdown = float('+inf')
    #Find the maximum drawdown given ti
    while pre >= 0:
        dd_i = (values[pos] / values[pre]) - 1
        if dd_i < drawdown:
            drawdown = dd_i
        pos, pre = pos - 1, pre - 1
    #Drawdown should be positive
    return abs(drawdown)

def prices(returns, base):
    #Converts returns into prices
    s = [base]
    for i in range(len(returns)):
        s.append(base * (1 + returns[i]))
    return np.array(s)

'''   .-----------------------.
      |    ALGORITHM LOGIC    | => first import indicators (custom or from TA-lib), then store it all in a pandas dataframe
      '-----------------------'
'''
def strat_logic(ma1_p):
    #pandas dataframe to series (i.e. np) to be readable by TA-Lib
    #MA + its slope
    histo['ma1'] = np.round(ta.SMA(close.values, ma1_p),digits+2)
    histo['slope'] = (histo['ma1']-histo['ma1'].shift(1))/histo['ma1']
 
    #set desired number of points as threshold for spread difference (divergence) and create column containing strategy directional stance
    #divergence = +/-1/(10^digits)
    #divergence = div_x*10^(-5)
    histo['direction'] = np.where(histo['slope'] >= 0, -1, 0)
    histo['direction'] = np.where(histo['slope'] < 0, 1, histo['direction'])
    histo['direction'].value_counts()

    #print(histo['ma1'], histo['slope'])

#     .-----------------------.
#     |    HANDLE RETURNS     |
#     '-----------------------'
#
    #create columns containing daily mkt & str candle log returns
    histo['Market Returns'] = np.log(histo['close'] / histo['close'].shift(1))
    histo['Strategy Returns'] = histo['Market Returns'] * histo['direction'].shift(1)

    #print(histo['direction'], histo['Market Returns'], histo['Strategy Returns'])

    #create columns containing daily mkt & str candle absolute pts return
    histo['Market Shift'] = histo['close'] - histo['close'].shift(1)
    histo['Strategy Shift'] = histo['Market Shift'] * histo['direction'].shift(1)

    #include spread if trade
    #if histo['direction'].shift(1) != histo['direction']:
    #histo['Strategy Shift'] = histo['Strategy Shift'] - (spread_pt/(10^digits))/2

    #set strategy starting equity to 1 (i.e. 100%) and generate equity curve
    histo['Strategy TR'] = histo['Strategy Returns'].cumsum() + 1
    histo['Benchmark TR'] = histo['Market Returns'].cumsum() + 1
 
    histo['Strategy AR'] = histo['Strategy Shift'].cumsum() + 1
    histo['Benchmark AR'] = histo['Market Shift'].cumsum() + 1

    #series of daily returns for risklib calls
    histo_d_series = [histo['Strategy Returns'], histo['Market Returns']]
    #concatenate to get 1 table
    histo_d = pd.concat(histo_d_series, axis=1, ignore_index=False)
    histo_d.columns=['Strategy DTR','Market DTR']

    #histo_d.reset_index(level=0, inplace=True)
    histo_d['datetime'] = histo_d.index
    histo_d['datetime'] = pd.to_datetime(histo_d['datetime'])
    histo_d = histo_d.set_index(['datetime'])

    #histo_d.index = datetime.datetime.strftime(histo_d.index, "%A")
    histo_d = histo_d.resample('24H').agg({'Strategy DTR': 'sum', 
                                           'Market DTR': 'sum'})
    histo_d = histo_d.dropna() #take the NaN out of the dataset, i.e. Sundays
    traded_days = len(histo_d.index)
    #print(histo, histo_d, traded_days)

    #extected returns translation, median approximation to avoid fat tails corruption:
    Rp = histo['Strategy Returns'].median()
    Rm = histo['Market Returns'].median()
    
    #expected daily returns:
    data_per_day = data_per_year*nb_histo_y/(traded_days) #corr tradable day, better than using 252
    Rpd = data_per_day*Rp
    Rmd = data_per_day*Rm

    #ending absolute return as instrument points
    Rp_pts = histo['Strategy AR'].iloc[-1]
    Rm_pts = histo['Benchmark AR'].iloc[-1]

    #print(histo['Strategy TR'])
    y_tradable = np.round((dt_window/traded_days),0)
    sharpe_strat = annualised_sharpe(histo_d['Strategy DTR'], y_tradable)
    max_ddr_ratio = histo['Strategy TR'].cumsum()[-1]/max_dd(histo_d['Strategy DTR'])
    return (histo['Strategy TR'].cumsum()[-1], sharpe_strat, max_ddr_ratio)

'''   .-----------------------.
      |  NUMPY OPTIMIZATION   | => optimization made possible through the linspace usage, generic solver
      '-----------------------'
'''
#run the previously genericly coded function on np linspaces
ma1 = np.linspace(20,200,5,dtype=int)

#set series with dataframe length for risk/reward indicator storage
results_pnl = np.zeros((len(ma1)))
results_sharpe = np.zeros((len(ma1)))
results_max_ddr = np.zeros((len(ma1)))

'''   .------------------------.
      | LOGIC LOOP IN LINSPACE |
      '------------------------'
'''
for i, ma_pass in enumerate(ma1):
    pnl, sharpe, max_ddr = strat_logic(ma_pass)
    results_pnl[i] = pnl
    results_sharpe[i] = sharpe
    results_max_ddr[i] = max_ddr
    print("Pass: [%s] Results: [P&L: %s Sharpe: %s Return/Max Drawdown: %s]" %(ma_pass, pnl, sharpe, max_ddr))

'''   .-----------------------.
      |     PLOT RESULTS      |
      '-----------------------'
'''
font1= {'family': 'serif',
    'color':  'black',
    'weight': 'normal',
    'size': 12,
    }
font2= {'family': 'serif',
    'color':  'black',
    'weight': 'normal',
    'size': 10,
    }

plt.figure(1)
figure(1).suptitle("Risk Reward Multiple Criteria Optimization",fontdict=font1)

subplot(221)
y1 = results_sharpe
x1 = ma1
scatter(x1,y1)
#title('Sharpe Optimization', fontdict=font)
ylabel('Sharpe Ratio', fontdict=font2)
xlabel('MA Period', fontdict=font2)
plt.margins(0.2)
# Tweak spacing to prevent clipping of tick-labels
plt.subplots_adjust(bottom=0.15)

subplot(222)
y2 = results_pnl
x2 = ma1
scatter(x2,y2)
#title('Profit Optimization', fontdict=font)
ylabel('Return', fontdict=font2)
xlabel('MA Period', fontdict=font2)
plt.margins(0.2)
# Tweak spacing to prevent clipping of tick-labels
plt.subplots_adjust(bottom=0.15)

subplot(223)
y3 = results_max_ddr
x3 = ma1
scatter(x3,y3)
#title('RMDD Optimization', fontdict=font)
ylabel('RMDD Ratio', fontdict=font2)
xlabel('MA Period', fontdict=font2)
plt.margins(0.2)
# Tweak spacing to prevent clipping of tick-labels
plt.subplots_adjust(bottom=0.15)

plt.show()
