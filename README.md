# Research Project Template

This repository serves as a template for research projects. It provides a structured way to organize data, experiment parameters, source code, and results. Additionally, it includes scripts for running experiments both locally and on SLURM clusters. The following sections act both as placeholders and as a quick start guide for running experiments using the provided scripts. Any of the following content can be edited and adapted for the specific project.

__Contents__:
- [Introduction](#introduction)
- [Dependencies](#dependencies)
- [Repository structure](#repository-structure)
- [Running experiments](#running-experiments)
- [Contact & attribution](#contact--attribution)


## Introduction

<!-- placeholder for an optional banner image -->
<!-- <div align="center">
  <img width="600" src="banner.png">
</div> -->

One paragraph motivating the project. This can be, for example, the paper abstract.

## Dependencies

### Python
All experiments were performed using Python 3.XX. To create a virtual environment and install dependencies:


```bash
python3 -m venv env
source env/bin/activate
pip install -r requirements.txt
```

*Note: The current `requirements.txt` contains commonly used packages. Remember to run `pip freeze > requirements.txt` before publishing the project.*

### Julia
All experiments were performed using Julia 1.XX.YY. To install dependencies, open the Julia REPL and run:


```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```
or equivalently
```julia
] activate .
] instantiate
```

*Note: The current `Project.toml` contains commonly used packages. Remember to also commit `Manifest.toml` before publishing the project.*

**Julia system image (optional but recommended):** For faster startup times, precompile packages into a system image:
```bash
julia --project=. scripts/build_sysimage.jl
```
This creates `dyn_sysimage.so` which is automatically used by `run.sh` and `submit_slurm.sh` when running Julia experiments.

**Hugging Face model cache (optional but recommended):** If your experiments use Hugging Face models, it is easier for bookkeeping topre-download them in the project directory:
```bash
python scripts/cache_hf_models.py
```
Edit `scripts/cache_hf_models.py` to specify which models to download. Models are cached in `models/hf_cache/` (except Mistral models, which use the default HF cache in the user's home directory).

## Repository structure

```
├── configs/
│   └── experiment.json
├── data/
│   ├── original/
│   └── processed/
├── figures/
├── notebooks/
├── outputs/
├── scripts/
│   ├── run.sh
│   ├── submit_slurm.sh
│   ├── clean.sh
│   ├── build_sysimage.jl
│   └── cache_hf_models.py
└── src/
    ├── executor.py
    ├── experiment.py
    ├── experiment.jl
    └── utils.py
```

- `configs/` — JSON files specifying experiment parameters
- `data/` — Raw data (`original/`) and their polished/organized versions (`processed/`)
- `figures/` — Generated figures
- `notebooks/` — Jupyter notebooks for analysis and visualization
- `outputs/` — Experiment results (JSON files)
- `scripts/` — Shell scripts for running experiments locally or on SLURM
  - `run.sh` — Run experiments locally
  - `submit_slurm.sh` — Submit SLURM array jobs
  - `clean.sh` — Clean log files
  - `build_sysimage.jl` — Precompile Julia packages into system image (optional)
  - `cache_hf_models.py` — Download Hugging Face models to local cache (optional)
- `src/` — Source code:
  - `executor.py` — Reads config, selects parameters, and runs the experiment script
  - `experiment.py` / `experiment.jl` — Main experiment logic (Python/Julia)
  - `utils.py` — Plotting utilities for LaTeX-compatible figures

## Running experiments

### Configuration

Experiments are configured via JSON files in `configs/`. Each config file has three sections:
- **Experiment parameters** (top-level): Fixed values (e.g., `"iterations": 10`) or arrays for variables (e.g., `"N": [10, 20]`) that are the main parameters passed to the Python/Julia script
- **Executor settings** (`executor`): Values that specify the name of the Python/Julia script to run, the output directory, and the logging directory
- **SLURM settings**: Resource requirements for execution on compute clusters (see `_comments` in the `slurm` section for parameter descriptions) --- these are simply ignored if the experiment is executed locally.

### How it works

The executor creates a grid of all parameter combinations. Array values in the config
(e.g., `"N": [10, 20]`, `"prob": [0.1, 0.5]`) are combined into 4 experiments (2×2).
Each combination runs as a separate experiment, either sequentially (local) or in
parallel (SLURM array job). The executor invokes `src/{exec_name}.py` (or `.jl` for Julia experiments)
with all parameters passed as command-line arguments, where `exec_name` is specified in the
config file's `executor.exec_name` field (default: `experiment`).

### Local execution

To run all parameter combinations locally:

```bash
./scripts/run.sh -n experiment
```

By default, this runs `configs/experiment.json` using Python.

**Options:**
- `-n, --name NAME` — Experiment name (required). It tells the executor to look for the config `configs/NAME.json` and the python/julia script uses that name as a prefix for output files.
- `-l, --lang LANG` — Language: `python` or `julia` (default: `python`)
- `-h, --help` — Show help message

**Examples:**
```bash
# Use Julia instead of Python
./scripts/run.sh -n experiment -l julia

# Use a different experiment
./scripts/run.sh -n my_other_experiment

# Combine options
./scripts/run.sh -n my_other_experiment -l julia
```

### SLURM execution

To submit experiments as a SLURM array job:

1. Configure SLURM settings in your config file (e.g., `configs/experiment.json`)
2. Submit the job:

```bash
./scripts/submit_slurm.sh
```

**Options** are the same as `run.sh`, plus:
- `-d, --dry-run` — Preview the sbatch command without executing

**Examples:**
```bash
# Preview what would be submitted
./scripts/submit_slurm.sh -n experiment --dry-run
# 💡 This is particularly useful if you do not have permission to execute bash scripts on the login node of your SLURM cluster. Simply run this command locally and copy-paste the resulting sbatch command.

# Submit Julia experiment
./scripts/submit_slurm.sh -n experiment -l julia

# Submit a different experiment
./scripts/submit_slurm.sh -n my_other_experiment
```

Monitor jobs with `squeue -u $USER` and check logs in the `slurm.log_dir` specified in your config (default: `outputs/slurm_logs`).

### Output

Results are saved to the `output_dir` specified in the config (default: `outputs/`). Executor logs are saved to `log_dir` (default: `outputs/logs`). Output filenames are auto-generated from variable parameters:

```
{exp_name}__{param1}={value1}__{param2}={value2}.json
```

For example: `test__N=10__prob=0.5.json`

## Contact & attribution

If you use this code in your research, please cite:

```bibtex
<!-- Insert your paper's BibTeX here -->
```
---
*A last note: If you have any questions about this repository, spot any bugs, or there is something you would like to see improved, please write me an email (see [https://stsirtsis.github.io/](https://stsirtsis.github.io/) for my address).*
