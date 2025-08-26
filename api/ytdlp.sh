#!/bin/bash
set -euo pipefail

# ==============================================================================
# BUILD-TIME LOGIC
# This `build` function is automatically executed by the Vercel Bash builder
# during the `vercel build` step.
# ==============================================================================
function build() {
  echo "--- Python Standalone Build Step ---"

  # 1. Define variables for clarity
  PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"
  ARCHIVE_NAME="python.tar.gz"
  INSTALL_DIR=".import-cache" # This will become /var/task/.import-cache in the Lambda

  # 2. Ensure the target directory exists
  mkdir -p "$INSTALL_DIR"

  # 3. Download the archive
  echo "Downloading Python from $PYTHON_URL..."
  # Use -L to follow redirects and -o to specify output file
  curl -L -o "$ARCHIVE_NAME" "$PYTHON_URL"

  # 4. Extract the archive into the target directory
  # The standalone build extracts to a `python/` sub-directory
  echo "Extracting Python to $INSTALL_DIR/..."
  tar -xzf "$ARCHIVE_NAME" -C "$INSTALL_DIR/"

  # 5. Clean up the downloaded archive to keep the Lambda size small
  rm "$ARCHIVE_NAME"

  echo "Python installation complete. It will be available at $INSTALL_DIR/python"
  echo "------------------------------------"
}


# ==============================================================================
# RUNTIME LOGIC
# This `handler` function is executed by the Vercel Bash runtime for each
# incoming HTTP request.
# ==============================================================================
function handler() {
  # The Python executable is now available at a relative path
  PYTHON_EXEC="./.import-cache/python/bin/python3"

  echo "Invoking Python script..."

  # Example: Execute a simple Python script inline
  local python_output
  python_output=$($PYTHON_EXEC -c '
import sys
import platform

print(f"Hello from Python {sys.version} on {platform.system()}!")
print("This script is running inside a Vercel Bash Lambda.")
')

  # Set HTTP headers and response code
  http_response_code 200
  http_response_header "Content-Type" "text/plain"

  # Send the output from the Python script as the HTTP response body
  echo "$python_output"
}
