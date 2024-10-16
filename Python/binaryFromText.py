# Create a set of binary database files from a delimited text file
# Written by June Skeeter

import os
import json
import shutil
import fnmatch
import argparse
import numpy as np
import pandas as pd
import readConfig as rCfg
from datetime import datetime,date

numerics = ['int16', 'int32', 'int64', 'float16', 'float32', 'float64']

class writeTraces():
    def __init__(self,siteID,inputFile,inputFileMetaData,**kwargs):
        # Default arguments
        defaultKwargs = {
            'database':None,
            'writeCols':None,
            'excludeCols':[],
            'mode':'nafill',
            'stage':'Flux',
            'tag':'',
            'verbose':True
            }
        # Apply defaults where not defined
        self.kwargs = defaultKwargs | kwargs
        self.siteID = siteID
        self.config = rCfg.set_user_configuration()
        if self.kwargs['database'] is not None:
            self.config['rootDir']['database'] = self.kwargs['database']
        if self.kwargs['stage'] in self.config['stage'].keys():
            self.kwargs['stage'] = self.config['stage'][self.kwargs['stage']]
        if 'parse_dates' in inputFileMetaData and type(inputFileMetaData['parse_dates'])==list:
            val = inputFileMetaData['parse_dates']
            key = tuple(['TIMESTAMP']+['' for i in range(len(inputFileMetaData['header'])-1)])
            inputFileMetaData['parse_dates'] = {key:val}
        df = pd.read_csv(inputFile,**inputFileMetaData)
        df.columns = df.columns.get_level_values(0)   
        df.index = df['TIMESTAMP']
        if self.kwargs['writeCols'] is not None:
            df = df[self.kwargs['writeCols']]
        else:
            cols = [c for c in df.columns if c not in [b for a in self.kwargs['excludeCols'] for b in fnmatch.filter(df.columns,a)]]
            df = df[cols].copy()    
        self.df = df.select_dtypes(include=numerics)
        self.padFullYear()

    def padFullYear(self):
        for self.y in self.df.index.year.unique():
            self.Year = pd.DataFrame(
                data={'TIMESTAMP':pd.date_range(
                    start = f'{self.y}01010030',
                    end=f'{self.y+1}01010001',
                    freq=self.config['dbase_metadata']['timestamp']['resolution']
                    )})
            self.Year = self.Year.set_index('TIMESTAMP')
            self.Year = self.Year.join(self.df)
            epoch = datetime(1970,1,1,0,0)
            self.Year['Floor'] = self.Year.index.floor(self.config['dbase_metadata']['timestamp']['base_unit'])
            secsPerBase = pd.Timedelta('1'+self.config['dbase_metadata']['timestamp']['base_unit']).total_seconds()
            self.Year['frac'] = ((self.Year.index-self.Year['Floor']).dt.seconds/secsPerBase)
            self.Year['base'] = np.floor((self.Year.index-epoch).total_seconds()/secsPerBase+int(self.config['dbase_metadata']['timestamp']['base']))
            self.Year[self.config['dbase_metadata']['timestamp']['name']] = self.Year['frac']+self.Year['base']
            self.Year = self.Year.drop(columns=['Floor','frac','base'])
            self.write()
        
    def write(self):
        db = f"{self.config['rootDir']['database']}/{self.Year.index.year[0]}/{self.siteID}/{self.kwargs['stage']}/"
        if self.kwargs['mode'].lower() == 'overwrite' and os.path.isdir(db):
            print(f'Overwriting all contents of {db}')
            shutil.rmtree(db)
            os.mkdir(db)
        elif os.path.isdir(db) == False:
            print(f"{db} does not exist, creating new directory")
            os.makedirs(db)
        for traceName in self.Year.columns:
            if traceName == self.config["dbase_metadata"]["timestamp"]["name"]:
                dt = self.config["dbase_metadata"]["timestamp"]["dtype"]
            else:
                dt = self.config["dbase_metadata"]["traces"]["dtype"]
            fvar = self.Year[traceName].astype(dt).values
            traceName = self.charRep(traceName)
            tracePath = f"{db}{traceName}"
            if os.path.isfile(tracePath):
                trace = np.fromfile(tracePath,dt)
                if self.kwargs['verbose'] == True:
                    print(f'{tracePath} exists, {self.kwargs["mode"]} existing file')
            else:
                if self.kwargs['verbose'] == True:
                    print(f'{tracePath} does not exist, writing new file')
                trace = np.empty(self.Year.shape[0],dtype=dt)
                trace[:] = np.nan
            if self.kwargs['mode'].lower() == 'nafill':
                trace[np.isnan(trace)] = fvar[np.isnan(trace)]
            elif self.kwargs['mode'] == 'repfill':
                trace[~np.isnan(fvar)] = fvar[~np.isnan(fvar)]
            elif self.kwargs['mode'] == 'replace' or self.kwargs['mode'] == 'overwrite':
                trace = fvar
            trace.tofile(tracePath)
            
    def charRep(self,traceName):
        # Based on renameFields in fr_read_generic_data_file by @znesic, except:
        #   * is replaced with "start" instead of "s"
        #   ( is replaced with ""''"" instead of "_"
        repKey = {'_':[' ','-','.','_','/'],
                  'star':['*'],
                  '':['(',')'],
                  'p':['%'],
                  }
        if self.kwargs['tag'] != '':
            traceName = f"{traceName}_{self.kwargs['tag']}"
        for key,value in repKey.items():
            for val in value:
                traceName = traceName.replace(val,key)
        return(traceName)
    
# If called from command line ...
if __name__ == '__main__':
    
    CLI=argparse.ArgumentParser()
    
    CLI.add_argument(
        "--siteID", 
        nargs="?",# Use "?" to limit to one argument instead of list of arguments
        type=str,
        default='BB',
        )
    
    CLI.add_argument(
        "--inputFile", 
        nargs="?",# Use "?" to limit to one argument instead of list of arguments
        type=str,
        default=None,
        )

    CLI.add_argument(
        "--inputFileMetaData", 
        nargs="?",# Use "?" to limit to one argument instead of list of arguments
        type=str,
        default=None,
        )

    CLI.add_argument(
        "--database", 
        nargs='?', # 1 or more values expected => creates a list
        type=str,
        default=None
        )
    
    CLI.add_argument(
        "--writeCols", 
        nargs='+', # 1 or more values expected => creates a list
        type=str,
        default=None
        )
        
    CLI.add_argument(
        "--excludeCols", 
        nargs='+', # 1 or more values expected => creates a list
        type=str,
        default=['']
        )
        

    CLI.add_argument(
        "--stage", 
        nargs='?',
        type=str,
        default='Flux',
        )
    
    CLI.add_argument(
        "--mode", 
        nargs='?',
        type=str,
        default='nafill',
        )

    CLI.add_argument(
        "--tag", 
        nargs='?',
        type=str,
        default='',
        )

    # Parse the args and make the call
    args = CLI.parse_args()

    print(args.stage)

    kwargs = {
        'database':args.database,
        'writeCols':args.writeCols,
        'excludeCols':args.excludeCols,
        'stage':args.stage,
        'mode':args.mode,
        'tag':args.tag
        }
    
    inputFileMetaData = json.loads(args.inputFileMetaData)


    writeTraces(args.siteID,args.inputFile,inputFileMetaData,**kwargs)
