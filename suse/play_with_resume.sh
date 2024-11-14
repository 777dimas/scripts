#!/bin/bash

PLAYLIST_FILE=$1

mpv --no-video --save-position-on-quit -audio-device=alsa/default --playlist=${PLAYLIST_FILE}

