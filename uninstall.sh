#!/usr/bin/env bash
set -euo pipefail
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
sudo rm -f /usr/local/bin/stl-thumbnailer
rm -f "$HOME/.local/bin/stl-thumbnailer" "$data_home/thumbnailers/stl-preview.thumbnailer" "$data_home/mime/packages/stl-preview.xml"
python3 - "$config_home/gtk-4.0/gtk.css" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
if path.exists():
    start = "/* BEGIN stl_preview Nautilus transparent thumbnails */"
    end = "/* END stl_preview Nautilus transparent thumbnails */"
    text = path.read_text()
    if start in text and end in text:
        before, rest = text.split(start, 1)
        _, after = rest.split(end, 1)
        path.write_text((before.rstrip() + "\n" + after.lstrip()).lstrip("\n"))
PY
command -v update-mime-database >/dev/null && update-mime-database "$data_home/mime" || true
rm -f "$cache_home/thumbnails/fail/gnome-thumbnail-factory/"*.png
printf 'Removed STL preview support:\n'
printf '  - Removed the renderer, thumbnailer, and STL file-type registration.\n'
printf '  - Removed this project’s Nautilus thumbnail background and border rule and cleared failed-thumbnail cache entries.\n'
printf 'Restart Nautilus to apply the changes.\n'
