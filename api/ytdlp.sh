#!/bin/bash

# A global variable to hold the path to our binary
YTDLP_PATH=""

# The `build` function is executed only once when the serverless function is
# deployed. It's the perfect place to download and set up dependencies.
build() {
  echo "--- Build Phase ---"
  echo "Build-time IMPORT_CACHE is: $IMPORT_CACHE"

  echo "Build: Importing yt-dlp binary..."
  YTDLP_PATH="$(import_file "https://github.com/yt-dlp/yt-dlp/releases/download/2023.12.30/yt-dlp_linux")"
  chmod +x "$YTDLP_PATH"
  echo "Build: yt-dlp downloaded and made executable at $YTDLP_PATH"

  echo "Listing build-time cache contents:"
  # Recursively list the contents of the cache directory to see the structure
  ls -lR "$IMPORT_CACHE"
  echo "--- End Build Phase ---"
}

# The `handler` function is executed for every incoming HTTP request.
handler() {
  # Let the client know we are sending back plain text
  http_response_header "Content-Type" "text/plain"

  # Print debug information to the runtime logs (not the HTTP response)
  echo "--- Handler Phase ---" >&2
  echo "Runtime IMPORT_CACHE variable is: $IMPORT_CACHE" >&2
  echo "Runtime LAMBDA_TASK_ROOT/.import-cache path is: $LAMBDA_TASK_ROOT/.import-cache" >&2

  echo "Listing runtime cache contents:" >&2
  # This output will go to the Vercel Function logs
  ls -lR "$LAMBDA_TASK_ROOT/.import-cache" >&2
  echo "--- End Handler Phase ---" >&2

  # Execute the binary. Its output is the HTTP response body.
  "$YTDLP_PATH" --version
}
