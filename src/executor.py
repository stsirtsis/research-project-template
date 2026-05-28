import click
import json
import itertools
import os
import subprocess
import sys

# Reserved keys (not experiment parameters)
# Keys starting with '_' are also excluded (used for comments/metadata)
RESERVED_KEYS = {'executor', 'slurm'}

def is_reserved(key):
    return key in RESERVED_KEYS or key.startswith('_')

# comment the click commands for testing
@click.command()
@click.option('--config', type=str, required=True, help="path to config JSON file")
@click.option('--name', type=str, required=True, help="experiment name")
@click.option('--index', type=int, required=True, help="index of the parameter set")
@click.option('--lang', type=str, default='python', help="language to use for the experiment")
@click.option('--source', type=str, default='experiment.py', help="name of the source file")
def execute(config, name, index, lang, source):

    # load the config file
    with open(config, "r") as f:
        config_data = json.load(f)

    # separate fixed and variable parameters (excluding reserved keys)
    fixed_params = {k: v for k, v in config_data.items() if not isinstance(v, list) and not is_reserved(k)}
    variable_params = {k: v for k, v in config_data.items() if isinstance(v, list) and not is_reserved(k)}

    # generate all combinations of variable parameters
    param_combinations = list(itertools.product(*[v for v in variable_params.values()]))

    # ensure index is within range
    if index >= len(param_combinations):
        raise ValueError(f"Index {index} is out of range. Only {len(param_combinations)} experiments available.")

    # construct parameter set
    experiment_params = {k: v for k, v in fixed_params.items()}  # copy fixed params
    experiment_params.update({
        k: param_combinations[index][i] for i, (k, v) in enumerate(variable_params.items())
    })  # add selected combination for variable params

    # inject exp_name from CLI argument
    experiment_params['exp_name'] = name

    # inject output_dir from executor config (with default)
    executor_config = config_data.get('executor', {})
    if 'output_dir' not in experiment_params:
        experiment_params['output_dir'] = os.path.join(executor_config.get('output_dir', 'outputs'), name)

    # auto-generate filename from variable params
    # NOTE: sometimes a parameter value (e.g., a HF model name) may contain "/"
    # replace such characters with "_" to ensure no directory issues arise
    exp_name = name
    var_parts = [f"{k}={experiment_params[k]}".replace("/", "_") for k in variable_params.keys()]
    output_filename = f"{exp_name}__{'__'.join(var_parts)}.json"

    # create args string - handle booleans as flags (no value)
    args_list = []
    for k, v in experiment_params.items():
        if isinstance(v, bool):
            if v:  # Only include flag if True
                args_list.append(f'--{k}')
            # If False, don't include the flag at all
        else:
            args_list.append(f'--{k} "{v}"')
    args = ' '.join(args_list)
    # check that the lang is either python or julia
    if lang not in ['python', 'julia']:
        raise ValueError(f"Language {lang} is not supported. Supported languages are python and julia.")

    # pass the output filename to the command
    args += f' --output_filename "{output_filename}"'

    # create the command
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    venv_python = os.path.join(project_root, 'env', 'bin', 'python')
    python_exe = venv_python if os.path.exists(venv_python) else sys.executable
    if lang == 'python':
        command = f'{python_exe} src/{source} {args}'
    elif lang == 'julia':
        command = f'julia --project=. -J dyn_sysimage.so src/{source} {args}'

    # create output directory (from executor config)
    output_dir = os.path.join(executor_config.get('output_dir', 'outputs'), name)
    os.makedirs(output_dir, exist_ok=True)

    # create log directory (from executor config)
    log_dir = os.path.join(executor_config.get('log_dir', 'outputs/logs'), name)
    os.makedirs(log_dir, exist_ok=True)

    # log files named to match JSON output
    log_base = output_filename.replace('.json', '')
    stdout_path = f"{log_dir}/{log_base}.out"
    stderr_path = f"{log_dir}/{log_base}.err"

    # run with output redirection
    with open(stdout_path, 'w') as stdout_file, open(stderr_path, 'w') as stderr_file:
        _ = subprocess.run(
            command,
            shell=True,
            stdout=stdout_file,
            stderr=stderr_file
        )

    return


if __name__ == '__main__':
    # comment for testing
    execute()
