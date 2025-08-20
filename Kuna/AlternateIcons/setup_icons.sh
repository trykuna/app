#!/bin/bash

# Create AlternateIcons directory if it doesn't exist
mkdir -p "/Users/richard/Documents/[02] Projects/[01] iOS Apps/Kuna/Kuna/AlternateIcons"

# Copy icon files from Assets.xcassets to AlternateIcons folder
# These need to be 60x60@2x (120x120) and 60x60@3x (180x180) for iPhone

echo "Setting up alternate app icons..."

# For each alternate icon, we need to create properly sized versions
# iOS expects these specific sizes for alternate icons:
# - 60x60@2x (120x120 pixels) for iPhone
# - 60x60@3x (180x180 pixels) for iPhone Plus/Pro Max

ICONS=(
    "Gold"
    "Orange" 
    "Red"
    "Yellow"
    "Neon"
    "Silver"
    "Pride"
    "AltPride"
    "TransPride"
)

for icon in "${ICONS[@]}"; do
    echo "Processing $icon icon..."
    
    # Source files are in the appiconset folders
    SOURCE_DIR="/Users/richard/Documents/[02] Projects/[01] iOS Apps/Kuna/Kuna/Assets.xcassets/AppIcon-${icon}.appiconset"
    
    # Find the light mode icon (main icon file)
    if [ -f "${SOURCE_DIR}/KunaLogo${icon}Light.png" ]; then
        SOURCE_FILE="${SOURCE_DIR}/KunaLogo${icon}Light.png"
    elif [ -f "${SOURCE_DIR}/KunaLogo${icon}.png" ]; then
        SOURCE_FILE="${SOURCE_DIR}/KunaLogo${icon}.png"
    else
        echo "Warning: Could not find source file for ${icon}"
        continue
    fi
    
    # Check if source file exists
    if [ -f "$SOURCE_FILE" ]; then
        echo "Found source: $SOURCE_FILE"
        
        # Copy and rename for iOS bundle
        # iOS looks for files named exactly as specified in Info.plist
        cp "$SOURCE_FILE" "/Users/richard/Documents/[02] Projects/[01] iOS Apps/Kuna/Kuna/AlternateIcons/AppIcon-${icon}@2x.png"
        cp "$SOURCE_FILE" "/Users/richard/Documents/[02] Projects/[01] iOS Apps/Kuna/Kuna/AlternateIcons/AppIcon-${icon}@3x.png"
        
        echo "Created AppIcon-${icon}@2x.png and AppIcon-${icon}@3x.png"
    fi
done

echo "Icon setup complete!"
echo ""
echo "Next steps:"
echo "1. Add the AlternateIcons folder to your Xcode project"
echo "2. Make sure all .png files are added to 'Copy Bundle Resources' build phase"
echo "3. The Info.plist already references these icons correctly"