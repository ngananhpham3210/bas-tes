#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
readonly PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"
readonly PYTHON_DIR="python"
readonly DEPS_DIR="dependencies"


# --- Helper Functions ---

log() {
  # Prepending with "»" to distinguish our logs from the runtime's logs.
  echo "» $1"
}

setup_python_runtime() {
  log "Setting up Python runtime..."
  local filename
  filename=$(basename "$PYTHON_URL")

  log "Downloading Python from $PYTHON_URL"
  # Use the `import` command provided by the runtime to cache the download
  # This speeds up subsequent builds.
  import curl "$PYTHON_URL" > "$filename"

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

function build() {
  log "Build Step Started"
  setup_python_runtime
  install_python_dependencies

  # --- NEW: LOG IMPORT-CACHE AT BUILD TIME ---
  # The `$IMPORT_CACHE` variable is set by the Vercel builder (`build.sh`).
  # This shows us what the `import.sh` script has cached during this build.
  log "Inspecting import-cache contents at BUILD TIME..."
  if [ -d "$IMPORT_CACHE" ]; then
    # Use `ls -lR` for a recursive, detailed listing.
    ls -lR "$IMPORT_CACHE"
  else
    log "IMPORT_CACHE directory not found at: $IMPORT_CACHE"
  fi
  # --- END NEW ---

  log "Build Step Finished"
}

function handler() {
  setup_runtime_environment

  # --- NEW: LOG IMPORT-CACHE AT RUNTIME ---
  # The `$IMPORT_CACHE` variable is set by the `bootstrap` script.
  # Its path within the Lambda is `$LAMBDA_TASK_ROOT/.import-cache`.
  # This shows us what was packaged into the final serverless function.
  log "Inspecting import-cache contents at RUNTIME..."
  if [ -d "$IMPORT_CACHE" ]; then
    ls -lR "$IMPORT_CACHE"
  else
    log "IMPORT_CACHE directory not found at runtime: $IMPORT_CACHE"
  fi
  # --- END NEW ---

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
