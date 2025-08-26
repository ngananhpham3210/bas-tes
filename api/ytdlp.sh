#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
# All settings are defined here for easy modification.

# URL for the standalone Python build. Must match Vercel's runtime architecture (x86_64).
readonly PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"

# Directory names for the Python runtime and its dependencies.
readonly PYTHON_DIR="python"
readonly DEPS_DIR="dependencies"


# --- Helper Functions ---

# A simple logging function to make build output clear.
log() {
  echo "--> $1"
}

# Downloads, extracts, and prepares the standalone Python runtime.
setup_python_runtime() {
  log "Setting up Python runtime..."
  local filename
  filename=$(basename "$PYTHON_URL")

  log "Downloading Python from $PYTHON_URL"
  curl --retry 3 -L -o "$filename" "$PYTHON_URL"

  # The archive contains symlinks which can cause issues. We extract and then
  # perform a deep copy (-L) to resolve all symlinks into actual files.
  log "Extracting and resolving symlinks..."
  local temp_extract_dir="python_temp_extracted"
  tar -xzf "$filename" -C . # Extract to current dir, creates 'python' folder
  mv "$PYTHON_DIR" "$temp_extract_dir" # Rename to avoid conflict
  mkdir "$PYTHON_DIR" # Create the final clean directory
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
  
  # Use the specific pip from our downloaded Python to install packages.
  # The --target flag installs them into a local directory.
  "$PYTHON_DIR/bin/pip" install --target="$DEPS_DIR" yt-dlp
  
  log "Dependencies installed successfully."
}

# Sets the necessary environment variables for our custom Python runtime.
setup_runtime_environment() {
  # Add our custom Python's `bin` directory to the PATH.
  export PATH="$PWD/$PYTHON_DIR/bin:$PATH"

  # Add our dependencies directory to Python's module search path.
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
  
  # --- LOGGING IMPORT CACHE AT BUILD TIME ---
  log "--- Logging Import Cache (Build Time) ---"
  # The builder (`index.ts`) sets the IMPORT_CACHE env var to the path
  # where build-time cache files are stored.
  if [[ -n "${IMPORT_CACHE-}" && -d "$IMPORT_CACHE" ]]; then
    log "Found import cache at: $IMPORT_CACHE"
    # Recursively list the contents to see the structure.
    ls -laR "$IMPORT_CACHE"
  else
    log "Build-time import cache directory not found or IMPORT_CACHE is not set."
  fi
  log "--- End Build Time Import Cache Log ---"

  log "Build Step Finished"
}

#
# handler() runs for EVERY incoming request.
#
function handler() {
  # First, set up the environment so our custom Python is used.
  setup_runtime_environment

  # --- LOGGING IMPORT CACHE AT RUNTIME ---
  log "--- Logging Import Cache (Runtime) ---"
  # The builder (`index.ts`) packages the necessary cache files into
  # a './.import-cache' directory within the Lambda.
  local runtime_cache_dir="./.import-cache"
  if [ -d "$runtime_cache_dir" ]; then
    log "Found runtime import cache at: $runtime_cache_dir"
    # Recursively list the contents to see what was included in the final function.
    ls -laR "$runtime_cache_dir"
  else
    log "Runtime import cache directory not found at: $runtime_cache_dir"
  fi
  log "--- End Runtime Import Cache Log ---"
  
  # --- Your Custom Application Logic Goes Here ---
  log "Handler invoked. Verifying environment..."
  echo
  echo "Runtime Architecture: $(uname -m)"
  echo "Python Version: $(python3 --version)"
  echo
  log "Running verification script..."
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
  echo
  log "Handler Finished"
}
