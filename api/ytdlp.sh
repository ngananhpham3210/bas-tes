#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
readonly PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"
readonly PYTHON_DIR="python"
readonly DEPS_DIR="dependencies"

# --- Helper Functions ---

log() {
  echo "--> $1"
}

setup_python_runtime() {
  log "Setting up Python runtime..."
  local filename
  filename=$(basename "$PYTHON_URL")

  log "Downloading Python from $PYTHON_URL"
  # The `import` tool from @vercel/bash provides `curl`
  import "curl"
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

#
# build() runs ONCE during deployment.
# The @vercel/bash runtime populates .import-cache BEFORE this function runs.
#
function build() {
  log "Build Step Started"
  
  # --- ADDED: LOG IMPORT-CACHE AT BUILD TIME ---
  log "Inspecting .import-cache contents at build time..."
  # The $IMPORT_CACHE variable is set by the Vercel builder (`src/build.sh`)
  if [ -d "$IMPORT_CACHE" ]; then
    echo "--- .import-cache location: $IMPORT_CACHE ---"
    # Using `ls -lR` for a recursive, detailed directory listing.
    ls -lR "$IMPORT_CACHE"
    echo "------------------------------------------------"
  else
    echo "WARNING: .import-cache directory not found at build time."
  fi
  # --- END LOGGING ---
  
  setup_python_runtime
  install_python_dependencies
  
  log "Build Step Finished"
}

#
# handler() runs for EVERY incoming request.
#
function handler() {
  # --- ADDED: LOG IMPORT-CACHE AT RUNTIME ---
  log "Inspecting .import-cache contents at runtime..."
  # The $IMPORT_CACHE variable is set by the Lambda bootstrap (`src/bootstrap`)
  if [ -d "$IMPORT_CACHE" ]; then
    echo "--- .import-cache location: $IMPORT_CACHE ---"
    # The cache is now located inside the Lambda task root.
    ls -lR "$IMPORT_CACHE"
    echo "------------------------------------------------"
  else
    # This should not happen if the build was successful.
    echo "ERROR: .import-cache directory not found at runtime."
  fi
  # --- END LOGGING ---

  # First, set up the environment so our custom Python is used.
  setup_runtime_environment

  # --- Your Custom Application Logic Goes Here ---
  log "Handler invoked. Verifying environment..."
  echo
  echo "Python Version: $(python3 --version)"
  echo
  log "Running verification script..."
  python3 -c '
import sys, platform, yt_dlp
print(f"Hello from Python {sys.version.split()[0]}!")
print(f"Successfully imported yt-dlp version: {yt_dlp.version.__version__}")
'
  echo
  log "Handler Finished"
}
