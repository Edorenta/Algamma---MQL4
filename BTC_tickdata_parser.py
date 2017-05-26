#this Python code aims at translating http://api.bitcoincharts.com/v1/csv/ free historical tick data
#in the following code, we will consider the tick data to be coinbase BTCUSD

#libs to include
import pandas as pd
import numpy as np
import datetime

#defining variables
timeframe = "1Min"        #pandas readable tf (xMin)
date_start = "20150630"   #start date as of YYYYMMDD
date_end = "20170524"     #end date as of YYYYMMDD

#pandas csv import
df1 = pd.read_csv('coinbaseUSD.csv', names=['unix_dt', 'last', 'volume'], header=None)
#if import was csv and not through pandas:
#gmt_dts = datetime.datetime.fromtimestamp(df1['unix_dt']).strftime('%Y-%M-%D %H:%M:%S')

#new lean dataset
df1['datetime']=pd.to_datetime(df1['unix_dt'], unit='s')
df2 = df1.set_index('datetime') #restructure dataframe to datetime
del df2['unix_dt']
df2.parse_date = True

#extract the csv as reworked dates
#df2.to_csv('coinbaseUSD_tick_datetime.csv', sep=',', encoding='utf-8')

#build OHLC from df2
df3 = df2['last'].resample(timeframe).ohlc()

#from custom date to 2017/05/24
df4 = df3[date_start:date_end]

#extract the csv as reworked dates
df4.to_csv('coinbaseUSD_1min.csv', sep=',', encoding='utf-8')
