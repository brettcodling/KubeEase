#!/bin/bash

# Generate PNG icon from SVG

set -e

echo "Generating PNG icon from SVG..."

# Check for available tools
if command -v inkscape &> /dev/null; then
    echo "Using Inkscape..."
    inkscape assets/icon.svg -o assets/icon.png -w 512 -h 512
elif command -v rsvg-convert &> /dev/null; then
    echo "Using rsvg-convert..."
    rsvg-convert -w 512 -h 512 assets/icon.svg -o assets/icon.png
elif command -v convert &> /dev/null; then
    echo "Using ImageMagick..."
    convert -background none -size 512x512 assets/icon.svg assets/icon.png
else
    echo "No SVG converter found. Installing librsvg2-bin..."
    sudo apt-get update
    sudo apt-get install -y librsvg2-bin
    rsvg-convert -w 512 -h 512 assets/icon.svg -o assets/icon.png
fi

echo "✓ Icon generated: assets/icon.png"

