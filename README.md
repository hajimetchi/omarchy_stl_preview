# STL Preview for Files

STL Preview adds shaded, transparent-background thumbnails for `.stl` models in GNOME Files (Nautilus), the file manager used by Omarchy. Made for Omarchy, it was tested on Omarchy 4.0.4-1 (stable).

The renderer uses Python's standard library only. It does not need pip packages, a 3D application, or an internet connection. It supports both binary and ASCII STL files. The thumbnails are for browsing and are not a substitute for a 3D viewer when checking a model's shape or dimensions.

## Screenshot

<!-- Add a screenshot of GNOME Files showing STL model thumbnails here. -->

_Screenshot coming soon._

## Install

1. Download this project: select **Code → Download ZIP** on GitHub and extract the ZIP, or clone the repository:

   ```bash
   git clone https://github.com/hajimetchi/omarchy_stl_preview.git
   cd omarchy_stl_preview
   ```

2. Open a terminal in the extracted project folder and run:

   ```bash
   ./install.sh
   ```

3. Enter your administrator password when prompted. The installer puts the thumbnail renderer in `/usr/local/bin` so GNOME's thumbnail sandbox can run it. The thumbnailer and STL file-type registration are installed in your user data folder; no administrator access is needed for those files.

4. Restart GNOME Files (close and reopen it, or log out and back in). Browse to a folder containing `.stl` files and use an icon or grid view. If thumbnails are disabled in Files, enable them in Files preferences.

The installer clears failed-thumbnail cache entries so Files can retry generating previews. The first preview may take a moment to appear.

## Uninstall

In a terminal opened in the project folder, run:

```bash
./uninstall.sh
```

Enter your administrator password when prompted, then restart GNOME Files. The uninstaller removes this thumbnail integration and its Nautilus-only transparent-thumbnail style. Other GTK style rules are preserved.

## Project files

| File | Purpose |
| --- | --- |
| `install.sh` | Installs the renderer, registers the thumbnailer and STL file type for your account, and adds the Nautilus thumbnail style. |
| `uninstall.sh` | Removes the renderer and registrations, then removes only the style block added by this project. |
| `bin/stl-thumbnailer` | Python program that reads an STL mesh and renders a transparent PNG thumbnail. |
| `share/thumbnailers/stl-preview.thumbnailer` | Tells GNOME which command to run to make thumbnails for STL files. |
| `share/mime/packages/stl-preview.xml` | Registers `.stl` files as STL models with the desktop file-type system. |
| `README.md` | Installation, removal, and project documentation. |

## How it works

GNOME Files uses the standard desktop thumbnailer system to request a PNG preview for an STL file. This project reads the mesh, projects its triangles into a shaded isometric-style view, and writes the thumbnail with a transparent background. It does not change the STL file itself.
