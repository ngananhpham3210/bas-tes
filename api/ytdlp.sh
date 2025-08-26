#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
# We no longer need PYTHON_URL or PYTHON_DIR, as we're using the system's Python.
readonly DEPS_DIR="dependencies" # This folder will contain yt-dlp and its dependencies


# --- Helper Functions ---

log() {
  echo "--> $1"
}

# Logs the structure of the deployment directory (`.` at build time, `/var/task` at runtime).
# It intelligently avoids deep recursion into the noisy 'dependencies' folder.
log_deployment_structure() {
  local target_dir="$1"
  
  if [ ! -d "$target_dir" ]; then
    log "Directory not found for structure log: $target_dir"
    return
  fi

  echo
  echo "============================================================"
  echo "--- Structure of Deployment Directory: $target_dir"
  echo "--- (Excluding contents of 'dependencies')"
  echo "============================================================"
  
  if command -v tree &> /dev/null; then
    # PREFERRED METHOD: Use `tree` to show a clean hierarchy.
    # We now only need to ignore the dependencies directory.
    tree -L 3 -I "$DEPS_DIR" "$target_dir"
  else
    # FALLBACK METHOD: If `tree` is not installed, just list the top-level contents.
    log "NOTE: 'tree' command not found. Falling back to a non-recursive 'ls' listing."
    ls -la "$target_dir"
  fi

  echo "--- End of Structure Log for: $target_dir ---"
  echo "============================================================"
  echo
}

# A separate function for a full, deep, recursive log, used only for the import-cache.
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

# --- REMOVED ---
# The setup_python_runtime function is no longer needed.

install_python_dependencies() {
  log "Installing Python dependencies..."
  mkdir -p "$DEPS_DIR"
  # --- CHANGED ---
  # Use the system's `python3` and `pip` to install packages into our target directory.
  # Using `python3 -m pip` is a best practice to ensure you're using the correct pip.
  python3 -m pip install --target="$DEPS_DIR" yt-dlp
  log "Dependencies installed successfully."
}

setup_runtime_environment() {
  # --- CHANGED ---
  # We no longer need to modify the PATH, as `python3` is already in the system PATH.
  # We ONLY need to set PYTHONPATH so the interpreter can find our vendored dependencies.
  export PYTHONPATH="$PWD/$DEPS_DIR"
}


# --- Vercel Build and Handler Functions ---

function build() {
  log "Build Step Started"

  # --- NEW ---
  # Install system-level tools needed for our build.
  # Vercel's environment uses `yum`. We install pip and the tree utility.
  # `python3-devel` is good practice in case any packages need to compile C extensions.
  log "Installing system dependencies: python3-pip, python3-devel, tree..."
  yum install -y python3-pip python3-devel tree
  
  # --- CHANGED ---
  # We now just call the dependency installer directly.
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
  # This command now uses the system `python3` from the runtime environment.
  # Because PYTHONPATH is set, it can import `yt_dlp` from the `dependencies` folder.
  python3 -c '
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
