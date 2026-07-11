#!/usr/bin/env python3
"""clear.py - remove v6 build output directories.

A small standalone clean tool. By default it deletes a single build output
directory; ``--all`` deletes the whole build root.

  python clear.py build/release        # delete one build dir
  python clear.py --all build           # delete the entire build root
"""

import argparse
import os
import shutil
import sys

_SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
if _SCRIPTS_DIR not in sys.path:
	sys.path.insert(0, _SCRIPTS_DIR)

from utils.log import TextColor, printc


def parse_args(argv):
	p = argparse.ArgumentParser(prog="clear", description="Delete v6 build output.")
	p.add_argument("path", nargs="?", default="build/release",
				help="directory to delete (default: build/release)")
	p.add_argument("--all", action="store_true",
				help="treat 'path' as the build root and delete it entirely")
	return p.parse_args(argv)


def main(argv=None):
	args = parse_args(argv if argv is not None else sys.argv[1:])
	target = args.path

	if not os.path.exists(target):
		printc(f"clear: nothing to delete ({target} does not exist).", TextColor.GRAY)
		return 0

	if not os.path.isdir(target):
		printc(f"clear ERROR: not a directory: {target}", TextColor.RED)
		return 1

	shutil.rmtree(target)
	scope = "build root" if args.all else "build dir"
	printc(f"clear: removed {scope} {target}.", TextColor.GREEN)
	return 0


if __name__ == "__main__":
	sys.exit(main())
