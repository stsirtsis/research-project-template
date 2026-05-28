#!/bin/bash
# Submit experiment as SLURM array job

set -e

show_help() {
    cat << 'EOF'
Usage: submit_slurm.sh -n NAME [OPTIONS]

Submit experiments as a SLURM array job.

Options:
  -n, --name NAME       Experiment name (required)
                        Config file is derived as configs/NAME.json
  -l, --lang LANG       Language: python or julia (default: python)
  -d, --dry-run         Show sbatch command without executing
  -h, --help            Show this help message

Environment variables:
  NAME, EXPERIMENT_LANG are also supported.
  Command-line arguments take precedence over environment variables.

SLURM settings are read from the 'slurm' section of the config file.

Examples:
  submit_slurm.sh -n experiment           # Submit experiment
  submit_slurm.sh -n my_exp -l julia      # Julia experiment
  submit_slurm.sh -n experiment --dry-run # Preview command
EOF
}

DRY_RUN=false

# Parse arguments
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
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            echo "Try 'submit_slurm.sh --help' for more information." >&2
            exit 2
            ;;
        *)
            echo "Error: Unexpected argument '$1'" >&2
            echo "Try 'submit_slurm.sh --help' for more information." >&2
            exit 2
            ;;
    esac
done

# Apply priority: CLI args > env vars
NAME="${ARG_NAME:-$NAME}"

# Validate required --name argument
if [ -z "$NAME" ]; then
    echo "Error: --name is required" >&2
    echo "Try 'submit_slurm.sh --help' for more information." >&2
    exit 2
fi

source env/bin/activate

# Set configuration variables
EXPERIMENT_LANG="${ARG_LANG:-${EXPERIMENT_LANG:-python}}"
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

# Get number of parameter combinations
PARAM_COMBINATIONS=$(jq -r '
    to_entries
    | map(select(.value | type == "array"))
    | map(.value | length)
    | reduce .[] as $item (1; . * $item)
' "$CONFIG_FILE")

# Read SLURM settings (with defaults)
SLURM_CORES=$(jq -r '.slurm.cores // 1' "$CONFIG_FILE")
SLURM_NODES=$(jq -r '.slurm.nodes // 1' "$CONFIG_FILE")
SLURM_TIME=$(jq -r '.slurm.time // "0-02:59"' "$CONFIG_FILE")
SLURM_MEMORY=$(jq -r '.slurm.memory // "5G"' "$CONFIG_FILE")
SLURM_LOG_DIR=$(jq -r '.slurm.log_dir // "outputs/slurm_logs"' "$CONFIG_FILE")
SLURM_JOB_NAME=$(jq -r '.slurm.job_name // "experiment"' "$CONFIG_FILE")
SLURM_PARTITION=$(jq -r '.slurm.partition // empty' "$CONFIG_FILE")
SLURM_ACCOUNT=$(jq -r '.slurm.account // empty' "$CONFIG_FILE")
SLURM_EMAIL=$(jq -r '.slurm.email // empty' "$CONFIG_FILE")
SLURM_EMAIL_TYPE=$(jq -r '.slurm.email_type // empty' "$CONFIG_FILE")
SLURM_GRES=$(jq -r '.slurm.gres // empty' "$CONFIG_FILE")
SLURM_CONSTRAINT=$(jq -r '.slurm.constraint // empty' "$CONFIG_FILE")
SLURM_EXCLUDE=$(jq -r '.slurm.exclude // empty' "$CONFIG_FILE")
SLURM_MAX_CONCURRENT=$(jq -r '.slurm.max_concurrent // empty' "$CONFIG_FILE")

mkdir -p "$SLURM_LOG_DIR"

# Build sbatch command with optional parameters
ARRAY_SPEC="0-$((PARAM_COMBINATIONS - 1))"
[ -n "$SLURM_MAX_CONCURRENT" ] && ARRAY_SPEC+="%$SLURM_MAX_CONCURRENT"
SBATCH_CMD="sbatch --array=$ARRAY_SPEC"
SBATCH_CMD+=" --cpus-per-task=$SLURM_CORES"
SBATCH_CMD+=" --nodes=$SLURM_NODES"
SBATCH_CMD+=" --time=$SLURM_TIME"
SBATCH_CMD+=" --mem=$SLURM_MEMORY"
SBATCH_CMD+=" --job-name=$SLURM_JOB_NAME"
SBATCH_CMD+=" --output=$SLURM_LOG_DIR/%A_%a.out"
SBATCH_CMD+=" --error=$SLURM_LOG_DIR/%A_%a.err"

[ -n "$SLURM_PARTITION" ] && SBATCH_CMD+=" --partition=$SLURM_PARTITION"
[ -n "$SLURM_ACCOUNT" ] && SBATCH_CMD+=" --account=$SLURM_ACCOUNT"
[ -n "$SLURM_EMAIL" ] && SBATCH_CMD+=" --mail-user=$SLURM_EMAIL"
[ -n "$SLURM_EMAIL_TYPE" ] && SBATCH_CMD+=" --mail-type=$SLURM_EMAIL_TYPE"
[ -n "$SLURM_GRES" ] && SBATCH_CMD+=" --gres=$SLURM_GRES"
[ -n "$SLURM_CONSTRAINT" ] && SBATCH_CMD+=" --constraint=$SLURM_CONSTRAINT"
[ -n "$SLURM_EXCLUDE" ] && SBATCH_CMD+=" --exclude=$SLURM_EXCLUDE"

SBATCH_CMD+=" --export=ALL,EXPERIMENT_LANG=$EXPERIMENT_LANG,NAME=$NAME"
SBATCH_CMD+=" scripts/run.sh"

echo "Submitting $PARAM_COMBINATIONS jobs..."
echo "Command: $SBATCH_CMD"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "(dry-run mode - command not executed)"
else
    eval $SBATCH_CMD
fi

deactivate
