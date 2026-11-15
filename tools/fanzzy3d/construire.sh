#!/bin/sh
# construire.sh ID... : prépare, construit et rend chaque skin (images de contrôle)
# Variables : PY (python avec mediapipe), POSE (pose.task), IMG (dossier des PNG), BLENDER
ICI=$(dirname "$0")
for i in "$@"; do L="$L $IMG/$i.png"; done
"$PY" "$ICI/preparer.py" "$POSE" "$ICI/../prep" $L 2>&1 | grep " ok\|aucun\|Error"
for i in "$@"; do
  "$BLENDER" -b -P "$ICI/fanzzy3d.py" -- "$ICI/../prep" $i "$ICI/../modeles" 2>&1 | grep "FINI\|Error"
  "$BLENDER" -b "$ICI/../modeles/$i.blend" -P "$ICI/rendu.py" -- "$ICI/../rendus" images 2>&1 | grep -i "Traceback"
done
