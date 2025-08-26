#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
readonly PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"
readonly PYTHON_DIR="python"
readonly DEPS_DIR="dependencies" # This folder will contain yt-dlp and its dependencies


# --- Helper Functions ---

log() {
  echo "--> $1"
}

# Logs the structure of the deployment directory (`.` at build time, `/var/task` at runtime).
# It intelligently avoids deep recursion into the noisy 'python' and 'dependencies' folders.
log_deployment_structure() {
  local target_dir="$1"
  
  if [ ! -d "$target_dir" ]; then
    log "Directory not found for structure log: $target_dir"
    return
  fi

  echo
  echo "============================================================"
  echo "--- Structure of Deployment Directory: $target_dir"
  echo "--- (Excluding contents of 'python' and 'dependencies')"
  echo "============================================================"
  
  if command -v tree &> /dev/null; then
    # PREFERRED METHOD: Use `tree` to show a clean hierarchy, ignoring the specified folders.
    # -L 3: Recurse up to 3 levels deep.
    # -I 'python|dependencies': Ignore directories named 'python' or 'dependencies'.
    tree -L 3 -I "$PYTHON_DIR|$DEPS_DIR" "$target_dir"
  else
    # FALLBACK METHOD: If `tree` is not installed, just list the top-level contents.
    # This shows that the excluded directories exist without listing their thousands of files.
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

setup_python_runtime() {
  log "Setting up Python runtime..."
  local filename; filename=$(basename "$PYTHON_URL")
  curl --retry 3 -L -o "$filename" "$PYTHON_URL"
  local temp_extract_dir="python_temp_extracted"
  tar -xzf "$filename" -C . && mv "$PYTHON_DIR" "$temp_extract_dir"
  mkdir "$PYTHON_DIR" && cp -RL "$temp_extract_dir"/* "$PYTHON_DIR"/
  chmod -R +x "$PYTHON_DIR/bin"
  rm -rf "$temp_extract_dir" "$filename"
  log "Python runtime setup complete."
}

install_python_dependencies() {
  log "Installing Python dependencies..."
  mkdir "$DEPS_DIR"
  "$PYTHON_DIR/bin/pip" install --target="$DEPS_DIR" yt-dlp
  log "Dependencies installed successfully."
}

setup_runtime_environment() {
  export PATH="$PWD/$PYTHON_DIR/bin:$PATH"
  export PYTHONPATH="$PWD/$DEPS_DIR"
}


# --- Vercel Build and Handler Functions ---

function build() {
  log "Build Step Started"
  setup_python_runtime
  install_python_dependencies
  
  log "Logging Build Environment Details..."
  
  # Log the structure of the build output directory (`.`), excluding the large folders.
  log_deployment_structure "."
  
  # Log the full contents of the import cache, as its details are often important.
  if [[ -n "${IMPORT_CACHE-}" && -d "$IMPORT_CACHE" ]]; then
    log_directory_details_recursive "$IMPORT_CACHE"
  fi
  
  log "Build Step Finished"
}

function handler() {
  setup_runtime_environment

  log "Logging Runtime Environment Details..."

  # Log the structure of the final deployed function at /var/task.
  log_deployment_structure "/var/task"

  # Log the full contents of the runtime import cache.
  local runtime_cache_dir="./.import-cache"
  if [ -d "$runtime_cache_dir" ]; then
    log_directory_details_recursive "$runtime_cache_dir"
  fi

  # --- Your Custom Application Logic Goes Here ---
  log "Handler invoked. Verifying yt-dlp installation..."
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
