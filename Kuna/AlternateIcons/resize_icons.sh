#!/bin/bash

# This script uses sips (built into macOS) to resize icons to the correct dimensions
# iOS expects these sizes for alternate app icons:
# @2x: 120x120 pixels (60pt @ 2x)
# @3x: 180x180 pixels (60pt @ 3x)

echo "Resizing alternate app icons to correct dimensions..."

# Process all @2x icons (resize to 120x120)
for icon in *@2x.png; do
    if [ -f "$icon" ]; then
        echo "Resizing $icon to 120x120..."
        sips -z 120 120 "$icon" --out "$icon" > /dev/null 2>&1
    fi
done

# Process all @3x icons (resize to 180x180)
for icon in *@3x.png; do
    if [ -f "$icon" ]; then
        echo "Resizing $icon to 180x180..."
        sips -z 180 180 "$icon" --out "$icon" > /dev/null 2>&1
    fi
done

echo "Resize complete!"
echo ""
echo "Icon sizes:"
ls -la *.png | grep -E "@[23]x\.png" | while read line; do
    filename=$(echo "$line" | awk '{print $NF}')
    dimensions=$(sips -g pixelHeight -g pixelWidth "$filename" 2>/dev/null | tail -2 | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
    echo "$filename: $dimensions"
done