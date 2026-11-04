#!/bin/sh
# Build the place file.
cd "$(dirname "$0")/.."
~/.rokit/bin/rojo build default.project.json -o build/GlitchRNG.rbxlx
