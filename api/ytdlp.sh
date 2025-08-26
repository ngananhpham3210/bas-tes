#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
readonly PYTHON_VERSION="3.11" # <-- CHANGED: Specify Python version here
readonly DEPS_DIR="dependencies" # This folder will contain yt-dlp and its dependencies


# --- Helper Functions ---

log() {
  echo "--> $1"
}

# Logs the structure of the deployment directory.
# Now excludes 'dependencies' but not 'python' since it no longer exists.
log_deployment_structure() {
  local target_dir="$1"
  
  if [ ! -d "$target_dir" ]; then
    log "Directory not found for structure log: $target_dir"
    return
  fi

  echo
  echo "============================================================"
  echo "--- Structure of Deployment Directory: $target_dir"
  echo "--- (Excluding contents of '$DEPS_DIR')"
  echo "============================================================"
  
  if command -v tree &> /dev/null; then
    # Use `tree`, ignoring the large dependencies folder.
    tree -L 3 -I "$DEPS_DIR" "$target_dir"
  else
    # Fallback to `ls`.
    log "NOTE: 'tree' command not found. Falling back to a non-recursive 'ls' listing."
    ls -la "$target_dir"
  fi

  echo "--- End of Structure Log for: $target_dir ---"
  echo "============================================================"
  echo
}

# (log_directory_details_recursive remains the same)
log_directory_details_recursive() {
  local target_dir="$1"
  if [ ! -d "$target_dir" ]; then
    log "Skipping detailed log for non-existent directory: $target_dir"
    return
  fi
  echo
  echo "============================================================"
  echo "--- Detailed Recursive Listing for: $target_dir"
  echo "============================================================"
  ls -laR "$target_dir"
  echo "--- End of Listing for: $target_dir ---"
  echo "============================================================"
  echo
}

# --- Standard Setup Functions ---

# <-- REMOVED: The old setup_python_runtime function is no longer needed.

install_python_dependencies() {
  log "Installing Python dependencies..."
  mkdir "$DEPS_DIR"
  # <-- CHANGED: Use the system-installed python/pip, targeting the local deps dir.
  "python${PYTHON_VERSION}" -m pip install --target="$DEPS_DIR" yt-dlp
  log "Dependencies installed successfully."
}

setup_runtime_environment() {
  # <-- CHANGED: We no longer need to modify the PATH for Python itself.
  # The system Python will already be in the PATH. We only need to set PYTHONPATH.
  export PYTHONPATH="$PWD/$DEPS_DIR"
}


# --- Vercel Build and Handler Functions ---

function build() {
  log "Build Step Started"

  # --- INSTALL SYSTEM DEPENDENCIES ---
  log "Updating package manager and installing system dependencies..."
  # Use dnf to install tree (for logging) and Python itself.
  dnf update -y
  dnf install -y tree "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-pip" # Install python and pip
  log "System dependencies installed."

  # Verify the installation
  "python${PYTHON_VERSION}" --version
  
  # Now install python packages using the system pip
  install_python_dependencies
  
  log "Logging Build Environment Details..."
  log_deployment_structure "."
  
  if [[ -n "${IMPORT_CACHE-}" && -d "$IMPORT_CACHE" ]]; then
    log_directory_details_recursive "$IMPORT_CACHE"
  fi
  
  log "Build Step Finished"
}

function handler() {
  setup_runtime_environment

  log "Logging Runtime Environment Details..."
  log_deployment_structure "/var/task"

  local runtime_cache_dir="./.import-cache"
  if [ -d "$runtime_cache_dir" ]; then
    log_directory_details_recursive "$runtime_cache_dir"
  fi

  # --- Your Custom Application Logic Goes Here ---
  log "Handler invoked. Verifying yt-dlp installation..."
  # <-- CHANGED: Use the specific python version for consistency.
  "python${PYTHON_VERSION}" -c '
import sys
import platform
import yt_dlp

print(f"Hello from Python {sys.version.split()[0]}!")
print(f"Running on platform: {platform.system()} {platform.machine()}")
try:
    print(f"Successfully imported yt-dlp version: {yt_dlp.version.__version__}")
except Exception as e:
    print(f"Error importing or using yt_dlp: {e}")
'
  log "Handler Finished"
}
