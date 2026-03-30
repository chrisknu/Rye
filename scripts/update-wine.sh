#!/bin/bash
set -euo pipefail

# Rye Wine Update Script
# Downloads the latest Wine-crossover and DXVK builds from Gcenx,
# packages them into Libraries.tar.gz, and creates a GitHub release.
#
# Usage: ./scripts/update-wine.sh
#
# Prerequisites: curl, tar, xz, gh (GitHub CLI), jq

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="chrisknu/Rye"
WORK_DIR=$(mktemp -d)
LIBRARIES_DIR="$WORK_DIR/Libraries"

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "==> Checking latest versions..."

# Get latest Wine-crossover version from Gcenx's homebrew tap
WINE_VERSION=$(curl -sL "https://raw.githubusercontent.com/Gcenx/homebrew-wine/master/Casks/wine-crossover.rb" \
    | grep 'version "' | head -1 | sed 's/.*version "\(.*\)"/\1/')
WINE_URL="https://github.com/Gcenx/winecx/releases/download/crossover-wine-${WINE_VERSION}/wine-crossover-${WINE_VERSION}-osx64.tar.xz"

# Get latest DXVK-macOS version
DXVK_TAG=$(gh release view --repo Gcenx/DXVK-macOS --json tagName --jq '.tagName')
DXVK_URL="https://github.com/Gcenx/DXVK-macOS/releases/download/${DXVK_TAG}/dxvk-macOS-async-${DXVK_TAG}.tar.gz"

# Get latest winetricks
WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"

echo "    Wine:       ${WINE_VERSION}"
echo "    DXVK:       ${DXVK_TAG}"
echo "    Winetricks:  latest master"

# Check what we currently have
CURRENT_TAG=$(grep 'releases/download/' "$SCRIPT_DIR/../WhiskyKit/Sources/WhiskyKit/WhiskyConfig.swift" \
    | sed 's|.*download/\(.*\)/Libraries.*|\1|')
echo "    Current:     ${CURRENT_TAG}"
echo ""

read -p "Proceed with update? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

mkdir -p "$LIBRARIES_DIR/Wine" "$LIBRARIES_DIR/DXVK"

# Download and extract Wine
echo "==> Downloading Wine-crossover ${WINE_VERSION}..."
curl -L "$WINE_URL" -o "$WORK_DIR/wine.tar.xz"
echo "==> Extracting Wine..."
tar xJf "$WORK_DIR/wine.tar.xz" -C "$WORK_DIR"
# Move wine binaries from the .app bundle into Libraries/Wine/
cp -R "$WORK_DIR/Wine Crossover.app/Contents/Resources/wine/bin" "$LIBRARIES_DIR/Wine/"
cp -R "$WORK_DIR/Wine Crossover.app/Contents/Resources/wine/lib" "$LIBRARIES_DIR/Wine/"
cp -R "$WORK_DIR/Wine Crossover.app/Contents/Resources/wine/share" "$LIBRARIES_DIR/Wine/"

# Download and extract DXVK
echo "==> Downloading DXVK ${DXVK_TAG}..."
curl -L "$DXVK_URL" -o "$WORK_DIR/dxvk.tar.gz"
echo "==> Extracting DXVK..."
tar xzf "$WORK_DIR/dxvk.tar.gz" -C "$WORK_DIR"
# DXVK extracts to a versioned directory — find it and move x32/x64
DXVK_DIR=$(find "$WORK_DIR" -maxdepth 1 -type d -name "dxvk-*" | head -1)
if [ -d "$DXVK_DIR/x32" ]; then
    cp -R "$DXVK_DIR/x32" "$LIBRARIES_DIR/DXVK/"
fi
if [ -d "$DXVK_DIR/x64" ]; then
    cp -R "$DXVK_DIR/x64" "$LIBRARIES_DIR/DXVK/"
fi

# Download winetricks
echo "==> Downloading winetricks..."
curl -sL "$WINETRICKS_URL" -o "$LIBRARIES_DIR/winetricks"
chmod +x "$LIBRARIES_DIR/winetricks"
# verbs.txt is embedded in winetricks now, create empty placeholder
touch "$LIBRARIES_DIR/verbs.txt"

# Parse Wine version for the plist (extract major.minor.patch from crossover version)
WINE_MAJOR=$(echo "$WINE_VERSION" | cut -d. -f1)
WINE_MINOR=$(echo "$WINE_VERSION" | cut -d. -f2)
WINE_PATCH=$(echo "$WINE_VERSION" | cut -d. -f3 | cut -d- -f1)

# Create WhiskyWineVersion.plist
cat > "$LIBRARIES_DIR/WhiskyWineVersion.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>version</key>
	<dict>
		<key>build</key>
		<string>0</string>
		<key>major</key>
		<integer>${WINE_MAJOR}</integer>
		<key>minor</key>
		<integer>${WINE_MINOR}</integer>
		<key>patch</key>
		<integer>${WINE_PATCH}</integer>
		<key>preRelease</key>
		<string></string>
	</dict>
</dict>
</plist>
PLIST

# Package
RELEASE_TAG="v${WINE_MAJOR}.${WINE_MINOR}.${WINE_PATCH}-wine"
OUTPUT="$WORK_DIR/Libraries.tar.gz"
echo "==> Packaging Libraries.tar.gz..."
tar czf "$OUTPUT" -C "$WORK_DIR" Libraries

SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "==> Package size: ${SIZE}"
echo ""

# Create GitHub release
echo "==> Creating GitHub release ${RELEASE_TAG}..."
gh release create "$RELEASE_TAG" \
    --repo "$REPO" \
    --title "Wine Libraries ${WINE_MAJOR}.${WINE_MINOR}.${WINE_PATCH}" \
    --notes "$(cat <<NOTES
Wine-crossover ${WINE_VERSION} + DXVK ${DXVK_TAG}

Sources:
- Wine: https://github.com/Gcenx/winecx/releases/tag/crossover-wine-${WINE_VERSION}
- DXVK: https://github.com/Gcenx/DXVK-macOS/releases/tag/${DXVK_TAG}
- Winetricks: latest master
NOTES
)" \
    "$OUTPUT" \
    "$LIBRARIES_DIR/WhiskyWineVersion.plist"

echo ""
echo "==> Release created: https://github.com/${REPO}/releases/tag/${RELEASE_TAG}"
echo ""
echo "==> Now update WhiskyConfig.swift:"
echo ""
echo "    private static let baseURL = \"https://github.com/${REPO}/releases/download/${RELEASE_TAG}\""
echo ""
echo "Done!"
