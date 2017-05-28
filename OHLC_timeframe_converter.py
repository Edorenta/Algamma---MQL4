'''
        .=====================================.
       /        OHLC Timeframe Converter       \
      {                 Algamma                 }
       \              by Edorenta              /
        '====================================='
'''
#the new file will be saved in the same directory as the source

# file #libs to include
import pandas as pd
import numpy as np
import datetime
from datetime import datetime

#input variables
import_dir = "historical_data\\"
export_dir = "historical_data\\"
file_name = "generic_BTCUSD_1min.csv" #check for file before you execute
timeframe = '5min'                                     #xhour, xmin, xsec
date_start = "20150630"
date_end = "20170524"

#string processing functions
def left(s, amount):
    return s[:amount]

def right(s, amount):
    return s[-amount:]

def mid(s, offset, amount):
    return s[offset:offset+amount]

#pandas csv import
df = pd.read_csv(import_dir + file_name, names=['datetime','open','high','low','close','volume'], header=0, index_col=0)
df.index = pd.to_datetime(df.index, format= '%y-%m-%d %H:%M:%S', infer_datetime_format=True)
df = df.resample(timeframe).agg({'open': 'first', 
                            'high': 'max', 
                            'low': 'min', 
                            'close': 'last',
                            'volume': 'sum'})

#custom date range export
df4 = df3[date_start:date_end]

#name and create csv with new ohlc
fname = left(file_name, len(file_name)-8)
export_name = "%s%s%s.csv" %(export_dir, fname, timeframe)
print(export_name)
df.to_csv(export_name, sep=',' ,encoding ='utf-8', index=True)
