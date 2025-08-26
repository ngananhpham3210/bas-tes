# FILE: api/index.sh
#!/bin/bash
set -euo pipefail

# This `build` function runs once during `vercel build`
function build() {
  echo "--- Installing Standalone Python 3.12 ---"

  # 1. Define the URL and the target directory inside the Lambda
  local PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"
  
  # This will become /var/task/.import-cache/python at runtime
  local TARGET_DIR=".import-cache/python"

  # 2. Create the target directory
  # The `.` refers to the build output directory
  mkdir -p "$TARGET_DIR"

  # 3. Download and extract the archive in one step
  #    - `curl -Ls`: Download, follow redirects (-L), and be silent (-s)
  #    - `tar -xz`: Extract (-x) from a gzipped (-z) archive
  #    - `-C "$TARGET_DIR"`: Extract into our target directory
  #    - `--strip-components=1`: Remove the top-level directory (e.g., `python/`) from the archive
  echo "Downloading and extracting Python..."
  curl -Ls "$PYTHON_URL" | tar -xz -C "$TARGET_DIR" --strip-components=1

  echo "--- Python installation complete ---"
}

# This `handler` function runs on every invocation of the Lambda
function handler() {
  # At runtime, our python binary is now available at this relative path
  local PYTHON_BIN="./.import-cache/python/bin/python3"

  # Let's execute it to prove it works
  echo "Checking installed Python version:"
  $PYTHON_BIN --version
  
  echo "" # Newline for cleaner logs

  # You can now run any Python script you want
  echo "Running an inline Python script:"
  $PYTHON_BIN -c '
import os
import sys

print(f"Hello from Python {sys.version}!")
print(f"Running in directory: {os.getcwd()}")
'
}
