#!/bin/sh

youtube-dl --extract-audio --audio-quality 0 --audio-format mp3 $*
