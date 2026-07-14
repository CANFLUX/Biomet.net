import os
import sys
import json
import shutil
import hashlib
import argparse
import subprocess
import fluxgapfill
import numpy as np
import pandas as pd
from pathlib import Path
import warnings
warnings.filterwarnings('ignore', category=UserWarning, module='sklearn')
import pickle

os.chdir(os.path.split(__file__)[0])
DEFAULT_CONFIG_FILE = Path('./config_files/ML_Gapfill_default.yml')

# Aliases
PREPROCESS = 1
TRAIN = 2
TEST = 3
GAPFILL = 4

TIMESTAMP_COLUMNS = ['TIMESTAMP_START', 'TIMESTAMP_END']


def main(args):
    # so you don't have to install pyyaml manually
    import_pyyaml() 

    db_path = Path(args.db_path)
    config = create_config(args)

    for flux_name, flux_config in config['fluxes'].items():
        # to overwrite the default by ignoring some fluxes, leave the flux config empty
        # e.g. fluxes:
        #       |-> fch4:           # here, fch4 will be ignored
        #       |-> nee:
        #             trace:
        #             preds_trace:  # and so on
        if flux_config is None:
            print(f"Skipping {flux_name.upper()}...")
            continue

        flux_label = flux_name.upper()
        print(f"\n{'-'*5} {flux_name.upper()} {'-'*5}")
        dfs_by_year = read_database_traces(db_path, config, flux_name, flux_config)
        if not dfs_by_year:
            raise RuntimeError(
                f'No readable yearly data found for flux "{flux_name}" '
                f'using trace "{flux_config["trace"]}".'
            )
        site_path = get_site_path(db_path, args.site, flux_name)
        stages_to_run = get_stages_to_run(
            site_path, dfs_by_year, flux_config, flux_label, config['mode']
        )
        df_all = pd.concat(list(dfs_by_year.values()), axis=0).sort_index()

        if PREPROCESS in stages_to_run:
            setup_and_preprocess(site_path, dfs_by_year, flux_config, flux_label)

        if TRAIN in stages_to_run:
            predictors = [str(Path(p).stem) for p in flux_config['preds_trace']]
            fluxgapfill.train(
                site_path, df_all, flux_config['models'], predictors,
                target=flux_label
            )

        if TEST in stages_to_run:
            fluxgapfill.test(site_path, df_all, flux_config['models'], target=flux_label)

        ml_dir = db_path / args.year / args.site / 'Clean' / 'ThirdStage_ML' / flux_name
        os.makedirs(ml_dir, exist_ok=True)

        # Copy timestamp into this flux's output directory
        timestamp_source = db_path / args.year / args.site / 'Clean' / 'ThirdStage' / config['dbase_metadata']['timestamp']['name']
        try:
            shutil.copy(timestamp_source, ml_dir)
        except FileNotFoundError as e:
            print(f"Could not copy timestamp file: {e}")

        for model in flux_config['models']:
            df_gapfilled = fluxgapfill.gapfill(
                site_path, dfs_by_year[args.year], [model],
                target=flux_label, output_prefix=flux_label
            )
            flux_f = df_gapfilled[f'{flux_label}_F'].values.astype(config['dbase_metadata']['traces']['dtype'])
            flux_f_u = df_gapfilled[f'{flux_label}_F_UNCERTAINTY'].values.astype(config['dbase_metadata']['traces']['dtype'])

            flux_f.tofile(ml_dir / f'{flux_label}_F_ML_{model.upper()}')
            flux_f_u.tofile(ml_dir / f'{flux_label}_F_ML_{model.upper()}_UNCERTAINTY')

        print(f"{'-'*(len(flux_name)+12)}")


def import_pyyaml():
    global yaml
    try:
        import yaml
    except ImportError:
        print('The package pyyaml does not exist. Installing it right now.')
        subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'pyyaml'])
        import yaml


def deep_merge(base, override):
    """Recursively merges override into base and returns base."""
    for key, value in override.items():
        if value is None:
            base[key] = None  # explicit NULL override kills the key
        elif isinstance(value, dict) and isinstance(base.get(key), dict):
            deep_merge(base[key], value)
        else:
            base[key] = value
    return base


def hash_df_columns(df, columns):
    return hashlib.sha256(df[columns].to_json().encode('utf-8')).hexdigest()


def build_preprocess_signature(flux_config):
    return {
        'trace': flux_config['trace'],
        'split_method': flux_config['split_method'],
        'num_splits': flux_config['num_splits'],
    }


def build_run_info(dfs_by_year, flux_config, flux_label):
    preprocess_columns = TIMESTAMP_COLUMNS + [flux_label]
    return {
        'preprocess_config': build_preprocess_signature(flux_config),
        'preprocess_hashes': {
            year: hash_df_columns(df, preprocess_columns)
            for year, df in dfs_by_year.items()
        },
    }


def write_run_info(site_path, run_info):
    os.makedirs(site_path, exist_ok=True)
    with open(site_path / 'run_info.json', 'w') as f:
        json.dump(run_info, f)


def get_site_path(db_path, site, flux_name):
    return db_path / 'methane_gapfill_ml' / site / flux_name


def has_complete_indices(site_path, num_splits):
    if not (site_path / 'indices' / 'test.npy').exists():
        return False
    for i in range(num_splits):
        if not (site_path / 'indices' / f'train{i}.npy').exists():
            return False
        if not (site_path / 'indices' / f'val{i}.npy').exists():
            return False
    return True


def create_config(args) -> dict:
    trace_analysis_ini_path = Path(args.db_path) / 'Calculation_Procedures' / 'TraceAnalysis_ini'
    with open(DEFAULT_CONFIG_FILE, 'r') as f:
        config = yaml.safe_load(f)
    config['site'] = args.site

    site_config_path = trace_analysis_ini_path / args.site / f"{args.site}_ML_Gapfill.yml"
    if site_config_path.exists():
        with open(site_config_path, 'r') as f:
            site_config = yaml.safe_load(f)
        # remap 'traces' key to 'fluxes' to match internal structure
        if 'traces' in site_config:
            site_config['fluxes'] = site_config.pop('traces')
        deep_merge(config, site_config)

    config['mode'] = args.mode
    return config


def setup_and_preprocess(site_path, dfs_by_year, flux_config, flux_label):
    '''Creates the run directory and caches the config as JSON, then runs preprocess'''
    if os.path.exists(site_path):
        shutil.rmtree(site_path)
    os.makedirs(site_path / 'indices')
    write_run_info(site_path, build_run_info(dfs_by_year, flux_config, flux_label))

    all_df = pd.concat(list(dfs_by_year.values()), axis=0).sort_index()
    fluxgapfill.preprocess(
        site_path, all_df, target=flux_label,
        split_method=flux_config['split_method'], n_train=flux_config['num_splits']
    )


def get_stages_to_run(site_path, dfs_by_year, flux_config, flux_label, mode) -> list:
    current_run_info = build_run_info(dfs_by_year, flux_config, flux_label)

    if mode == 'gapfill':
        missing_models = [
            model for model in flux_config['models']
            if not is_gapfill_run_complete(site_path, model, flux_config['num_splits'])
        ]
        if missing_models:
            missing_models_str = ', '.join(missing_models)
            raise RuntimeError(
                f'Gapfill mode requested, but trained/tested models are missing for flux "{flux_label}" '
                f'(models: {missing_models_str}). Use train_ML_gapfill.m to train the model.'
            )

        # Check predictors match trained model
        current_predictors = [str(Path(p).stem) for p in flux_config['preds_trace']]
        for model in flux_config['models']:
            pkl_path = site_path / 'models' / model / f'{model}0.pkl'
            if pkl_path.exists():
                with open(pkl_path, 'rb') as f:
                    trained_model = pickle.load(f)
                saved_predictors = list(trained_model.predictors)
                if saved_predictors != current_predictors:
                    raise RuntimeError(
                        f'Gapfill mode requested, but predictors have changed for "{flux_label}" '
                        f'(model: {model}).\n'
                        f'  Saved:   {saved_predictors}\n'
                        f'  Current: {current_predictors}\n'
                        f'Run train_ML_gapfill to retrain.'
                    )

        return [GAPFILL]

    elif mode == 'full': 
        valid_stages = [PREPROCESS, TRAIN, TEST, GAPFILL]
        # --- Preprocess ---
        try:
            with open(site_path / 'run_info.json', 'r') as f:
                run_info = json.load(f)
            assert run_info['preprocess_config'] == current_run_info['preprocess_config']
            assert run_info['preprocess_hashes'] == current_run_info['preprocess_hashes']
            assert has_complete_indices(site_path, flux_config['num_splits'])
            valid_stages.remove(PREPROCESS)
        except Exception as _:
            if os.path.exists(site_path):
                shutil.rmtree(site_path)
            print('Running pipeline from preprocess')
            return valid_stages

        # --- Train ---
        try:
            for model in flux_config['models']:
                model_dir = site_path / 'models' / model
                for i in range(flux_config['num_splits']):
                    assert os.path.exists(model_dir / f'{model}{i}.pkl')
                assert os.path.exists(model_dir / 'val_metrics.csv')

                # Check predictors match by reading directly from the trained model
                pkl_path = model_dir / f'{model}0.pkl'
                if pkl_path.exists():
                    with open(pkl_path, 'rb') as f:
                        trained_model = pickle.load(f)
                    saved_predictors = list(trained_model.predictors)
                    current_predictors = [str(Path(p).stem) for p in flux_config['preds_trace']]
                    assert saved_predictors == current_predictors, \
                        f'Predictors changed for {model}: {saved_predictors} → {current_predictors}'

            valid_stages.remove(TRAIN)
        except Exception:
            if os.path.exists(site_path):
                shutil.rmtree(site_path)
            print('Running pipeline from preprocess due to predictor/model mismatch')
            return [PREPROCESS, TRAIN, TEST, GAPFILL]

        # --- Test ---
        try:
            for model in flux_config['models']:
                assert os.path.exists(site_path / 'models' / model / 'test_metrics.csv')
                assert os.path.exists(site_path / 'models' / model / 'test_predictions.csv')
            valid_stages.remove(TEST)
        except Exception as _:
            print('Running pipeline from test')
            return valid_stages

        return valid_stages

    else:
        raise ValueError(f"The mode {mode} is invalid. Please use either 'full' or 'gapfill'.")


def is_train_run_complete(path, model, num_splits) -> bool:
    """Checks if a given site has a full set of trained models"""
    model_dir = path / 'models' / model
    return (
        all(os.path.exists(model_dir / f'{model}{i}.pkl') for i in range(num_splits))
        and os.path.exists(model_dir / 'val_metrics.csv')
    )


def is_gapfill_run_complete(path, model, num_splits) -> bool:
    """Checks if a model has all artifacts required for gapfill-only runs."""
    model_dir = path / 'models' / model
    return (
        is_train_run_complete(path, model, num_splits)
        and os.path.exists(model_dir / 'scale.json')
    )


def read_database_traces(db_path, config, flux_name, flux_config) -> dict:
    """Reads binary data for a given site and returns a pandas DataFrame.
    Args:
        db_path (str): Path to the Database directory
        config (dict): Configuration dictionary (contains the site)
    """
    dfs_by_year = {}
    database_years = [d for d in os.listdir(db_path) if d.isnumeric()]
    for year in database_years:
        try:
            dfs_by_year[year] = read_database_trace_by_year(db_path, year, config, flux_name, flux_config)
        except FileNotFoundError as e:
            print(f'Variables not found for year {year}. Skipping... but also: {e}')
    return dfs_by_year



def read_database_trace_by_year(db_path, year, config, flux_name, flux_config) -> pd.DataFrame:
    """
    Reads binary data for a given site and year, and returns a pandas DataFrame.
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
    for trace in flux_config['preds_trace']:
        trace_path = Path(trace)
        trace_name = trace_path.stem
        trace_values = np.fromfile(db_path / year / config['site'] / 'Clean' / trace_path, dtype=trace_dtype)
        df[trace_name] = trace_values

    # Target flux
    flux_values = np.fromfile(db_path / year / config['site'] / 'Clean' / Path(flux_config['trace']), dtype=trace_dtype)
    df[flux_name.upper()] = flux_values
    return df 


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--site', type=str, required=True)
    parser.add_argument('--year', type=str, required=True)
    parser.add_argument('--db_path', type=str, required=True)
    parser.add_argument('--mode', type=str, choices=['full', 'gapfill'], required=True)
    args = parser.parse_args()

    main(args)

 