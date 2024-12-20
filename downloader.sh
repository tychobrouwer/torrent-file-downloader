#!/bin/bash

# Read input file
INPUT_FILE="input.txt"

if [[ ! -f $INPUT_FILE ]]; then
  echo "Input file '$INPUT_FILE' not found! Please create it with the following format:"
  echo -e "TYPE=directory|file\nURL=https://example.com/path/to/resource\nREGEX=optional_regex\n\nRepeat the above lines for multiple entries."
  exit 1
fi

# Create a directory to store downloaded .torrent files
DOWNLOAD_DIR="downloaded_torrents"
mkdir -p "$DOWNLOAD_DIR"

# Process each block in the input file
TYPE=""
URL=""
REGEX=""
while IFS= read -r line; do
  # Skip empty lines and comments
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  # Parse TYPE, URL, and REGEX
  if [[ "$line" =~ ^TYPE=(.+)$ ]]; then
    TYPE="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^URL=(.+)$ ]]; then
    URL="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^REGEX=(.+)$ ]]; then
    REGEX="${BASH_REMATCH[1]}"
  else
    echo "Invalid line in input file: $line"
    continue
  fi

  TYPE=$(echo $TYPE | tr -d '\r')
  URL=$(echo $URL | tr -d '\r')
  REGEX=$(echo $REGEX | tr -d '\r')

  # Ensure TYPE and URL are set
  if [[ -n "$TYPE" && -n "$URL" ]]; then
    if [[ "$TYPE" == "directory" && -n "$REGEX" ]]; then
      echo "Processing directory: $URL"

      # Fetch the list of files from the URL
      LINKS="$(lynx -dump -listonly -hiddenlinks=listonly $URL | awk '{print $2}' | uniq)"

      if [[ -z "$LINKS" ]]; then
        echo "Failed to fetch content from $URL."
        continue
      fi

      # Extract matching links
      TORRENT_LINKS=$(echo "$LINKS" | grep -E "^.*\\.torrent$")
      MATCHING_LINKS=$(echo "$TORRENT_LINKS" | grep -P "$REGEX")

      if [[ -z "$MATCHING_LINKS" ]]; then
        echo "No matching files found at $URL."
        continue
      fi

      # Download each matching file
      for LINK in $MATCHING_LINKS; do
        if [[ $LINK != http* ]]; then
          LINK="$URL/$LINK"
        fi

        FILENAME=$(basename "$LINK")
        echo "Downloading $FILENAME..."
        curl -s -o "$DOWNLOAD_DIR/$FILENAME" "$LINK"

        if [[ $? -eq 0 ]]; then
          echo "$FILENAME downloaded successfully."
        else
          echo "Failed to download $FILENAME."
        fi
      done

      # Reset TYPE, URL, and REGEX for the next block
      TYPE=""
      URL=""
      REGEX=""

    elif [[ "$TYPE" == "file" ]]; then
      echo "Downloading file: $URL"

      FILENAME=$(basename "$URL")
      curl -s -o "$DOWNLOAD_DIR/$FILENAME" "$URL"

      if [[ $? -eq 0 ]]; then
        echo "$FILENAME downloaded successfully."
      else
        echo "Failed to download $FILENAME."
      fi

      # Reset TYPE, URL, and REGEX for the next block
      TYPE=""
      URL=""
      REGEX=""

    fi
  fi

done <"$INPUT_FILE"

echo "All specified files and directories have been processed. Downloaded files are in $DOWNLOAD_DIR."
