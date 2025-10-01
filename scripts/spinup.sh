#!/bin/bash
# spinup.sh
# This script requires the image_llm_archives_public virtual environment to be active and spins up HTTP services for image_llm_archives_public and lc-reconcile projects.

# Exit on any error
set -e


# Define project root and paths
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
IMAGE_PROJECT_DIR="$(realpath "$SCRIPT_DIR/..")"
PROJECT_ROOT="$(realpath "$IMAGE_PROJECT_DIR/..")"
IMAGE_PROJECT_NAME="$(basename "$IMAGE_PROJECT_DIR")"
RECONCILE_PROJECT_DIR="$PROJECT_ROOT/lc-reconcile"
IMAGE_VENV="$IMAGE_PROJECT_DIR/venv"
RECONCILE_VENV="$RECONCILE_PROJECT_DIR/venv"
LOG_DIR="$PROJECT_ROOT/logs"
IMAGE_PORT=8000
RECONCILE_PORT=5000
IMAGE_PID_FILE="$LOG_DIR/image_server.pid"
RECONCILE_PID_FILE="$LOG_DIR/reconcile_server.pid"

# Load PROJECT_FOLDER from project_folder.env if it exists
PROJECT_FOLDER=""
if [ -f "$IMAGE_PROJECT_DIR/project_folder.env" ]; then
    # shellcheck disable=SC1090
    source "$IMAGE_PROJECT_DIR/project_folder.env"
    echo "Loaded PROJECT_FOLDER from $IMAGE_PROJECT_DIR/project_folder.env: $PROJECT_FOLDER"
fi

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/spinup.log"
}

# Set IMAGE_DIR using PROJECT_FOLDER if set, else raise error
if [ -n "$PROJECT_FOLDER" ]; then
    IMAGE_DIR="$IMAGE_PROJECT_DIR/img/$PROJECT_FOLDER"
else
    log_message "ERROR: PROJECT_FOLDER is not set. Please set it in $IMAGE_PROJECT_DIR/project_folder.env."
    exit 1
fi




# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -i :"$port" > /dev/null 2>&1; then
        log_message "ERROR: Port $port is already in use."
        exit 1
    fi
}

# Function to check if a process is running
check_process() {
    local pid_file=$1
    local service_name=$2
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_message "$service_name is already running with PID $pid."
            return 1
        else
            rm -f "$pid_file"
        fi
    fi
    return 0
}

# Check if virtual environment exists and is valid
check_venv() {
    local venv_path=$1
    local project_name=$2
    if [ ! -d "$venv_path" ]; then
        log_message "ERROR: Virtual environment for $project_name not found at $venv_path."
        exit 1
    fi
    if [ ! -f "$venv_path/bin/activate" ]; then
        log_message "ERROR: Invalid virtual environment for $project_name at $venv_path."
        exit 1
    fi
}

# Check virtual environments
check_venv "$IMAGE_VENV" "$IMAGE_PROJECT_NAME"
check_venv "$RECONCILE_VENV" "lc-reconcile"


# Ensure the image virtual environment is already active
ensure_image_venv_active() {
    if [ -z "${VIRTUAL_ENV:-}" ]; then
        log_message "ERROR: No virtual environment is currently active. Please activate $IMAGE_VENV before running this script."
        exit 1
    fi

    if [ "$VIRTUAL_ENV" != "$IMAGE_VENV" ]; then
        log_message "ERROR: Unexpected virtual environment active at $VIRTUAL_ENV. Please activate $IMAGE_VENV before running this script."
        exit 1
    fi

    log_message "Detected active virtual environment at $VIRTUAL_ENV."
}

ensure_image_venv_active

# Check if ports are available
check_port "$IMAGE_PORT"
check_port "$RECONCILE_PORT"

# Check if services are already running
check_process "$IMAGE_PID_FILE" "Image HTTP server"
check_process "$RECONCILE_PID_FILE" "Reconcile HTTP server"

# Start image HTTP server
log_message "Starting image HTTP server..."
if [ ! -d "$IMAGE_DIR" ]; then
    log_message "ERROR: Image directory $IMAGE_DIR not found."
    exit 1
fi

cd "$IMAGE_DIR"
$IMAGE_PROJECT_DIR/venv/bin/python -m http.server "$IMAGE_PORT" > "$LOG_DIR/image_server.log" 2>&1 &
IMAGE_PID=$!
echo "$IMAGE_PID" > "$IMAGE_PID_FILE"
log_message "Image HTTP server started with PID $IMAGE_PID on port $IMAGE_PORT."

# Start reconcile HTTP server (auto-activates its virtual environment)
log_message "Starting reconcile HTTP service..."
cd "$RECONCILE_PROJECT_DIR"
if [ ! -f "reconcile.py" ]; then
    log_message "ERROR: reconcile.py not found in $RECONCILE_PROJECT_DIR."
    exit 1
fi

# shellcheck disable=SC1091
source "$RECONCILE_VENV/bin/activate"
$RECONCILE_PROJECT_DIR/venv/bin/python reconcile.py --debug > "$LOG_DIR/reconcile_server.log" 2>&1 &
RECONCILE_PID=$!
echo "$RECONCILE_PID" > "$RECONCILE_PID_FILE"
log_message "Reconcile HTTP service started with PID $RECONCILE_PID on port $RECONCILE_PORT."

deactivate

# Verify services are running
sleep 2
if ! ps -p "$IMAGE_PID" > /dev/null 2>&1; then
    log_message "ERROR: Image HTTP server failed to start. Check $LOG_DIR/image_server.log for details."
    exit 1
fi
if ! ps -p "$RECONCILE_PID" > /dev/null 2>&1; then
    log_message "ERROR: Reconcile HTTP service failed to start. Check $LOG_DIR/reconcile_server.log for details."
    exit 1
fi

log_message "All services started successfully."
log_message "Image HTTP server running at http://localhost:$IMAGE_PORT"
log_message "Reconcile HTTP service running at http://localhost:$RECONCILE_PORT"