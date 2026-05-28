#!/bin/bash
# Unified experiment runner
# - When SLURM_ARRAY_TASK_ID is set: runs single experiment (SLURM worker mode)
# - Otherwise: loops through all parameter combinations (local mode)

set -e

show_help() {
    cat << 'EOF'
Usage: run.sh -n NAME [OPTIONS]

Run experiments locally (all combinations) or as a SLURM worker (single task).

Options:
  -n, --name NAME       Experiment name (required)
                        Config file is derived as configs/NAME.json
  -l, --lang LANG       Language: python or julia (default: python)
  -h, --help            Show this help message

Examples:
  run.sh -n experiment              # Run experiment
  run.sh -n my_exp -l julia         # Julia experiment

SLURM worker mode:
  When SLURM_ARRAY_TASK_ID is set (running as SLURM job),
  configuration is read from environment variables passed by sbatch.
EOF
}

# Parse arguments (skip if in SLURM worker mode - uses env vars from sbatch)
if [ -z "$SLURM_ARRAY_TASK_ID" ]; then
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                ARG_NAME="$2"
                shift 2
                ;;
            --name=*)
                ARG_NAME="${1#*=}"
                shift
                ;;
            -l|--lang)
                ARG_LANG="$2"
                shift 2
                ;;
            --lang=*)
                ARG_LANG="${1#*=}"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                echo "Error: Unknown option $1" >&2
                echo "Try 'run.sh --help' for more information." >&2
                exit 2
                ;;
            *)
                echo "Error: Unexpected argument '$1'" >&2
                echo "Try 'run.sh --help' for more information." >&2
                exit 2
                ;;
        esac
    done

    # Validate required --name argument
    if [ -z "$ARG_NAME" ]; then
        echo "Error: --name is required" >&2
        echo "Try 'run.sh --help' for more information." >&2
        exit 2
    fi
fi

source env/bin/activate

export HF_HUB_CACHE="$(pwd)/models/hf_cache"

# Set configuration variables
if [ -n "$SLURM_ARRAY_TASK_ID" ]; then
    # SLURM worker mode: use env vars passed by sbatch
    EXPERIMENT_LANG="${EXPERIMENT_LANG:-python}"
    # NAME must be set by sbatch
    if [ -z "$NAME" ]; then
        echo "Error: NAME environment variable not set" >&2
        exit 1
    fi
else
    # Local mode: CLI args
    EXPERIMENT_LANG="${ARG_LANG:-python}"
    NAME="$ARG_NAME"
fi
CONFIG_FILE="configs/${NAME}.json"

# Validate language
if [[ ! "$EXPERIMENT_LANG" =~ ^(python|julia)$ ]]; then
    echo "Error: Invalid language '$EXPERIMENT_LANG'. Use 'python' or 'julia'." >&2
    exit 1
fi

# Validate config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

# Set up Julia path for SLURM mode (compute nodes don't source .bashrc)
if [ -n "$SLURM_ARRAY_TASK_ID" ] && [ "$EXPERIMENT_LANG" == "julia" ]; then
    JULIA_PATH=$(jq -r '.slurm.julia_path // empty' "$CONFIG_FILE")
    JULIA_PATH="${JULIA_PATH/#\~/$HOME}"  # Expand ~ to $HOME
    if [ -n "$JULIA_PATH" ]; then
        export PATH="$JULIA_PATH:$PATH"
    fi
fi

# Determine source file from config's executable field
SCRIPT_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('executor', {}).get('exec_name', 'experiment'))")
if [ "$EXPERIMENT_LANG" == "python" ]; then
    SRC="${SCRIPT_NAME}.py"
elif [ "$EXPERIMENT_LANG" == "julia" ]; then
    SRC="${SCRIPT_NAME}.jl"
fi

if [ -n "$SLURM_ARRAY_TASK_ID" ]; then
    # SLURM worker mode: run single experiment
    python src/executor.py --config="$CONFIG_FILE" --name="$NAME" --index="$SLURM_ARRAY_TASK_ID" --lang="$EXPERIMENT_LANG" --source="$SRC"
else
    # Local mode: loop through all combinations
    PARAM_COMBINATIONS=$(jq -r '
        to_entries
        | map(select(.value | type == "array"))
        | map(.value | length)
        | reduce .[] as $item (1; . * $item)
    ' "$CONFIG_FILE")

    echo "Running $PARAM_COMBINATIONS experiments locally..."
    for INDEX in $(seq 0 $((PARAM_COMBINATIONS - 1))); do
        echo "[$((INDEX + 1))/$PARAM_COMBINATIONS]"
        python src/executor.py --config="$CONFIG_FILE" --name="$NAME" --index="$INDEX" --lang="$EXPERIMENT_LANG" --source="$SRC"
    done
fi

deactivate
