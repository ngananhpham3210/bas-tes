#!/bin/bash

# The `build` function runs once at deploy time to prepare the environment.
build() {
  echo "--- Build Phase ---"
  echo "Downloading yt-dlp binary..."

  # 1. Download the file into the cache and get its location.
  #    The returned path will be something like:
  #    .../links/https/github.com/.../yt-dlp_linux
  local ytdlp_source_path
  ytdlp_source_path="$(import_file "https://github.com/yt-dlp/yt-dlp/releases/download/2023.12.30/yt-dlp_linux")"

  # 2. Make the downloaded file executable.
  chmod +x "$ytdlp_source_path"

  # 3. Define the desired, predictable path inside the `bin` directory.
  local ytdlp_bin_path="$IMPORT_CACHE/bin/yt-dlp"

  # 4. Create a symbolic link from the desired path to the actual cached file.
  ln -s "$ytdlp_source_path" "$ytdlp_bin_path"

  echo "Build complete. Symlink created for yt-dlp in the bin directory."

  # 5. List the contents of the bin directory to verify in the build logs.
  echo "Final contents of '$IMPORT_CACHE/bin':"
  ls -l "$IMPORT_CACHE/bin"
  echo "--- End Build Phase ---"
}

# The `handler` function runs on every request.
handler() {
  # Let the client know we are sending back plain text
  http_response_header "Content-Type" "text/plain"

  # The path to our binary is now fixed and predictable because of our build step.
  local YTDLP_PATH="$IMPORT_CACHE/bin/yt-dlp"

  # For debugging, let's list the bin directory again at runtime.
  echo "--- Handler: Listing '$IMPORT_CACHE/bin' directory ---" >&2
  ls -l "$IMPORT_CACHE/bin" >&2
  echo "--- End of listing ---" >&2

  # Check if the file exists and is executable before running it
  if [ -x "$YTDLP_PATH" ]; then
    # Execute the binary. Its output is the HTTP response body.
    "$YTDLP_PATH" --version
  else
    # If something went wrong, send an error response.
    http_response_code 500
    echo "Error: yt-dlp binary not found or not executable at '$YTDLP_PATH'."
  fi
}
