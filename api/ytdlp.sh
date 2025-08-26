#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

#
# This function runs ONCE during the Vercel build process.
# Its job is to download and prepare the Python runtime environment.
# Everything created in this function will be included in the final serverless function.
#
function build() {
  echo "--- Build Step Started ---"

  # The URL for the standalone Python build.
  # CRITICAL: This version is specifically for aarch64 (ARM64) and Linux,
  # which matches the Vercel runtime environment and fixes the "Illegal instruction" error.
  PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"
  FILENAME=$(basename "$PYTHON_URL")

  echo "Downloading Python for ARM64 from $PYTHON_URL..."
  curl --retry 3 -L -o "$FILENAME" "$PYTHON_URL"
  echo "Download complete."

  # FIX for "ENAMETOOLONG" error:
  # The archive contains many symbolic links. We must resolve them into actual file copies.
  # Step 1: Extract the archive into a temporary directory named 'python'.
  echo "Extracting archive..."
  tar -xzf "$FILENAME"

  # Step 2: Create a new, clean directory for the final output.
  mkdir python_final

  # Step 3: Copy from the extracted dir to the final dir, resolving all symlinks.
  # -R = recursive, -L = dereference (follow) symbolic links.
  echo "Copying and resolving symlinks to create a clean build output..."
  cp -RL python/* python_final/

  # Step 4: Clean up the original extracted directory and the downloaded archive.
  echo "Cleaning up intermediate files..."
  rm -rf python
  rm "$FILENAME"

  # Step 5: Rename the clean directory to 'python' so the handler can find it.
  mv python_final python

  # FIX for "FUNCTION_INVOCATION_FAILED" error:
  # Add execute permissions to all files in the python/bin directory.
  echo "Setting execute permissions on Python binaries..."
  chmod -R +x python/bin

  # --- NEW: Install yt-dlp ---
  echo "Installing yt-dlp using our standalone Python's pip..."
  # Create a directory to hold our dependencies
  mkdir dependencies
  # Use the specific pip from our downloaded Python to install yt-dlp
  # into the 'dependencies' directory.
  python/bin/pip install --target=dependencies yt-dlp
  echo "yt-dlp installation complete."
  # --- END NEW ---

  echo "--- Build Step Finished ---"
}

#
# This function runs for EVERY incoming request to your API endpoint.
# The Python environment prepared in the `build` function is available here.
#
function handler() {
  # Add our custom Python's `bin` directory to the PATH environment variable.
  # This makes the `python3` command available.
  export PATH="$PWD/python/bin:$PATH"

  # --- NEW: Add our dependencies to Python's search path ---
  # This tells Python to look for modules in our 'dependencies' folder.
  export PYTHONPATH="$PWD/dependencies"

  # --- Your Custom Logic Goes Here ---

  # First, let's verify everything is working correctly.
  echo "--- Handler Invoked ---"
  echo
  echo "Runtime Architecture:"
  uname -m
  echo

  echo "Checking Python version:"
  python3 --version
  echo

  echo "Running an inline Python script to test yt-dlp:"
  python3 -c '
import sys
import platform
import yt_dlp  # Try to import the library

print(f"Hello from Python {sys.version}!")
print(f"Running on platform: {platform.system()} {platform.machine()}")
print(f"Successfully imported yt-dlp version: {yt_dlp.version.__version__}")
'
  echo
  echo "--- Handler Finished ---"
}
