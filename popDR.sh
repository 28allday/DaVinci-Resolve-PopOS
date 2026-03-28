#!/bin/bash
# ==============================================================================
# DaVinci Resolve Installer for Pop!_OS 24.04
#
# DaVinci Resolve is a professional video editing suite by Blackmagic Design.
# This script automates the installation on Pop!_OS 24.04, handling:
#   - FUSE library installation (needed for the AppImage-style installer)
#   - Qt5 library installation (Resolve's UI depends on Qt5)
#   - ZIP extraction and installer execution
#   - Fallback AppImage extraction if FUSE isn't working
#   - Library conflict resolution (bundled glib/gio vs system versions)
#
# Pop!_OS is Ubuntu-based, so this script uses apt for package management.
# Pop!_OS ships with NVIDIA drivers pre-configured on the NVIDIA ISO,
# making it one of the easier distros for Resolve.
#
# Prerequisites:
#   - Pop!_OS 24.04
#   - DaVinci Resolve Linux ZIP downloaded to ~/Downloads/
#     (download from https://www.blackmagicdesign.com/products/davinciresolve)
#   - Internet connection (for installing packages)
#
# Usage:
#   chmod +x popDR.sh
#   ./popDR.sh
# ==============================================================================

set -eo pipefail  # Exit on error; catch pipe failures

# Resolve the real user even when running with sudo. logname returns the
# user who originally logged in, not "root". getent passwd safely looks up
# the home directory without eval (which has injection risks).
ACTIVE_USER=$(logname)
HOME_DIR=$(getent passwd "$ACTIVE_USER" | cut -d: -f6)
DOWNLOADS_DIR="$HOME_DIR/Downloads"
EXTRACTION_DIR="/opt/resolve"
ZIP_FILE_PATTERN="DaVinci_Resolve_*.zip"

# ==================== Step 1: FUSE Libraries ====================
#
# The Resolve .run installer is an AppImage-style archive that uses FUSE
# to mount itself. Pop!_OS doesn't always have FUSE installed by default.
#   - fuse:     FUSE kernel module and mount tools
#   - libfuse2: Userspace library (libfuse.so.2) for AppImage support
#
# If FUSE doesn't work, the script falls back to --appimage-extract later.
echo "Checking for FUSE and libfuse.so.2..."
if ! dpkg -s fuse libfuse2 >/dev/null 2>&1; then
    echo "Installing FUSE..."
    sudo apt update
    sudo apt install -y fuse libfuse2
fi

if [ ! -f /lib/x86_64-linux-gnu/libfuse.so.2 ]; then
    echo "Error: libfuse.so.2 is not found. Installing libfuse2..."
    sudo apt install -y libfuse2
fi

# ==================== Step 2: Qt5 Libraries ====================
#
# DaVinci Resolve's UI is built with Qt5. Pop!_OS uses GTK (COSMIC/GNOME)
# so Qt5 libraries may not be present. These packages provide the core
# Qt5 framework, X11 rendering extensions, and Wayland support.
echo "Installing required Qt libraries..."
sudo apt install -y qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools libqt5core5a libqt5gui5 libqt5widgets5 libqt5network5 libqt5dbus5 \
libxrender1 libxrandr2 libxi6 libxkbcommon-x11-0 libxcb-xinerama0 libxcb-xfixes0 qtwayland5 libxcb-glx0 libxcb-util1

# ==================== Step 3: Find the ZIP ====================
#
# The user must download the Resolve ZIP manually from Blackmagic's website
# (registration form required). We look for it in ~/Downloads/.
echo "Navigating to Downloads directory..."
if [ ! -d "$DOWNLOADS_DIR" ]; then
    echo "Error: Downloads directory not found at $DOWNLOADS_DIR."
    exit 1
fi
cd "$DOWNLOADS_DIR"

# ==================== Step 4: Extract ZIP ====================
#
# The download is a ZIP containing a .run file (self-extracting installer).
# We extract it to a temporary DaVinci_Resolve/ directory.
echo "Extracting DaVinci Resolve installer..."
ZIP_FILE=$(find . -maxdepth 1 -type f -name "$ZIP_FILE_PATTERN" | head -n 1)
if [ -z "$ZIP_FILE" ]; then
    echo "Error: DaVinci Resolve ZIP file not found in $DOWNLOADS_DIR."
    exit 1
fi

unzip -o "$ZIP_FILE" -d DaVinci_Resolve/
chown -R "$ACTIVE_USER:$ACTIVE_USER" DaVinci_Resolve
chmod -R u+rwX,go+rX DaVinci_Resolve

# ==================== Step 5: Run Installer ====================
#
# The .run file is an AppImage-style self-extracting archive. We try:
#   1. Run it with FUSE (SKIP_PACKAGE_CHECK=1 bypasses distro check)
#   2. Fall back to --appimage-extract if FUSE fails
#
# Qt environment variables tell the installer where to find platform plugins.
echo "Running the DaVinci Resolve installer..."
cd DaVinci_Resolve
INSTALLER_FILE=$(find . -type f -name "DaVinci_Resolve_*.run" | head -n 1)
if [ -z "$INSTALLER_FILE" ]; then
    echo "Error: DaVinci Resolve installer (.run) file not found in extracted directory."
    exit 1
fi

chmod +x "$INSTALLER_FILE"

# Tell Qt where to find platform plugins so the installer GUI can render.
export QT_DEBUG_PLUGINS=1
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins/platforms
export QT_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

# Try FUSE-based install first, fall back to manual extraction
if ! SKIP_PACKAGE_CHECK=1 ./"$INSTALLER_FILE" -a; then
    echo "FUSE is not functional. Extracting AppImage contents..."
    ./"$INSTALLER_FILE" --appimage-extract || { echo "Error: AppImage extraction failed"; exit 1; }
    if [ ! -d "squashfs-root" ] || [ -z "$(ls -A squashfs-root)" ]; then
        echo "Error: Extraction produced empty directory"; exit 1
    fi
    sudo mkdir -p "$EXTRACTION_DIR"
    sudo cp -a squashfs-root/. "$EXTRACTION_DIR/"
    sudo chown -R root:root "$EXTRACTION_DIR"
    rm -rf squashfs-root
fi

# ==================== Step 6: Library Conflict Resolution ====================
#
# Resolve bundles old versions of glib/gio libraries that conflict with
# Pop!_OS's newer system versions. Moving them aside and using the system's
# glib fixes crashes and "symbol not found" errors. This is safe because
# glib has a very stable C ABI — newer versions are backwards-compatible.
echo "Resolving library conflicts..."
if [ -d "$EXTRACTION_DIR/libs" ]; then
    cd "$EXTRACTION_DIR/libs"
    sudo mkdir -p not_used
    sudo mv libgio* not_used || true
    sudo mv libgmodule* not_used || true

    if [ -f /usr/lib/x86_64-linux-gnu/libglib-2.0.so.0 ]; then
        sudo cp /usr/lib/x86_64-linux-gnu/libglib-2.0.so.0 "$EXTRACTION_DIR/libs/"
    else
        echo "Warning: System library libglib-2.0.so.0 not found. Ensure compatibility manually."
    fi
else
    echo "Error: Installation directory $EXTRACTION_DIR/libs not found. Skipping library conflict resolution."
fi

# ==================== Step 7: Cleanup ====================
#
# Remove the temporary extraction directory from ~/Downloads/.
# The installed application stays at /opt/resolve.
echo "Cleaning up installation files..."
cd "$DOWNLOADS_DIR"
rm -rf DaVinci_Resolve

echo "DaVinci Resolve installation completed successfully!"