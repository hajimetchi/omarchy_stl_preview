#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
thumbnailer_bin="/usr/local/bin/stl-thumbnailer"
mkdir -p "$data_home/thumbnailers" "$data_home/mime/packages"
# GNOME runs thumbnailers in a bubblewrap sandbox that exposes /usr, not the
# user's home directory. Install the executable under /usr/local/bin so it is
# available inside that sandbox.
sudo install -D -m 755 "$root/bin/stl-thumbnailer" "$thumbnailer_bin"
install -m 644 "$root/share/thumbnailers/stl-preview.thumbnailer" "$data_home/thumbnailers/stl-preview.thumbnailer"
install -m 644 "$root/share/mime/packages/stl-preview.xml" "$data_home/mime/packages/stl-preview.xml"
sed -i "s|^TryExec=.*|TryExec=$thumbnailer_bin|; s|^Exec=.*|Exec=$thumbnailer_bin %i %o %s|" "$data_home/thumbnailers/stl-preview.thumbnailer"
python3 - "$config_home/gtk-4.0/gtk.css" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
start = "/* BEGIN stl_preview Nautilus transparent thumbnails */"
end = "/* END stl_preview Nautilus transparent thumbnails */"
rule = ".nautilus-window.view .thumbnail {\n  background: none;\n  border: none;\n  box-shadow: none;\n  padding: 0;\n  margin: 0;\n}"
block = f"{start}\n{rule}\n{end}"
legacy_rules = [
    ".nautilus-window.view .thumbnail {\n  background: none;\n}\n",
    ".nautilus-window.view .thumbnail {\n  background: none;\n  border: none;\n}\n",
    rule + "\n",
]
path.parent.mkdir(parents=True, exist_ok=True)
text = path.read_text() if path.exists() else ""
# Migrate the exact unmarked rule previously added by this installer workflow.
for legacy in legacy_rules:
    text = text.replace(legacy, "")
if start in text and end in text:
    before, rest = text.split(start, 1)
    _, after = rest.split(end, 1)
    text = before.rstrip() + ("\n\n" if before.strip() else "") + block + after
else:
    text = text.rstrip() + ("\n\n" if text.strip() else "") + block + "\n"
path.write_text(text)
PY
command -v update-mime-database >/dev/null && update-mime-database "$data_home/mime" || true
command -v update-desktop-database >/dev/null && update-desktop-database "$data_home/applications" 2>/dev/null || true
rm -f "$cache_home/thumbnails/fail/gnome-thumbnail-factory/"*.png
printf 'Installed STL preview support:\n'
printf '  - Installed the renderer and registered the thumbnailer and STL file type.\n'
printf '  - Removed Nautilus thumbnail backgrounds and borders.\n'
printf '  - Cleared failed-thumbnail cache entries so previews can be regenerated.\n'
printf 'Restart Nautilus to load the changes.\n'
