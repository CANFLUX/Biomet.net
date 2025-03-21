import yaml
import numpy as np
import argparse
import fluxgapfill
from pathlib import Path
from typing import List
import pandas as pd
import os

os.chdir(os.path.split(__file__)[0])
CONFIG_PATH = Path('./config_files')

def main(args):
    # Get config defaults
    with open(CONFIG_PATH / 'config.yml', 'r') as f:
        config = yaml.safe_load(f)
    with open(CONFIG_PATH / 'methane_gapfill_ml.yml', 'r') as f:
        config.update(yaml.safe_load(f))

    db_path = Path(args.db_path)
    custom_config_path = db_path / 'Calculation_Procedures' / 'TraceAnalysis_ini' / 'CH4_ML_Gapfilling.yml'
    if os.path.exists(custom_config_path):
        with open(custom_config_path, 'r') as f:
            config.update(yaml.safe_load(f))
    
    methane_data_path = db_path / 'methane_gapfill_ml'
    models = config['models']
    site = args.site
    gapfill_year = args.year
    predictors = [Path(trace).stem for trace in config['predictor_traces']]


    os.makedirs(methane_data_path / site, exist_ok=True)
    
    if clean_models_found(db_path, methane_data_path, site, predictors, config):
        print(f'Using existing models for site {site}.')
    else:
        print(f'Preprocessing and training new models.')
        setup_pipeline_directory(db_path, methane_data_path, site, predictors, config)
        fluxgapfill.preprocess(sites=args.site, 
            na_values=-9999,
            split_method='random',
            n_train=config['num_splits'],
            data_dir=str(methane_data_path)
        )

        fluxgapfill.train(
            sites=args.site,
            data_dir=str(methane_data_path),
            models=models,
            predictors=predictors + ['temporal'],
            overwrite_existing_models=True
        )

        fluxgapfill.test(
            sites=args.site,
            data_dir=str(methane_data_path),
            models=models,
            predictors=predictors + ['temporal'],
            split='test',
            distribution='laplace',
            overwrite_results=True
        )

        fluxgapfill.gapfill(
            sites=args.site,
            data_dir=str(methane_data_path),
            models=models,
            predictors=predictors + ['temporal']
        )

    write_database_traces(db_path, methane_data_path, site, gapfill_year, models, config)


def clean_models_found(db_path, methane_data_path, site, predictors, config) -> bool:
    """Checks the methane data path to see if there are already trained models for
    this site, and whether there are any new site-years (in which case it should re-train).
    
    Returns False if there is any reason to re-compile the data and retrain.
    Returns True if the existing models are up-to-date, and we can just reuse the data.
    """
    if not os.path.exists(methane_data_path / site / 'years.txt') or \
       not os.path.exists(methane_data_path / site / 'predictors.txt'):
        return False
    
    clean_years = find_clean_site_years(site, db_path, config)
    with open(methane_data_path / site / 'years.txt', 'r') as f:
        existing_years = f.read().split(',')
    new_years = [y for y in clean_years if y not in existing_years]
    if len(new_years) > 0:
        return False
    
    with open(methane_data_path / site / 'predictors.txt', 'r') as f:
        existing_predictors = f.read().split(',')
    if sorted(predictors) != sorted(existing_predictors):
        return False
    
    for model in config['models']:
        for split in range(1,config['num_splits']+1):
            if not os.path.exists(methane_data_path / site / 'models' / model / 'predictors' / f'model{split}.pkl'):
                return False
    return True



def setup_pipeline_directory(db_path, methane_data_path, site, predictors, config) -> None:
    """Creates all necessary files to begin running the ML pipeline"""

    clean_years = find_clean_site_years(site, db_path, config)

    with open(methane_data_path / site / 'years.txt', 'w') as f:
        f.write(','.join(clean_years))
    with open(methane_data_path / site / 'predictors.txt', 'w') as f:
        f.write(','.join(predictors))
    
    site_df = read_database_traces(site, clean_years, db_path, config)
    site_df.to_csv(methane_data_path / site / 'raw.csv', index=False)


def find_clean_site_years(site, db_path, config) -> List:
    database_years = [d for d in os.listdir(db_path) if d.isnumeric()]
    clean_site_years = []
    required_variable_paths = [Path(v) for v in config['predictor_traces']]
    required_variable_paths.append(Path(config['methane_trace']))
    for year in sorted(database_years):
        for p in required_variable_paths:
            if not os.path.exists(db_path / year / site / 'Clean' / p):
                print(db_path / year / site / 'Clean' / p)
                print(f'Cannot find variable {p} in year {year}. Skipping...')
                break
        else:
            clean_site_years.append(year)
    return clean_site_years


def read_database_traces(site, years, db_path, config) -> pd.DataFrame:
    """Reads binary data for a given site and returns a pandas DataFrame.
    Args:
        site (str): The site identifier for which data is being read.
        years (list of str): List of years to include in the dataset.
        db_path (str): Path to the Database directory
        config (dict): Configuration dictionary
    """
    
    # Timestamps
    ts_cfg = config['dbase_metadata']['timestamp'] # for brevity
    timestamp_raw = np.concatenate([
            np.fromfile(db_path / year / site / 'Clean' / 'SecondStage' / ts_cfg['name'], dtype=ts_cfg['dtype'])
        for year in years ])
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
        trace_values = np.concatenate([
                np.fromfile(db_path / year / site / 'Clean' / trace_path, dtype=trace_dtype)
            for year in years ])
        df[trace_name] = trace_values

    # Methane
    methane_values = np.concatenate([
        np.fromfile(db_path / year / site / 'Clean' / Path(config['methane_trace']), dtype=trace_dtype)
    for year in years ])
    df['FCH4'] = methane_values

    return df


def write_database_traces(db_path, methane_data_path, site, year, models, config):
    """Writes the gapfilled FCH4 columns to the database"""
    output_path = db_path / year / site / 'Clean' / 'ThirdStage'
    os.makedirs(output_path, exist_ok=True)
    existing_ml_traces = [f for f in os.listdir(output_path) if 'FCH4_F_ML' in f]
    for trace in existing_ml_traces:
        if os.path.exists(output_path / trace):
            os.remove(output_path / trace)
    
    trace_dtype = config['dbase_metadata']['traces']['dtype']
    for model in models:
        df = pd.read_csv(methane_data_path / site / 'gapfilled' / f'{model}_predictors_laplace.csv')
        df = df[df['Year'] == int(year)]
        trace = df['FCH4_F'].values.squeeze().astype(trace_dtype)
        trace.tofile(output_path / f'FCH4_F_ML_{model.upper()}')
    return


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--site", type=str, required=True)
    parser.add_argument("--year", type=str, required=True)
    parser.add_argument("--db_path", type=str, required=True)
    args = parser.parse_args()

    main(args)
