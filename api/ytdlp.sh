#!/bin/bash
set -euo pipefail

# ==============================================================================
# BUILD-TIME LOGIC
# ==============================================================================
function build() {
  echo "--- Python Standalone Build Step ---"

  # 1. Define variables with a non-conflicting directory name
  PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"
  ARCHIVE_NAME="python.tar.gz"
  # Use a neutral name like "python" instead of ".import-cache"
  INSTALL_DIR="python"

  # 2. Ensure the target directory exists
  mkdir -p "$INSTALL_DIR"

  # 3. Download the archive
  echo "Downloading Python from $PYTHON_URL..."
  curl -L -o "$ARCHIVE_NAME" "$PYTHON_URL"

  # 4. Extract the archive into the target directory
  # Use --strip-components=1 to move the contents of the inner 'python' folder
  # directly into our target directory, avoiding a nested 'python/python' structure.
  echo "Extracting Python to $INSTALL_DIR/..."
  tar -xzf "$ARCHIVE_NAME" -C "$INSTALL_DIR/" --strip-components=1

  # 5. Clean up the downloaded archive
  rm "$ARCHIVE_NAME"

  echo "Python installation complete. It will be available at ./$INSTALL_DIR"
  echo "------------------------------------"
}


# ==============================================================================
# RUNTIME LOGIC
# ==============================================================================
function handler() {
  # Update the path to the Python executable to match the new INSTALL_DIR
  PYTHON_EXEC="./python/bin/python3"

  echo "Invoking Python script..."

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
