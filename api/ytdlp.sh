#!/bin/bash
set -euo pipefail

# This function runs during the Vercel build process.
function build() {
  echo "--- Python Build Step ---"

  PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"
  FILENAME=$(basename "$PYTHON_URL")

  echo "Downloading Python from $PYTHON_URL..."
  curl --retry 3 -L -o "$FILENAME" "$PYTHON_URL"
  echo "Download complete."

  # The archive contains many symbolic links which cause errors in the Vercel builder.
  # To fix this, we will perform a copy that dereferences all links.
  # -R = recursive
  # -L = dereference (follow) all symbolic links

  # Step 1: Extract the archive. This will create a 'python' directory.
  echo "Extracting $FILENAME..."
  tar -xzf "$FILENAME"

  # Step 2: Create a new, clean directory for the final output.
  mkdir python_final

  # Step 3: Copy from the extracted dir to the final dir, resolving all symlinks.
  echo "Copying and resolving symlinks to create a clean build output..."
  cp -RL python/* python_final/

  # Step 4: Clean up the original extracted directory and the archive.
  echo "Cleaning up intermediate files..."
  rm -rf python
  rm "$FILENAME"

  # Step 5: Rename the clean directory to 'python' so the handler can find it.
  mv python_final python

  echo "--- Python Build Step Finished ---"
}

# This function runs for every incoming request in the AWS Lambda environment.
# It does not need to be changed.
function handler() {
  # Add the `python/bin` directory (created during the build step) to the PATH.
  export PATH="$PWD/python/bin:$PATH"

  # --- Your Python logic goes here ---

  # Example: Check the Python version
  echo "Checking Python version:"
  python3 --version
  echo

  # Example: Run an inline Python script
  echo "Running an inline Python script:"
  python3 -c '
import sys
import platform

print(f"Hello from Python {sys.version}!")
print(f"Running on platform: {platform.system()} {platform.machine()}")
'
}
