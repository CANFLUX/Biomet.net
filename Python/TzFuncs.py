from tzfpy import get_tz
from datetime import *
import pandas as pd
import argparse
import pytz

class Tzfuncs():
    # Takes an input timezone or auto-determines a (DST aware) timezone from lat/lon coordinates
    # Will convert to TZ aware "UTC_time" and "Local_Time" along with non-TZ aware / non DST "Standard_Time"

    def __init__(self,Time_Zone=None,lat_lon=None,DST=False,from_UTC=False,to_UTC=False,Dates=None):
        self.DST,self.from_UTC,self.to_UTC = DST,from_UTC,to_UTC

        if Time_Zone is not None:
            self.Time_Zone = pytz.timezone(Time_Zone)
        elif lat_lon is not None:
            self.AssumeTZ(lat_lon[1],lat_lon[0])
        else:
            print(f'No Time Zone Info Provided')
        if Dates is not None:
            if isinstance(Dates,list):
                Dates = pd.DatetimeIndex(Dates)
            self.convert(Dates)

    def AssumeTZ(self,lon,lat):
        print(f'Timezone not provided, estimating for {lon}, {lat}')
        self.Time_Zone = pytz.timezone(get_tz(lon,lat))
        print(f'Assumed timezone is: {self.Time_Zone}')

    def convert(self,Input_Time):
        if isinstance(Input_Time,pd.DatetimeIndex):
            Input_Time=Input_Time.to_series()
        if self.from_UTC == False:
            self.Local_Time=Input_Time
            self.to_StandardTime()
        else:
            self.UTC_Time=Input_Time
            self.fromUTC()

    def to_StandardTime(self):
        offset = self.Local_Time.apply(lambda x: self.Time_Zone.dst(x,is_dst=self.DST))
        if self.DST == True:
            self.Standard_Time = pd.DatetimeIndex(self.Local_Time-offset)
            self.Local_Time = self.Local_Time.apply(lambda x: self.Time_Zone.localize(x,is_dst=self.DST))
        else:
            self.Standard_Time = pd.DatetimeIndex(self.Local_Time)
            self.Local_Time = (self.Local_Time+offset).apply(lambda x: self.Time_Zone.localize(x,is_dst=self.DST))
        if self.to_UTC == True:
            self.toUTC()
        self.Local_Time = pd.DatetimeIndex(self.Local_Time)

    def toUTC(self):
        self.UTC_Time = pd.DatetimeIndex(self.Local_Time.apply(lambda x: x.astimezone(pytz.utc)))

    def fromUTC(self):
        self.UTC_Time = self.UTC_Time.apply(lambda x: pytz.utc.localize(x, is_dst=self.DST))
        self.Local_Time = self.UTC_Time.apply(lambda x: x.astimezone(self.Time_Zone).replace(tzinfo=None))
        self.to_UTC=False
        self.to_StandardTime()
        self.UTC_Time = pd.DatetimeIndex(self.UTC_Time)

# If called from command line ...
if __name__ == '__main__':
    
    CLI=argparse.ArgumentParser()
    
    CLI.add_argument(f"--Time_Zone",type=str,nargs=1,default=None)
    CLI.add_argument(f"--lat_lon",type=float,nargs=2,default=None)
    CLI.add_argument(f"--DST",type=bool,nargs=1,default=None)
    CLI.add_argument('Dates',nargs=argparse.REMAINDER)

    # parse the command line
    args = CLI.parse_args()
    kwargs = vars(args)
    tz = Tzfuncs(**kwargs)