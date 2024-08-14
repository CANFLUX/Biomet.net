# Create a CSV file from the binary database 
# Written by June Skeeter

# Basic test-call from command line:
    # py csvFromBinary.py --siteID BBS --dateRange "2023-06-01 00:00" "2024-05-31 23:59"
# Call with user defined request file (s)
    # py csvFromBinary.py --siteID BBS --dateRange "2023-06-01 00:00" "2024-05-31 23:59" --tasks C:/path_to/request1.yml C:/path_to/request2.yml
# Can also call from other python scripts, using this general syntax:
    # import csvFromBinary as cfb
    # cfb.makeCSV(siteID="BBS",dateRange=["2023-06-01 00:00","2024-05-31 23:59"],tasks=["config_files/csv_tasks_template.yml"])
# Setup the config files for your environment accordingly before running

import os
import argparse
import numpy as np
import pandas as pd
import readConfig as rCfg
from datetime import datetime,date

os.chdir(os.path.split(__file__)[0])

template = 'config_files/csv_from_binary.yml'
defaultDateRange = [date(datetime.now().year,1,1),datetime.now()]

# Create the csv
# args with "None" value provide option to overwrite default
# def makeCSV(siteID,dateRange=None,tasks=[template],stage=None,outputPath=None):
def makeCSV(siteID,**kwargs):
    # Default arguments
    defaultKwargs = {
        'dateRange':None,
        'database':None,
        'outputPath':None,
        'tasks':[template],
        'stage':None
        }
    
    # Apply defaults where not defined
    kwargs = defaultKwargs | kwargs
    tasks = kwargs['tasks']
    
    config = rCfg.set_user_configuration(tasks)
    # Use default if user does not provide alternative
    if kwargs['outputPath'] is None:
        outputPath = config['rootDir']['Outputs']
    else: outputPath = kwargs['outputPath']

    # Root directory of the database
    if kwargs['database'] is None:
        root = config['rootDir']['database']
    else: root = kwargs['database']

    if kwargs['dateRange'] is not None:
        Range_index = pd.DatetimeIndex(kwargs['dateRange'])
    else:
        Range_index = pd.DatetimeIndex(defaultDateRange)

    print(f'Initializing tasks for {siteID} over:', f"{Range_index.strftime(date_format='%Y-%m-%d %H:%M').values}") 
    
    # Years to process
    Years = range(Range_index.year.min(),Range_index.year.max()+1)

    results = {}
    for name,task in config['tasks'].items():

        if kwargs['stage'] is not None:
            task['stage']=config['stage'][kwargs['stage']]
        else:
            task['stage']=config['stage'][task['stage']]
        # Create a dict of traces
        traces={}
        # Create a list of column header - unit tuples
        # Only used if units_in_header set to True
        columns_tuple = []
        # Create a blank dataframe
        df = pd.DataFrame()
        
        file = f"{siteID}/{task['stage']}/{config['dbase_metadata']['timestamp']['name']}"
        tv = np.concatenate(
            [np.fromfile(f"{root}{YYYY}/{file}",config['dbase_metadata']['timestamp']['dtype']) for YYYY in Years],
            axis=0)
        DT = pd.to_datetime(tv-config['dbase_metadata']['timestamp']['base'],unit=config['dbase_metadata']['timestamp']['base_unit']).round('S')

        for time_trace,formatting in task['formatting']['time_vectors'].items():
            traces[time_trace] = DT.floor('Min').strftime(formatting['fmt'])
            # Add name-unit pairs to column header list
            columns_tuple.append(
                (formatting['output_name'],
                formatting['units'])
                )
        # Loop through race list for request
        for trace_name,trace_info in task['traces'].items():
            # if exists (over full period) output
            try:
                file = f"{siteID}/{task['stage']}/{trace_name}"
                trace = [np.fromfile(f"{root}{YYYY}/{file}",config['dbase_metadata']['traces']['dtype']) for YYYY in Years]
                traces[trace_name]=np.concatenate(trace,axis=0)
            # give NaN if traces does not exist
            except:
                print(f"{trace_name} missing, outputting NaNs")
                traces[trace_name]=np.empty(tv.shape)*np.nan
             # Add name-unit pairs to column header list
            columns_tuple.append((trace_info['output_name'],trace_info['units']))
        # dump traces to dataframe
        df = pd.DataFrame(data=traces,index=DT)
        # limit to requested timeframe
        df = df.loc[((df.index>=Range_index.min())&(df.index<= Range_index.max()))]

        # Apply optional resampling 
        # Add units to header (preferred) or exclude (dangerous)
        if task['formatting']['units_in_header'] == True:
            df.columns = pd.MultiIndex.from_tuples(columns_tuple)
        else:
            df.columns = [c[0] for c in columns_tuple]

        if 'resample' in task['formatting']:
            ### Finish stuff here
            aggregation = task['formatting']['resample']['agg'].split(',')
            # Text and numeric data must be treated differently
            # For text dates, get the first value
            txt = df.columns[:len(task['formatting']['time_vectors'].keys())]
            rsmp = df[txt].resample(task['formatting']['resample']['freq']).agg('first')
            rsmp=rsmp.T.set_index(np.repeat('', rsmp.shape[1]), append=True).T

            # For numeric data, aggregate as desired
            num = df.columns[len(task['formatting']['time_vectors'].keys()):]
            rsmp2 = df[num].resample(task['formatting']['resample']['freq']).agg(aggregation)
            df = rsmp.join(rsmp2)
            # Drop aggregation defs if excluding units    
            if task['formatting']['units_in_header'] == False:
                df.columns = df.columns.get_level_values(0)

        # Set specified NaN value or drop from dataset
        if task['formatting']['na_value'] is None:
            df = df.dropna()
        else:
            df = df.fillna(task['formatting']['na_value'])

        # Format filename and save output
        dates = Range_index.strftime('%Y%m%d%H%M')
        fn = f"{siteID}_{name}_{dates[0]}_{dates[1]}"
        if os.path.isdir(outputPath) == False:
            os.makedirs(outputPath)
        dout = f"{outputPath}/{fn}.csv"
        df.to_csv(dout,index=False)

        print(f'See output: {dout}')
        results[name]=dout
    print('All tasks completed successfully')
    return(results)

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
        "--dateRange", 
        nargs='+', # 1 or more values expected => creates a list
        type=str,
        default=[defaultDateRange],
        )
        
    CLI.add_argument(
        "--database", 
        nargs='+', # 1 or more values expected => creates a list
        type=str,
        default=None
        )
        

    CLI.add_argument(
        "--tasks", 
        nargs='+',
        type=str,
        default=[template],
        )
      
    CLI.add_argument(
        "--outputPath", 
        nargs='?',
        type=str,
        default=None,
        )
    
    CLI.add_argument(
        "--stage", 
        nargs='?',
        type=str,
        default=None,
        )

    # Parse the args and make the call
    args = CLI.parse_args()


    kwargs = {
        'dateRange':args.dateRange,
        'database':args.database,
        'outputPath':args.outputPath,
        'tasks':args.tasks,
        'stage':args.stage
        }
    
    makeCSV(args.siteID,**kwargs)