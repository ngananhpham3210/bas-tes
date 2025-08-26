#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# This is a best practice for robust shell scripts.
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

  # --- NEW: Log Build-Time Import Cache ---
  # The Vercel builder sets the IMPORT_CACHE env var pointing to the cache directory.
  log "--- Logging Build-Time Import Cache ---"
  if [ -n "${IMPORT_CACHE-}" ] && [ -d "$IMPORT_CACHE" ]; then
    log "IMPORT_CACHE variable is set to: $IMPORT_CACHE"
    log "Recursively listing its contents:"
    # Use `find` for a clear, indented tree view of the directory structure.
    find "$IMPORT_CACHE"
  else
    log "IMPORT_CACHE directory not found or variable is not set."
  fi
  log "--- End Build-Time Cache Log ---"
  # --- END NEW ---

  log "Build Step Finished"
}

#
# handler() runs for EVERY incoming request.
#
function handler() {
  # First, set up the environment so our custom Python is used.
  setup_runtime_environment

  # --- NEW: Log Runtime Import Cache ---
  # The builder packages the necessary cache files into the `.import-cache` directory.
  log "--- Logging Runtime Import Cache ---"
  local runtime_cache_dir="./.import-cache"
  if [ -d "$runtime_cache_dir" ]; then
    log "Found runtime cache directory at: $runtime_cache_dir"
    log "Recursively listing its contents:"
    find "$runtime_cache_dir"
  else
    log "Runtime cache directory '$runtime_cache_dir' not found."
  fi
  log "--- End Runtime Cache Log ---"
  # --- END NEW ---

  # --- Your Custom Application Logic Goes Here ---
  log "Handler invoked. Verifying Python environment..."
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
