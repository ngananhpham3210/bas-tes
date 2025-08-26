#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# This is a best practice for robust shell scripts.
set -euo pipefail

# --- Configuration ---
# All settings are defined here for easy modification.
readonly PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"
readonly PYTHON_DIR="python"
readonly DEPS_DIR="dependencies"


# --- Helper Functions ---

# A simple logging function for clear section headers.
log() {
  echo "--> $1"
}

# A detailed logging function that performs a deep, recursive list of a directory's contents.
# This is crucial for inspecting the exact file structure and permissions.
log_directory_details() {
  local target_dir="$1"
  
  # Check if the directory exists before attempting to list its contents.
  if [ ! -d "$target_dir" ]; then
    log "Skipping log for non-existent directory: $target_dir"
    return
  fi

  echo
  echo "============================================================"
  echo "--- Detailed Recursive Listing for: $target_dir"
  echo "============================================================"
  # Use `ls -laR` for a detailed, recursive listing including hidden files.
  ls -laR "$target_dir"
  echo "--- End of Listing for: $target_dir ---"
  echo "============================================================"
  echo
}

# Downloads, extracts, and prepares the standalone Python runtime.
setup_python_runtime() {
  log "Setting up Python runtime..."
  local filename
  filename=$(basename "$PYTHON_URL")
  log "Downloading Python from $PYTHON_URL"
  curl --retry 3 -L -o "$filename" "$PYTHON_URL"
  log "Extracting and resolving symlinks..."
  local temp_extract_dir="python_temp_extracted"
  tar -xzf "$filename" -C .
  mv "$PYTHON_DIR" "$temp_extract_dir"
  mkdir "$PYTHON_DIR"
  cp -RL "$temp_extract_dir"/* "$PYTHON_DIR"/
  log "Setting execute permissions on Python binaries..."
  chmod -R +x "$PYTHON_DIR/bin"
  log "Cleaning up intermediate files..."
  rm -rf "$temp_extract_dir"
  rm "$filename"
  log "Python runtime setup complete."
}

# Installs Python packages into the dedicated dependencies directory.
install_python_dependencies() {
  log "Installing Python dependencies..."
  mkdir "$DEPS_DIR"
  "$PYTHON_DIR/bin/pip" install --target="$DEPS_DIR" yt-dlp
  log "Dependencies installed successfully."
}

# Sets the necessary environment variables for our custom Python runtime.
setup_runtime_environment() {
  export PATH="$PWD/$PYTHON_DIR/bin:$PATH"
  export PYTHONPATH="$PWD/$DEPS_DIR"
}


# --- Vercel Build and Handler Functions ---

#
# build() runs ONCE during deployment to prepare the serverless function.
#
function build() {
  log "Build Step Started"
  setup_python_runtime
  install_python_dependencies
  
  # --- DETAILED LOGGING AT BUILD TIME ---
  log "Logging Build Environment Filesystem Details..."
  
  # Define the specific directories relevant to the build environment.
  # `/vercel/work` (or '.') is where our source and output files are.
  # `/usr/local` and `/usr/include` are common locations for system libraries.
  local build_dirs_to_log=("/usr/local" "/usr/include" ".")

  for dir in "${build_dirs_to_log[@]}"; do
    log_directory_details "$dir"
  done
  
  # Also log the import cache if it exists.
  if [[ -n "${IMPORT_CACHE-}" && -d "$IMPORT_CACHE" ]]; then
    log_directory_details "$IMPORT_CACHE"
  fi
  
  log "Build Environment logging complete."
  log "Build Step Finished"
}

#
# handler() runs for EVERY incoming request.
#
function handler() {
  setup_runtime_environment

  # --- DETAILED LOGGING AT RUNTIME ---
  log "Logging Runtime Environment Filesystem Details..."
  
  # Define directories relevant to the AWS Lambda runtime.
  # `/var/task` (or '.') is the root of our deployed function package.
  # `/usr/local` and `/usr/include` show what system libs are available.
  local runtime_dirs_to_log=("/var/task" "/usr/local" "/usr/include")

  for dir in "${runtime_dirs_to_log[@]}"; do
    log_directory_details "$dir"
  done

  # The runtime import cache is located inside our function package.
  local runtime_cache_dir="./.import-cache"
  if [ -d "$runtime_cache_dir" ]; then
    log_directory_details "$runtime_cache_dir"
  fi
  
  log "Runtime Environment logging complete."

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
