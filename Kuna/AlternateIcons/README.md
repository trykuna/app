# Alternate App Icons Setup

## Problem Fixed
The alternate app icons were showing as the "blueprint" default icon because iOS requires alternate icons to be in the app bundle root, not in Assets.xcassets.

**Update**: Pride, Red, Silver, and Yellow icons were recreated from the correct source files as they used different naming conventions (e.g., `KunaLogoPride.png` instead of `KunaLogoPrideLight.png`).

## What Was Done
1. Created properly sized icon files from the existing assets:
   - `@2x` icons: 120x120 pixels (60pt @ 2x)
   - `@3x` icons: 180x180 pixels (60pt @ 3x)

2. Placed them in the `AlternateIcons` folder with correct naming convention:
   - `AppIcon-Gold@2x.png` and `AppIcon-Gold@3x.png`
   - `AppIcon-Orange@2x.png` and `AppIcon-Orange@3x.png`
   - etc.

## Required Xcode Setup

### Step 1: Add Icons to Project
1. Open `Kuna.xcodeproj` in Xcode
2. Right-click on the `Kuna` folder in the project navigator
3. Select "Add Files to 'Kuna'..."
4. Navigate to the `AlternateIcons` folder
5. Select all the `.png` files (not the .sh scripts)
6. Make sure these options are checked:
   - ✅ Copy items if needed (if not already in project)
   - ✅ Add to targets: Kuna
7. Click "Add"

### Step 2: Verify Build Phase
1. Select the Kuna project in the navigator
2. Select the Kuna target
3. Go to "Build Phases" tab
4. Expand "Copy Bundle Resources"
5. Verify all the alternate icon PNG files are listed there
6. If not, click the "+" button and add them

### Step 3: Clean and Build
1. Product → Clean Build Folder (⌘⇧K)
2. Product → Build (⌘B)

## Testing
1. Run the app on a device or simulator
2. Go to Settings → App Icon
3. Select any alternate icon
4. The icon should change properly without showing the blueprint icon

## How It Works
- iOS looks for alternate icons in the app bundle based on the names in Info.plist
- The Info.plist specifies `AppIcon-Gold`, `AppIcon-Orange`, etc.
- iOS automatically appends `@2x` and `@3x` based on the device's screen scale
- The actual files must be in the bundle root (not in Assets.xcassets)

## Troubleshooting
If icons still don't work:
1. Check that files are in "Copy Bundle Resources" build phase
2. Verify Info.plist has correct `CFBundleAlternateIcons` entries
3. Ensure icon file names match exactly (case-sensitive)
4. Try deleting the app and reinstalling