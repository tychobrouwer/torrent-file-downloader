#!/bin/bash

# Read input file
INPUT_FILE="input.txt"

if [[ ! -f $INPUT_FILE ]]; then
  echo "Input file '$INPUT_FILE' not found! Please create it with the following format:"
  echo -e "TYPE=directory|file\nURL=https://example.com/path/to/resource\nREGEX=optional_regex\n\nRepeat the above lines for multiple entries."
  exit 1
fi

# Create a directory to store downloaded .torrent files
DOWNLOAD_DIR="~/torrents_watch"
mkdir -p "$DOWNLOAD_DIR"

# Process each block in the input file
TYPE=""
URL=""
REGEX=""
while IFS= read -r line; do
  # Skip lines not starting with TYPE, URL, or REGEX
  if [[ ! "$line" =~ ^TYPE= && ! "$line" =~ ^URL= && ! "$line" =~ ^REGEX= ]]; then
    continue
  fi

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

  random_chars=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 8)

  # Ensure TYPE and URL are set
  if [[ -n "$TYPE" && -n "$URL" ]]; then
    # Select lastest directory from URL
    if [[ "$TYPE" == "select-latest-directory" ]]; then
      echo "Processing latest directory: $URL"

      # Fetch the list of directories from the URL
      LINKS="$(lynx -dump -listonly -hiddenlinks=listonly $URL?r=$random_chars | awk '{print $2}' | uniq)"

      if [[ -z "$LINKS" ]]; then
        echo "Failed to fetch content from $URL."
        continue
      fi

      # Extract directories
      DIRECTORIES=$(echo "$LINKS" | grep -E "^.*\/$")

      if [[ -z "$DIRECTORIES" ]]; then
        echo "No directories found at $URL."
        continue
      fi

      # Select the latest directory
      TYPE="from-directory"
      URL=$(echo "$DIRECTORIES" | sort -r | head -n 1)

      if [[ -z "$URL" ]]; then
        echo "Failed to select the latest directory from $URL."
        continue
      fi
    fi

    # Select lastest file from URL
    if [[ "$TYPE" == "select-latest-file" && -n "$REGEX" ]]; then
      echo "Processing latest file: $URL"

      # Fetch the list of files from the URL
      LINKS="$(lynx -dump -listonly -hiddenlinks=listonly $URL?r=$random_chars | awk '{print $2}' | uniq)"

      if [[ -z "$LINKS" ]]; then
        echo "Failed to fetch content from $URL."
        continue
      fi

      TORRENT_LINKS=$(echo "$LINKS" | grep -E "^.*\\.torrent$")
      MATCHING_LINKS=$(echo "$TORRENT_LINKS" | grep -P "$REGEX")

      if [[ -z "$MATCHING_LINKS" ]]; then
        echo "No matching files found at $URL."
        continue
      fi

      # Select the latest file
      TYPE="file"
      URL=$(echo "$MATCHING_LINKS" | sort -r | head -n 1)

      if [[ -z "$URL" ]]; then
        echo "Failed to select the latest file from $URL."
        continue
      fi
    fi

    if [[ "$TYPE" == "from-directory" && -n "$REGEX" ]]; then
      echo "Processing directory: $URL"

      # Fetch the list of files from the URL
      LINKS="$(lynx -dump -listonly -hiddenlinks=listonly $URL?r=$random_chars | awk '{print $2}' | uniq)"

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
