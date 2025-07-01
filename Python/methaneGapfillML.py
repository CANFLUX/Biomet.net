import yaml
import numpy as np
import argparse
import fluxgapfill
from pathlib import Path
import shutil
import hashlib
import pandas as pd
import os
import json

os.chdir(os.path.split(__file__)[0])
DEFAULT_CONFIG_FILE = Path('./config_files/CH4_ML_Gapfill_default.yml')

# Aliases
PREPROCESS = 1
TRAIN = 2
TEST = 3
GAPFILL = 4

def main(args):
    db_path = Path(args.db_path)
    config = create_config(args)

    dfs_by_year = read_database_traces(db_path, config)
    stages_to_run = get_stages_to_run(db_path, dfs_by_year, config)
    df_all = pd.concat(list(dfs_by_year.values()), axis=0).sort_index()
    site_path = db_path / 'methane_gapfill_ml' / args.site

    if PREPROCESS in stages_to_run:
        setup_and_preprocess(site_path, dfs_by_year, config)
    
    if TRAIN in stages_to_run:
        predictors = [str(Path(p).stem) for p in config['predictor_traces']]
        fluxgapfill.train(site_path, df_all, config['models'], predictors)

    if TEST in stages_to_run:
        fluxgapfill.test(site_path, df_all, config['models'])
    
    ml_dir = db_path / args.year / args.site / 'Clean' / 'ThirdStage_ML'
    os.makedirs(ml_dir, exist_ok=True)
    for model in config['models']:
        df_gapfilled = fluxgapfill.gapfill(site_path, dfs_by_year[args.year], [model])
        fch4_f = df_gapfilled['FCH4_F'].values.astype(config['dbase_metadata']['traces']['dtype'])
        fch4_f_u = df_gapfilled['FCH4_F_UNCERTAINTY'].values.astype(config['dbase_metadata']['traces']['dtype'])

        fch4_f.tofile(ml_dir / f'FCH4_F_ML_{model.upper()}')
        fch4_f_u.tofile(ml_dir / f'FCH4_F_ML_{model.upper()}_UNCERTAINTY')


def create_config(args) -> dict:
    '''Creates a configuration dictionary for the pipeline.
       Reads in the default config, then updates using a custom config in TraceAnalysis_ini / CH4_ML_Gapfill.yml
       Then updates with a site-specific config if it exists - in TraceAnalysis_ini / {site} / CH4_ML_Gapfill.yml
    '''
    trace_analysis_ini_path = Path(args.db_path) / 'Calculation_Procedures' / 'TraceAnalysis_ini'
    with open(DEFAULT_CONFIG_FILE, 'r') as f:
        config = yaml.safe_load(f)
    site = args.site
    config['site'] = site
    
    custom_config_path = trace_analysis_ini_path  / 'CH4_ML_Gapfill.yml'
    if os.path.exists(custom_config_path):
        with open(custom_config_path, 'r') as custom_ml_comfig_file:
            config.update(yaml.safe_load(custom_ml_comfig_file))
    
    site_config_path = trace_analysis_ini_path / site / 'CH4_ML_Gapfill.yml'
    if os.path.exists(site_config_path):
        with open(site_config_path, 'r') as site_ml_config_file:
            config.update(yaml.safe_load(site_ml_config_file))
    
    return config
    

def setup_and_preprocess(site_path, dfs_by_year, config):
    '''Creates the run directory and caches the config as JSON, then runs preprocess'''
    os.makedirs(site_path / 'indices')
    hash_df = lambda df: hashlib.sha256(df.to_json().encode('utf-8')).hexdigest()
    hashes = {year: hash_df(df) for year, df in dfs_by_year.items()}
    with open(site_path / 'run_info.json', 'w') as f:
        json.dump({ 'config': config, 'hashes': hashes }, f)

    all_df = pd.concat(list(dfs_by_year.values()), axis=0).sort_index()
    fluxgapfill.preprocess(site_path, all_df, split_method=config['split_method'], n_train=config['num_splits'])


def get_stages_to_run(db_path, dfs_by_year, config) -> list:
    '''Smart procedure for determining how much of the pipeline needs to
       be rerun for a given site. Returns a list of stages to run
    '''
    stages = [PREPROCESS, TRAIN, TEST, GAPFILL]
    site_path = db_path / 'methane_gapfill_ml' / args.site

    # Preprocess
    try:
        with open(site_path / 'run_info.json', 'r') as f:
            run_info = json.load(f)
        
        hash_df = lambda df: hashlib.sha256(df.to_json().encode('utf-8')).hexdigest()
        hashes = {year: hash_df(df) for year, df in dfs_by_year.items()}
        assert run_info['config'] == config
        assert run_info['hashes'] == hashes

        for i in range(config['num_splits']):
            assert os.path.exists(site_path / 'indices' / f'train{i}.npy')
            assert os.path.exists(site_path / 'indices' / f'val{i}.npy')
        assert os.path.exists(site_path / 'indices' / 'test.npy')
        stages.remove(PREPROCESS)
    except Exception as e:
        # Data has changed, or some other fundamental part of the config.
        # Scrap the entire directory and start over.
        if os.path.exists(site_path):
            shutil.rmtree(site_path)
        print('Running pipeline from preprocess')
        return stages

    # Train
    try:
        for model in config['models']:
            assert is_train_run_complete(site_path, model, config['num_splits'])
        stages.remove(TRAIN)
    except Exception as e:
        print('Running pipeline from train')
        return stages

    # Test
    try:
        for model in config['models']:
            assert os.path.exists(site_path / 'models' / model / 'test_metrics.csv')
            assert os.path.exists(site_path / 'models' / model / 'test_predictions.csv')
        stages.remove(TEST)
    except Exception as e:
        print('Running pipeline from test')
        return stages
    
    return stages


def is_train_run_complete(path, model, num_splits) -> bool:
    '''Checks if a given site has a full set of trained models'''
    for i in range(num_splits):
        if not os.path.exists(path / 'models' / model / f'{model}{i}.pkl'):
            return False
    if not os.path.exists(path / 'models' / model / 'val_metrics.csv'):
        return False
    return True


def read_database_traces(db_path, config) -> dict:
    """Reads binary data for a given site and returns a pandas DataFrame.
    Args:
        db_path (str): Path to the Database directory
        config (dict): Configuration dictionary (contains the site)
    """
    dfs_by_year = {}
    database_years = [d for d in os.listdir(db_path) if d.isnumeric()]
    for year in database_years:
        try:
            dfs_by_year[year] = read_database_trace_by_year(db_path, year, config)
        except FileNotFoundError as _:
            print(f'Variables not found for year {year}. Skipping...')
    return dfs_by_year


def read_database_trace_by_year(db_path, year, config) -> pd.DataFrame:
    """Reads binary data for a given site and year, and returns a pandas DataFrame.
    Args:
        db_path (str): Path to the Database directory
        year (int): The year read in the Database
        config (dict): Configuration dictionary (contains the site)
    """
    # Timestamps
    ts_cfg = config['dbase_metadata']['timestamp'] # for brevity
    timestamp_raw = np.fromfile(db_path / year / config['site'] / 'Clean' / 'SecondStage' / ts_cfg['name'], dtype=ts_cfg['dtype'])
    timestamp_end = pd.to_datetime(timestamp_raw - ts_cfg['base'], unit=ts_cfg['base_unit']).round('s')
    timestamp_start = timestamp_end - pd.Timedelta(minutes=30)
    timestamp_end_ameriflux = timestamp_end.strftime('%Y%m%d%H%M')
    timestamp_start_ameriflux = timestamp_start.strftime('%Y%m%d%H%M')
    df = pd.DataFrame({'TIMESTAMP_START': timestamp_start_ameriflux, 'TIMESTAMP_END': timestamp_end_ameriflux})

    # Predictor traces
    trace_dtype = config['dbase_metadata']['traces']['dtype']
    for trace in config['predictor_traces']:
        trace_path = Path(trace)
        trace_name = trace_path.stem
        trace_values = np.fromfile(db_path / year / config['site'] / 'Clean' / trace_path, dtype=trace_dtype)
        df[trace_name] = trace_values

    # Methane
    methane_values = np.fromfile(db_path / year / config['site'] / 'Clean' / Path(config['methane_trace']), dtype=trace_dtype)
    df['FCH4'] = methane_values
    return df


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--site", type=str, required=True)
    parser.add_argument("--year", type=str, required=True)
    parser.add_argument("--db_path", type=str, required=True)
    args = parser.parse_args()

    main(args)
