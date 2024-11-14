#!/bin/bash

PLAYLIST=/home/db/Music/youtube-music/music.m3u

STATE_FILE=/home/db/Music/youtube-music/mpv_state.json

save_state() {
    echo "Saving state..."
    echo -e '{ "file": "'"$CURRENT_FILE"'", "time_pos": '"$TIME_POS"' }' > $STATE_FILE
}

load_state() {
    if [[ -f $STATE_FILE ]]; then
        STATE=$(cat $STATE_FILE)
        CURRENT_FILE=$(echo $STATE | jq -r '.file')
        TIME_POS=$(echo $STATE | jq -r '.time_pos')
        echo "Resuming $CURRENT_FILE from $TIME_POS seconds"
        mpv --no-video --start=$TIME_POS "$CURRENT_FILE"
    else
        echo "No state file found. Starting from the beginning."
        mpv --playlist=$PLAYLIST
    fi
}

trap save_state SIGINT SIGTERM

load_state



