#!/bin/bash
set -euo pipefail

# This function runs during the Vercel build process.
# Its job is to download the standalone Python distribution and extract it.
# The resulting `python` directory will be included in the Lambda package.
function build() {
  echo "--- Python Build Step ---"

  # Define the URL and the filename for the Python distribution
  PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"
  FILENAME=$(basename "$PYTHON_URL")

  # Download the archive. The `curl` command is available in the build env.
  echo "Downloading Python from $PYTHON_URL..."
  curl --retry 3 -L -o "$FILENAME" "$PYTHON_URL"
  echo "Download complete."

  # Extract the contents. This will create a `python` directory.
  echo "Extracting $FILENAME..."
  tar -xzf "$FILENAME"
  echo "Extraction complete."

  # Clean up the downloaded archive to keep the Lambda size small
  rm "$FILENAME"
  echo "Cleaned up archive."

  echo "--- Python Build Step Finished ---"
}

# This function runs for every incoming request in the AWS Lambda environment.
function handler() {
  # Add the `python/bin` directory (created during the build step) to the PATH.
  # This makes the `python3` executable available to this script.
  # $LAMBDA_TASK_ROOT is the current directory, so we can use a relative path.
  export PATH="$PWD/python/bin:$PATH"

  # --- Your Python logic goes here ---

  # Example 1: Check the Python version
  echo "Checking Python version..."
  python3 --version
  echo ""

  # Example 2: Run a simple inline Python script
  echo "Running an inline Python script:"
  python3 -c '
import sys
import platform

print(f"Hello from Python {sys.version}!")
print(f"Running on platform: {platform.system()} {platform.machine()}")
'
}
