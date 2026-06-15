#!/usr/bin/env python3
"""install_tools.py - fetch the external tools the v6gel pipeline drives.

Reads ``tools.lock.json`` and downloads each tool's release archive for the
current platform into ``tools/<dest>/`` (which is gitignored). The asset
exporters and the build driver discover tools there automatically (see
``scripts/utils/tools.py``), so no PATH or environment setup is required after
a successful install.

Usage
-----
    python install_tools.py              # install every tool for this OS
    python install_tools.py v6asm zx0    # install only the named tools
    python install_tools.py --list       # show tools and install state
    python install_tools.py --force      # re-download even if present

Security
--------
Pin a ``sha256`` in the manifest to verify a download's integrity; when a hash
is present a mismatch aborts the install. A ``null`` hash only prints a warning
(the project chose not to block on missing hashes). Archives are extracted with
path-traversal ("zip-slip") protection.
"""

import argparse
import hashlib
import os
import platform
import shutil
import sys
import tarfile
import tempfile
import urllib.request
import zipfile

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
MANIFEST_PATH = os.path.join(REPO_ROOT, "tools.lock.json")
TOOLS_DIR = os.path.join(REPO_ROOT, "tools")


def _platform_key():
	"""Return the manifest platform key for the running machine."""
	system = platform.system()
	machine = platform.machine().lower()
	arch = "x86_64" if machine in ("x86_64", "amd64", "x64") else machine
	os_name = {"Windows": "windows", "Linux": "linux", "Darwin": "macos"}.get(system)
	if os_name is None:
		return None
	return f"{os_name}-{arch}"


def _load_manifest():
	import json
	if not os.path.isfile(MANIFEST_PATH):
		sys.exit(f"manifest not found: {MANIFEST_PATH}")
	with open(MANIFEST_PATH, "rb") as f:
		return json.load(f)["tools"]


def _is_installed(dest):
	path = os.path.join(TOOLS_DIR, dest)
	return os.path.isdir(path) and any(os.scandir(path))


def _download(url, dst_path):
	"""Download ``url`` to ``dst_path`` with a simple progress line."""
	def _hook(block_num, block_size, total_size):
		if total_size <= 0:
			return
		done = min(block_num * block_size, total_size)
		pct = done * 100 // total_size
		sys.stdout.write(f"\r    downloading... {pct:3d}% ({done >> 10} KiB)")
		sys.stdout.flush()

	urllib.request.urlretrieve(url, dst_path, _hook)  # noqa: S310 (trusted release URLs)
	sys.stdout.write("\n")


def _sha256(path):
	h = hashlib.sha256()
	with open(path, "rb") as f:
		for chunk in iter(lambda: f.read(1 << 20), b""):
			h.update(chunk)
	return h.hexdigest()


def _safe_extract_zip(archive, dest):
	for member in archive.namelist():
		target = os.path.realpath(os.path.join(dest, member))
		if not target.startswith(os.path.realpath(dest) + os.sep) and target != os.path.realpath(dest):
			raise RuntimeError(f"unsafe path in archive: {member}")
	archive.extractall(dest)


def _safe_extract_tar(archive, dest):
	dest_real = os.path.realpath(dest)
	for member in archive.getmembers():
		target = os.path.realpath(os.path.join(dest, member.name))
		if not target.startswith(dest_real + os.sep) and target != dest_real:
			raise RuntimeError(f"unsafe path in archive: {member.name}")
	archive.extractall(dest)


def _extract(archive_path, dest):
	os.makedirs(dest, exist_ok=True)
	if archive_path.endswith(".zip"):
		with zipfile.ZipFile(archive_path) as zf:
			_safe_extract_zip(zf, dest)
	elif archive_path.endswith((".tar.gz", ".tgz")):
		with tarfile.open(archive_path, "r:gz") as tf:
			_safe_extract_tar(tf, dest)
	else:
		raise RuntimeError(f"unsupported archive type: {archive_path}")


def _flatten_single_root(dest):
	"""If ``dest`` holds exactly one subdirectory, lift its contents up a level."""
	entries = list(os.scandir(dest))
	if len(entries) == 1 and entries[0].is_dir():
		inner = entries[0].path
		for child in os.listdir(inner):
			shutil.move(os.path.join(inner, child), os.path.join(dest, child))
		os.rmdir(inner)


def _install_one(name, spec, plat_key, force):
	dest_dir = os.path.join(TOOLS_DIR, spec["dest"])
	entry = spec.get("platforms", {}).get(plat_key)
	if entry is None:
		print(f"  {name}: no {plat_key} release available - skipping")
		return True

	if _is_installed(spec["dest"]) and not force:
		print(f"  {name}: already installed ({spec['dest']}/) - skipping (use --force to reinstall)")
		return True

	url = entry["url"]
	print(f"  {name} {spec.get('version', '')} <- {url}")

	if force and os.path.isdir(dest_dir):
		shutil.rmtree(dest_dir)

	suffix = ".zip" if url.endswith(".zip") else ".tar.gz"
	tmp_fd, tmp_path = tempfile.mkstemp(suffix=suffix)
	os.close(tmp_fd)
	try:
		_download(url, tmp_path)

		expected = entry.get("sha256")
		actual = _sha256(tmp_path)
		if expected:
			if actual.lower() != expected.lower():
				print(f"    ERROR: sha256 mismatch\n      expected {expected}\n      got      {actual}")
				return False
			print("    sha256 OK")
		else:
			print(f"    WARNING: no sha256 pinned; got {actual} (add it to tools.lock.json to verify)")

		_extract(tmp_path, dest_dir)
		_flatten_single_root(dest_dir)
		print(f"    installed -> tools/{spec['dest']}/")
		return True
	finally:
		if os.path.exists(tmp_path):
			os.remove(tmp_path)


def main(argv=None):
	parser = argparse.ArgumentParser(
		prog="install_tools",
		description="Download the external tools used by the v6gel pipeline.",
	)
	parser.add_argument("tools", nargs="*", help="tool names to install (default: all)")
	parser.add_argument("--list", action="store_true", help="list tools and install state, then exit")
	parser.add_argument("--force", action="store_true", help="re-download even if already installed")
	args = parser.parse_args(argv)

	manifest = _load_manifest()
	plat_key = _platform_key()

	if args.list:
		print(f"platform: {plat_key or 'unsupported'}")
		for name, spec in manifest.items():
			state = "installed" if _is_installed(spec["dest"]) else "missing"
			avail = "yes" if plat_key in spec.get("platforms", {}) else "no release"
			print(f"  {name:10s} {spec.get('version', ''):14s} [{state:9s}] this-OS: {avail}")
		return 0

	if plat_key is None:
		sys.exit(f"unsupported platform: {platform.system()} {platform.machine()}")

	wanted = args.tools or list(manifest.keys())
	unknown = [t for t in wanted if t not in manifest]
	if unknown:
		sys.exit(f"unknown tool(s): {', '.join(unknown)} (known: {', '.join(manifest)})")

	os.makedirs(TOOLS_DIR, exist_ok=True)
	print(f"Installing {len(wanted)} tool(s) for {plat_key} into tools/")
	ok = True
	for name in wanted:
		ok = _install_one(name, manifest[name], plat_key, args.force) and ok

	print("Done." if ok else "Done with errors.")
	return 0 if ok else 1


if __name__ == "__main__":
	sys.exit(main())
