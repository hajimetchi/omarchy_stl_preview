#!/usr/bin/env python3
"""Update the owned thumbnailer descriptor with the selected input size cap."""
import hashlib
import json
import os
import re
import sys
import tempfile
from pathlib import Path

ALLOWED = {8, 16, 32, 64, 128}


def atomic_write(path: Path, data: bytes, mode: int) -> None:
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def main() -> None:
    mib = int(sys.argv[1])
    if mib not in ALLOWED:
        raise ValueError("Unsupported STL file size limit")
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    record = data_home / "stl-preview/ownership.json"
    descriptor = data_home / "thumbnailers/stl-preview.thumbnailer"
    state = json.loads(record.read_text())
    files = state.get("files", {})
    expected = files.get(str(descriptor))
    if not expected or not descriptor.is_file():
        raise ValueError("The installed thumbnailer descriptor is not owned by this plugin")
    original = descriptor.read_bytes()
    if hashlib.sha256(original).hexdigest() != expected:
        raise ValueError("The thumbnailer descriptor changed outside the plugin")
    text = original.decode("utf-8")
    pattern = re.compile(r"(?m)^(Exec=/usr/local/bin/stl-thumbnailer %i %o %s)(?: \d+)?$")
    updated, count = pattern.subn(rf"\g<1> {mib * 1024 * 1024}", text)
    if count != 1:
        raise ValueError("Could not safely identify the plugin thumbnailer command")
    descriptor_bytes = updated.encode("utf-8")
    state["files"][str(descriptor)] = hashlib.sha256(descriptor_bytes).hexdigest()
    record_bytes = (json.dumps(state, indent=2) + "\n").encode("utf-8")
    atomic_write(descriptor, descriptor_bytes, 0o644)
    try:
        atomic_write(record, record_bytes, 0o600)
    except BaseException:
        # Keep the ownership record truthful if persisting its new hash fails.
        atomic_write(descriptor, original, 0o644)
        raise


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"set-file-cap.py: {exc}", file=sys.stderr)
        sys.exit(1)
