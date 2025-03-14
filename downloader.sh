#!/bin/bash

# Read input file
INPUT_FILE="input.txt"

if [[ ! -f $INPUT_FILE ]]; then
  echo "Input file '$INPUT_FILE' not found! Please create it with the following format:"
  echo -e "TYPE=select-latest-directory|select-latest-file|from-directory|file\nURL=https://example.com/path/to/resource\nREGEX=optional_regex\n\nRepeat the above lines for multiple entries"
  exit 1
fi

# Create a directory to store downloaded .torrent files
DOWNLOAD_DIR="watched"
mkdir -p "$DOWNLOAD_DIR"

# Function to process a block
process_block() {
  local TYPE="$1"
  local URL="$2"
  local REGEX="$3"
  local SUFFIX="$4"
  
  if [[ -n "$TYPE" && -n "$URL" ]]; then
    random_chars=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 8)

    if [[ "$TYPE" == "select-latest-directory" ]]; then
      echo "Getting latest directory: $URL"

      LINKS=$(lynx -dump -listonly -hiddenlinks=listonly "$URL?r=$random_chars" | awk '{print $2}' | uniq)
      DIRECTORIES=$(echo "$LINKS" | grep -E "/$")
      URL=$(echo "$DIRECTORIES" | sort -r | head -n 1)
      TYPE="from-directory"
    fi

    if [[ "$TYPE" == "select-latest-file" ]]; then
      echo "Getting latest file: $URL"

      LINKS=$(lynx -dump -listonly -hiddenlinks=listonly "$URL?r=$random_chars" | awk '{print $2}' | uniq)
      MATCHING_LINKS=$(echo "$LINKS" | grep -P "$REGEX")
      URL=$(echo "$MATCHING_LINKS" | sort -r | head -n 1)
      TYPE="file"
    fi

    if [[ "$TYPE" == "from-directory" ]]; then
      echo "Processing directory: $URL"

      LINKS=$(lynx -dump -listonly -hiddenlinks=listonly "$URL?r=$random_chars" | awk '{print $2}' | uniq)
      MATCHING_LINKS=$(echo "$LINKS" | grep -P "$REGEX")

      for LINK in $MATCHING_LINKS; do
        [[ $LINK != http* ]] && LINK="$URL/$LINK"
        FILENAME=$(basename "$LINK$SUFFIX")
        curl -s -o "$DOWNLOAD_DIR/$FILENAME" "$LINK$SUFFIX" && echo "$FILENAME downloaded successfully" || echo "Failed to download $FILENAME"
      done

    elif [[ "$TYPE" == "file" ]]; then

      echo "Downloading file: $URL$SUFFIX"
      FILENAME=$(basename "$URL$SUFFIX")
      curl -s -o "$DOWNLOAD_DIR/$FILENAME" "$URL$SUFFIX" && echo "$FILENAME downloaded successfully" || echo "Failed to download $FILENAME"
    fi
  fi

  echo ""
}

while IFS= read -r line || [[ -n "$line" ]]; do
  line=$(echo $line | tr -d '\r')

  # Parse TYPE, URL, and REGEX
  if [[ "$line" =~ ^TYPE=(.+)$ ]]; then
    TYPE="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^URL=(.+)$ ]]; then
    URL="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^REGEX=(.+)$ ]]; then
    REGEX="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^SUFFIX=(.+)$ ]]; then
    SUFFIX="${BASH_REMATCH[1]}"
  fi

  if [[ "$line" == "" ]]; then
    process_block "$TYPE" "$URL" "$REGEX" "$SUFFIX"
  fi
done <"$INPUT_FILE"

# Process the last block if not already processed
process_block "$TYPE" "$URL" "$REGEX" "$SUFFIX"

chmod -R 777 ./watched
chown -R qbittorrent:qbittorrent ./watched

echo "All specified files and directories have been processed. Downloaded files are in $DOWNLOAD_DIR"
