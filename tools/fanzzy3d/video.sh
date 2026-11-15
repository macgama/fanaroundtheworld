#!/bin/sh
# video.sh ID... : vidéo des 5 animations pour chaque ID, puis côte à côte (famille.mp4)
ICI=$(dirname "$0"); R="$ICI/../rendus"
for i in "$@"; do
  rm -rf "$R/video-$i"
  "$BLENDER" -b "$ICI/../modeles/$i.blend" -P "$ICI/rendu.py" -- "$R/video-$i" video 2>&1 | grep "IMAGES\|Traceback"
  ffmpeg -hide_banner -loglevel error -y -framerate 24 -i "$R/video-$i/_images/%05d.png" -vf scale=400:450 -c:v libopenh264 -b:v 3M "$R/$i.mp4"
  E="$E -i $R/$i.mp4"; N=$((N+1))
done
ffmpeg -hide_banner -loglevel error -y $E -filter_complex hstack=$N -c:v libopenh264 -b:v 6M "$R/famille.mp4"
