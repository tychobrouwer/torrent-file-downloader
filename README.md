# Torrent Downloader Script

This Bash script automates downloading ```.torrent``` files from directories or specific URLs listed in an input file.

## Features

Downloads ```.torrent``` files from directory URLs.

Filters files in directories using optional regular expressions.

Downloads individual files directly.

Organizes downloads in the ```downloaded_torrents``` folder.

## Prerequisites

```curl``` must be installed.

## Usage

1. Create an ```input.txt``` file with entries in the following format:

    ```txt
    TYPE=directory
    URL=<https://example.com/path/to/torrents>
    REGEX=.*debian.*\.torrent$

    TYPE=file
    URL=<https://example.com/path/to/file.torrent>
    ```

    + TYPE: directory or file.
    + URL: Resource URL.
    + REGEX: Optional for filtering; defaults to .*\.torrent$.

2. Run the script:

    ```bash
    ./torrent_downloader.sh
    ```

3. Downloads are saved in ```downloaded_torrents/```.

## Notes

Missing input file or invalid entries are logged as errors.

Default behavior matches .torrent files.

Use this script to quickly and efficiently download ```.torrent``` files from specified sources.
