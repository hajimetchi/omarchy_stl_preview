#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
user_record="$data_home/stl-preview/ownership.json"
thumbnailer_bin="/usr/local/bin/stl-thumbnailer"
ownership_record="/var/lib/stl-preview/stl-thumbnailer.sha256"
# Refuse to claim an existing system path unless our root-owned record proves
# that this installer installed the unchanged executable there.
if sudo test -e "$thumbnailer_bin"; then
  if ! sudo test -f "$ownership_record"; then
    printf 'Refusing to replace %s: it exists without this plugin\'s ownership record.\n' "$thumbnailer_bin" >&2
    exit 1
  fi
  installed_hash="$(sudo sha256sum "$thumbnailer_bin" | awk '{print $1}')"
  recorded_hash="$(sudo cat "$ownership_record")"
  if [[ "$installed_hash" != "$recorded_hash" ]]; then
    printf 'Refusing to replace %s: its contents no longer match this plugin\'s ownership record.\n' "$thumbnailer_bin" >&2
    exit 1
  fi
elif sudo test -e "$ownership_record"; then
  printf 'Refusing to install: ownership record exists but %s is missing. Remove the stale record after reviewing it.\n' "$thumbnailer_bin" >&2
  exit 1
fi
# Check user-level destinations before changing the system executable or any
# user files. Existing files are only managed when our record still matches.
python3 - "$data_home" "$config_home" "$user_record" <<'PY'
import hashlib, json, sys
from pathlib import Path

data, config, record = map(Path, sys.argv[1:])
managed = {
    data / "thumbnailers/stl-preview.thumbnailer",
    data / "mime/packages/stl-preview.xml",
}
css = config / "gtk-4.0/gtk.css"
start, end = "/* BEGIN stl_preview Nautilus transparent thumbnails */", "/* END stl_preview Nautilus transparent thumbnails */"
state = json.loads(record.read_text()) if record.exists() else None
if state is None:
    conflicts = [str(p) for p in managed if p.exists()]
    if css.exists() and (start in css.read_text() or end in css.read_text()):
        conflicts.append(str(css) + " (existing plugin marker without ownership record)")
    if conflicts:
        raise SystemExit("Refusing to overwrite unowned user files: " + ", ".join(conflicts))
else:
    for p in managed:
        old = state["files"].get(str(p))
        if p.exists() and (old is None or hashlib.sha256(p.read_bytes()).hexdigest() != old):
            raise SystemExit(f"Refusing to overwrite changed or unowned file: {p}")
    if css.exists() and state.get("css_block"):
        text = css.read_text()
        if start not in text or end not in text:
            raise SystemExit(f"Refusing to change CSS; managed block is missing: {css}")
        block = text.split(start, 1)[1].split(end, 1)[0]
        digest = hashlib.sha256((start + block + end).encode()).hexdigest()
        if digest != state["css_block"]:
            raise SystemExit(f"Refusing to change CSS; managed block was edited: {css}")
PY
mkdir -p "$data_home/thumbnailers" "$data_home/mime/packages"
# GNOME runs thumbnailers in a bubblewrap sandbox that exposes /usr, not the
# user's home directory. Install the executable under /usr/local/bin so it is
# available inside that sandbox.
sudo install -D -m 755 "$root/bin/stl-thumbnailer" "$thumbnailer_bin"
sudo install -d -m 755 "$(dirname "$ownership_record")"
printf '%s\n' "$(sha256sum "$thumbnailer_bin" | awk '{print $1}')" | sudo tee "$ownership_record" >/dev/null
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
path.parent.mkdir(parents=True, exist_ok=True)
text = path.read_text() if path.exists() else ""
# Only replace this plugin's explicitly marked block. Unmarked CSS may belong
# to the user even when its text happens to match an older plugin rule.
if start in text and end in text:
    before, rest = text.split(start, 1)
    _, after = rest.split(end, 1)
    text = before.rstrip() + ("\n\n" if before.strip() else "") + block + after
else:
    text = text.rstrip() + ("\n\n" if text.strip() else "") + block + "\n"
path.write_text(text)
PY
command -v update-mime-database >/dev/null && update-mime-database "$data_home/mime" || true
python3 - "$data_home" "$config_home" "$user_record" <<'PY'
import hashlib, json, sys
from pathlib import Path
data, config, record = map(Path, sys.argv[1:])
files = [data / "thumbnailers/stl-preview.thumbnailer", data / "mime/packages/stl-preview.xml"]
css = config / "gtk-4.0/gtk.css"
text = css.read_text()
start, end = "/* BEGIN stl_preview Nautilus transparent thumbnails */", "/* END stl_preview Nautilus transparent thumbnails */"
block = start + text.split(start, 1)[1].split(end, 1)[0] + end
record.parent.mkdir(parents=True, exist_ok=True)
record.write_text(json.dumps({"files": {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}, "css_block": hashlib.sha256(block.encode()).hexdigest()}, indent=2) + "\n")
PY
printf 'Installed STL preview support:\n'
printf '  - Installed the renderer and registered the thumbnailer and STL file type.\n'
printf '  - Removed Nautilus thumbnail backgrounds and borders.\n'
printf '  - Recorded ownership of user-level registrations and the marked style block.\n'
printf 'Restart Nautilus to load the changes.\n'
