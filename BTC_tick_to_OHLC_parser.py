
#this Python code aims at translating http://api.bitcoincharts.com/v1/csv/ free historical tick data into custom OHLC
#in the following code, we will consider the tick data to be coinbase BTCUSD
#the output sample can be found as .csv in the same repository

#libs to include
import pandas as pd
import numpy as np
import datetime

#input variables
date_start = "20150630"
date_end = "20170524"
timeframe = "1Min"
import_dir = "sources\\crypto\\"
export_dir = "historical_data\\"
file_name = "coinbaseUSD.csv" #of the existing raw tick datafile
curr = "BTCUSD" #exported currency tag

#pandas csv import
df1 = pd.read_csv(file_name, names=['unix_dt', 'last', 'volume'], header=None)
#if import was csv and not through pandas:
#gmt_dts = datetime.datetime.fromtimestamp(df1['unix_dt']).strftime('%Y-%M-%D %H:%M:%S')

#new lean dataset
df1['datetime']=pd.to_datetime(df1['unix_dt'], unit='s')
df2 = df1.set_index('datetime') #restructure dataframe to datetime
del df2['unix_dt']
df2.parse_date = True

#extract the csv as reworked dates
#df2.to_csv('coinbaseUSD_tick_datetime.csv', sep=',', encoding='utf-8')

#build OHLC from df2 names=['date time','open','high','low','close']
px = df2['last'].resample(timeframe).ohlc()
vol = df2['volume'].resample(timeframe).sum()
df3 = pd.concat([px, vol], axis=1)
#quick and dirty way:
#df3 = df2['last'].resample(timeframe, how={'price'ohlc()

#cleanup the data
df3 = df3.replace(0, np.NaN).ffill() #give 0 value NaN, missquotes
df3 = df3.dropna(axis=0, how='any', thresh=None, subset=None, inplace=False) #take the NaN out of the dataset

#could have been used to cut na off
#df3 = df3.dropna(axis=0, how='any', thresh=None, subset=None, inplace=False) #take the NaN out of the dataset
#from custom date to 2017/05/24
df4 = df3[date_start:date_end]

#extract the csv as reworked OHLC
fname = left(file_name, len(file_name)-7)
export_name = "%s%s_%s_%s.csv" %(export_dir, fname, curr, timeframe)
print(export_name)
df4.to_csv(export_name, sep=',', encoding='utf-8')
