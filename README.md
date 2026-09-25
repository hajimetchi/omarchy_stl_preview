# STL Preview for Omarchy

Adds transparent STL model thumbnails to GNOME Files on Omarchy, with install and removal controls in a Quattro bar widget. The widget uses a compact 2×2 isometric diamond grid icon.

The thumbnails are for browsing, not a substitute for a 3D viewer when checking a model's shape or dimensions.

The installer adds a GTK style rule to Nautilus thumbnail widgets: transparent background, no border or shadow, and no extra padding or margin. Nautilus does not expose an STL-only GTK selector, so the rule also affects other thumbnails.

## Screenshot

![.stl files preview screenshot](./screenshot.png)

Model: [Bag Clip Crocodile with Lock (Print in Place)](https://www.printables.com/model/1822754-bag-clip-crocodile-with-lock-print-in-place/).

## Install as an Omarchy Quattro plugin

Install the plugin with:

```bash
omarchy plugin add https://github.com/hajimetchi/omarchy_stl_preview.git --enable
```

The 2×2 isometric diamond icon appears in the bar's right section. Hover to see its **Manage STL previews** tooltip, then click it and choose **Install STL previews**. This opens an interactive terminal and runs `install.sh`; the script asks for your administrator password when it installs the renderer under `/usr/local/bin`. The plugin does not run the installer automatically.

Restart GNOME Files (close and reopen it, or log out and back in). Browse to a folder containing `.stl` files and use an icon or grid view. If thumbnails are disabled in Files, enable them in Files preferences. The first preview may take a moment to appear.

## Remove

Use **Remove STL previews** in the widget before removing the plugin with `omarchy plugin remove io.github.hajimetchi.stl-preview`. The removal action asks for your administrator password to delete the renderer from `/usr/local/bin`, then removes this integration's user-level registrations, style block, and failed-thumbnail cache entries. Other GTK style rules are preserved.

## Project files

| File | Purpose |
| --- | --- |
| `manifest.json`, `BarWidget.qml`, `Panel.qml`, `ActionButton.qml`, `icons/isometric-grid.svg` | Declare and implement the Quattro widget, 2×2 isometric grid icon, and install/remove panel. |
| `install.sh` | Installs the renderer, registers the thumbnailer and STL file type for your account, and applies the Nautilus thumbnail style. Launched by the widget. |
| `uninstall.sh` | Removes the renderer and registrations, then removes only the style block added by this project. Launched by the widget. |
| `bin/stl-thumbnailer` | Python program that reads an STL mesh and renders a transparent PNG thumbnail. |
| `share/thumbnailers/stl-preview.thumbnailer` | Tells GNOME which command to run to make thumbnails for STL files. |
| `share/mime/packages/stl-preview.xml` | Registers `.stl` files as STL models with the desktop file-type system. |
| `README.md` | Installation, removal, and project documentation. |

## How it works

GNOME Files uses the standard desktop thumbnailer system to request a PNG preview for an STL file. This project reads the mesh, projects its triangles into a shaded isometric-style view, and writes the thumbnail with a transparent background. It does not change the STL file itself.
