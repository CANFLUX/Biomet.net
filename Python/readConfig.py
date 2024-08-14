# Read configuration file(s) for python based tasks
# Intended to be called by other scripts, not called by user directly
# Written by June Skeeter

import os
import sys
import yaml # Note: you need to install the "pyyaml" package, e.g., pip install pyyaml
import argparse


def set_user_configuration(user_defined=[]):
    wd = os.getcwd()
    os.chdir(os.path.split(__file__)[0])
    # Parse the config settings
    with open('config_files/config.yml') as yml:
        config = yaml.safe_load(yml)
        if os.path.isfile('config_files/user_path_definitions.yml'):
            with open('config_files/user_path_definitions.yml') as yml:
                config.update(yaml.safe_load(yml))
        else:
            with open('config_files/user_path_definitions_template.yml') as yml:
                config.update(yaml.safe_load(yml))
            print(f"WARNING: missing {'config_files/user_path_definitions.yml'}")
            print("Proceeding with template paths from {'config_files/user_path_definitions_template.yml'}")
            print("These are likely to cause issues, please create your own path definition file")

    # Import the user specified configurations (exit if they don't exist)
    config['tasks'] = {}
    if isinstance(user_defined,str):user_defined=[user_defined]
    for req in user_defined:
        if os.path.isfile(req):
            with open(req) as yml:
                config['tasks'].update(yaml.safe_load(yml))
        else:
            sys.exit(f"Missing {req}")
    os.chdir(wd)
    return(config)

# If called from command line ...
if __name__ == '__main__':
    
    CLI=argparse.ArgumentParser()

    CLI.add_argument(
        "--tasks", 
        nargs='+',
        type=str,
        default=[],
        )

    # Parse the args and make the call
    args = CLI.parse_args()

    set_user_configuration(args.tasks)