#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <YouTube Playlist ID>"
    exit 1
fi

PLAYLIST_ID=$1
OUTPUT_FILE="/home/db/Music/youtube-music/music.m3u"

echo "#EXTM3U" > $OUTPUT_FILE
youtube-dl -j --flat-playlist "https://www.youtube.com/playlist?list=$PLAYLIST_ID" | jq -r '.id' | sed 's_^_https://www.youtube.com/watch?v=_' >> $OUTPUT_FILE

echo "Playlist saved to $OUTPUT_FILE"

