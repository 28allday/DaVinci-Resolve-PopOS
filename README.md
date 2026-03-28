# DaVinci Resolve - Pop!_OS

Install [DaVinci Resolve](https://www.blackmagicdesign.com/products/davinciresolve) on Pop!_OS 24.04 with automatic dependency installation and library conflict resolution.

## Requirements

- **OS**: Pop!_OS 24.04
- **DaVinci Resolve ZIP**: Downloaded from [blackmagicdesign.com](https://www.blackmagicdesign.com/products/davinciresolve) to `~/Downloads/`

## Quick Start

1. **Download DaVinci Resolve** from [blackmagicdesign.com](https://www.blackmagicdesign.com/products/davinciresolve)
   - Choose **Linux** and download the ZIP file
   - Save to `~/Downloads/`

2. **Run the installer**:
```bash
git clone https://github.com/28allday/DaVinci-Resolve-PopOS.git
cd DaVinci-Resolve-PopOS
chmod +x popDR.sh
./popDR.sh
```

## What It Does

### 1. Installs FUSE Libraries

The Resolve installer needs FUSE to mount itself. If FUSE isn't available, the script falls back to manual extraction.

| Package | Purpose |
|---------|---------|
| `fuse` | FUSE kernel module and mount tools |
| `libfuse2` | Userspace library for AppImage support |

### 2. Installs Qt5 Libraries

Resolve's UI is built with Qt5. Pop!_OS uses GTK (COSMIC/GNOME) so Qt5 may not be present.

| Package | Purpose |
|---------|---------|
| `qtbase5-dev` + tools | Qt5 core framework |
| `libqt5core5a`, `libqt5gui5`, `libqt5widgets5` | Qt5 runtime |
| `libxrender1`, `libxrandr2`, `libxi6` | X11 extensions |
| `qtwayland5` | Wayland support |

### 3. Extracts and Installs Resolve

- Finds the ZIP in `~/Downloads/`
- Tries running the installer with FUSE
- Falls back to `--appimage-extract` if FUSE doesn't work
- Installs to `/opt/resolve`

### 4. Resolves Library Conflicts

| Library | Action | Why |
|---------|--------|-----|
| `libgio-2.0.so` | Moved to `not_used/` | Bundled version conflicts with system |
| `libgmodule-2.0.so` | Moved to `not_used/` | Bundled version conflicts with system |
| `libglib-2.0.so.0` | Replaced with system copy | Stable C ABI, safe to swap |

### 5. Cleans Up

Removes temporary extraction files. The application stays at `/opt/resolve`.

## Pop!_OS Advantages

Pop!_OS is one of the easier distros for Resolve because:
- The **NVIDIA ISO** comes with proprietary drivers pre-configured
- Ubuntu-based, so most Resolve dependencies are readily available
- System76's hardware support means GPU drivers are well-tested

## Troubleshooting

### Resolve won't start

- Launch from terminal: `/opt/resolve/bin/resolve`
- Check GPU drivers: `nvidia-smi` (NVIDIA) or `glxinfo | grep renderer` (AMD)

### Qt plugin errors

```bash
export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/x86_64-linux-gnu/qt5/plugins/platforms
/opt/resolve/bin/resolve
```

### FUSE errors during installation

The script handles this automatically with `--appimage-extract` fallback. No action needed.

## Updating Resolve

Download the new ZIP and run the script again:
```bash
./popDR.sh
```

## Uninstalling

```bash
sudo rm -rf /opt/resolve
sudo rm -f /usr/share/applications/DaVinciResolve.desktop
rm -f ~/.local/share/applications/DaVinciResolve.desktop
rm -rf ~/.local/share/DaVinciResolve
```

## Credits

- [System76](https://system76.com/) - Pop!_OS
- [Blackmagic Design](https://www.blackmagicdesign.com/) - DaVinci Resolve

## License

This project is provided as-is.
