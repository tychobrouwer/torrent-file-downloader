#!/bin/bash

# Read input file
INPUT_FILE="input.txt"

if [[ ! -f $INPUT_FILE ]]; then
  echo "Input file '$INPUT_FILE' not found! Please create it with the following format:"
  echo -e "TYPE=directory|file\nURL=https://example.com/path/to/resource\nREGEX=optional_regex\n\nRepeat the above lines for multiple entries"
  exit 1
fi

# Create a directory to store downloaded .torrent files
DOWNLOAD_DIR="watched"
mkdir -p "$DOWNLOAD_DIR"

echo "" >>"$INPUT_FILE"

# Process each block in the input file
TYPE=""
URL=""
REGEX=""
SUFFIX=""

process=0

while IFS= read -r line; do
  line=$(echo $line | tr -d '\r')

  # Skip lines not starting with TYPE, URL, or REGEX
  if [[ ! "$line" =~ ^TYPE= && ! "$line" =~ ^URL= && ! "$line" =~ ^REGEX= && ! "$line" =~ ^SUFFIX= && $line != "" ]]; then
    continue
  fi

  # Parse TYPE, URL, and REGEX
  if [[ "$line" =~ ^TYPE=(.+)$ ]]; then
    TYPE="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^URL=(.+)$ ]]; then
    URL="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^REGEX=(.+)$ ]]; then
    REGEX="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^SUFFIX=(.+)$ ]]; then
    SUFFIX="${BASH_REMATCH[1]}"
  elif [[ "$line" == "" ]]; then
    process=1
  else
    echo "Invalid line in input file: $line"
    continue
  fi

  random_chars=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 8)

  # Ensure TYPE and URL are set
  if [[ process -eq 1 ]]; then
    # Select lastest directory from URL
    if [[ "$TYPE" == "select-latest-directory" ]]; then
      echo "Processing latest directory: $URL"

      # Fetch the list of directories from the URL
      LINKS="$(lynx -dump -listonly -hiddenlinks=listonly $URL?r=$random_chars | awk '{print $2}' | uniq)"

      if [[ -z "$LINKS" ]]; then
        echo "Failed to fetch content from $URL"

        TYPE=""
        URL=""
        REGEX=""
        SUFFIX=""
        continue
      fi

      # Extract directories
      DIRECTORIES=$(echo "$LINKS" | grep -E "^.*\/$")

      if [[ -z "$DIRECTORIES" ]]; then
        echo "No directories found at $URL"

        TYPE=""
        URL=""
        REGEX=""
        SUFFIX=""
        continue
      fi

      # Select the latest directory
      TYPE="from-directory"
      URL=$(echo "$DIRECTORIES" | sort -r | head -n 1)

      if [[ -z "$URL" ]]; then
        echo "Failed to select the latest directory from $URL"

        TYPE=""
        URL=""
        REGEX=""
        SUFFIX=""
        continue
      fi
    fi

    # Select lastest file from URL
    if [[ "$TYPE" == "select-latest-file" ]]; then
      echo "Processing latest file: $URL"

      # Fetch the list of files from the URL
      LINKS="$(lynx -dump -listonly -hiddenlinks=listonly $URL?r=$random_chars | awk '{print $2}' | uniq)"

      if [[ -z "$LINKS" ]]; then
        echo "Failed to fetch content from $URL"

        TYPE=""
        URL=""
        REGEX=""
        SUFFIX=""
        continue
      fi

      MATCHING_LINKS=$(echo "$LINKS")
      if [[ -n "$REGEX" ]]; then
        MATCHING_LINKS=$(echo "$LINKS" | grep -P "$REGEX")
      fi

      if [[ -z "$MATCHING_LINKS" ]]; then
        echo "No matching files found at $URL"

        TYPE=""
        URL=""
        REGEX=""
        SUFFIX=""
        continue
      fi

      # Select the latest file
      TYPE="file"
      URL=$(echo "$MATCHING_LINKS" | sort -r | head -n 1)

      if [[ -z "$URL" ]]; then
        echo "Failed to select the latest file from $URL"

        TYPE=""
        URL=""
        REGEX=""
        SUFFIX=""
        continue
      fi
    fi

    if [[ "$TYPE" == "from-directory" ]]; then
      echo "Processing directory: $URL"

      # Fetch the list of files from the URL
      LINKS="$(lynx -dump -listonly -hiddenlinks=listonly $URL?r=$random_chars | awk '{print $2}' | uniq)"

      if [[ -z "$LINKS" ]]; then
        echo "Failed to fetch content from $URL"

        TYPE=""
        URL=""
        REGEX=""
        SUFFIX=""
        continue
      fi

      # Extract matching links
      MATCHING_LINKS=$(echo "$LINKS")
      if [[ -n "$REGEX" ]]; then
        MATCHING_LINKS=$(echo "$LINKS" | grep -P "$REGEX")
      fi

      if [[ -z "$MATCHING_LINKS" ]]; then
        echo "No matching files found at $URL"

        TYPE=""
        URL=""
        REGEX=""
        SUFFIX=""
        continue
      fi

      # Download each matching file
      for LINK in $MATCHING_LINKS; do
        if [[ $LINK != http* ]]; then
          LINK="$URL/$LINK"
        fi

        FILENAME=$(basename "$LINK$SUFFIX")
        curl -s -o "$DOWNLOAD_DIR/$FILENAME" "$LINK$SUFFIX"

        if [[ $? -eq 0 ]]; then
          echo "$FILENAME downloaded successfully"
        else
          echo "Failed to download $FILENAME"
        fi
      done

    elif [[ "$TYPE" == "file" ]]; then
      echo "Downloading file: $URL$SUFFIX"

      FILENAME=$(basename "$URL$SUFFIX")
      curl -s -o "$DOWNLOAD_DIR/$FILENAME" "$URL$SUFFIX"

      if [[ $? -eq 0 ]]; then
        echo "$FILENAME downloaded successfully"
      else
        echo "Failed to download $FILENAME"
      fi

    fi

    # Reset TYPE, URL, and REGEX for the next block
    TYPE=""
    URL=""
    REGEX=""
    SUFFIX=""

    process=0

    echo ""
  fi

done <"$INPUT_FILE"

chmod -R 777 ./watched
chown -R qbittorrent:qbittorrent ./watched

echo "All specified files and directories have been processed. Downloaded files are in $DOWNLOAD_DIR"
