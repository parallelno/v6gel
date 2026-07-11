"""External tool discovery for the v6 pipeline.

Tool locations are resolved at run time instead of being hardcoded, so the
pipeline works on any machine. Each tool is resolved in this order:

1. an explicit value (e.g. a ``--asm`` CLI flag),
2. an environment variable (``V6ASM`` / ``V6FDD`` / ``ZX0``),
3. a vendored copy under the repo's ``tools/<name>/`` directory,
4. the system ``PATH`` (via :func:`shutil.which`).

If none match, a clear :class:`ExportError` tells the user how to fix it.
"""

import os
import shutil

from utils.log import ExportError

# Repo root = two levels up from this file (scripts/utils/tools.py).
_REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Environment variable names callers can set to point at each tool.
ENV_V6ASM = "V6ASM"
ENV_V6FDD = "V6FDD"
ENV_ZX0 = "ZX0"

# Default extra arguments appended to the zx0 packer command.
_ZX0_DEFAULT_ARGS = ["-classic"]

# Where the prerequisite tools come from, for actionable error messages.
_V6ASM_URL = "https://github.com/parallelno/v6asm"
_ZX0_URL = "https://github.com/emmanuel-marty/salvador/releases"


def _vendored(subdir, names):
	"""Return a tool path under ``tools/<subdir>/`` if one of ``names`` exists."""
	for name in names:
		candidate = os.path.join(_REPO_ROOT, "tools", subdir, name)
		if os.path.isfile(candidate):
			return candidate
	return None


def _which_any(names):
	"""Return the first of ``names`` found on PATH, or ``None``."""
	for name in names:
		found = shutil.which(name)
		if found:
			return found
	return None


def _resolve(cli_value, env_var, vendored_subdir, exe_names, what, url):
	if cli_value:
		return cli_value
	env_value = os.environ.get(env_var)
	if env_value:
		return env_value
	vendored = _vendored(vendored_subdir, exe_names)
	if vendored:
		return vendored
	on_path = _which_any(exe_names)
	if on_path:
		return on_path
	raise ExportError(
		f"could not find {what}",
		f"pass it explicitly, set the {env_var} environment variable, place it "
		f"under tools/{vendored_subdir}/, or add it to PATH. See {url}",
	)


def resolve_v6asm(cli_value=None):
	"""Resolve the path to the v6asm assembler."""
	return _resolve(
		cli_value, ENV_V6ASM, "v6asm",
		["v6asm.exe", "v6asm"], "the v6asm assembler", _V6ASM_URL,
	)


def resolve_v6fdd(cli_value=None):
	"""Resolve the path to the v6fdd floppy-image packer."""
	return _resolve(
		cli_value, ENV_V6FDD, "v6asm",
		["v6fdd.exe", "v6fdd"], "the v6fdd FDD packer", _V6ASM_URL,
	)


def resolve_zx0(cli_value=None):
	"""Resolve the zx0 packer command (executable plus default arguments)."""
	if cli_value:
		return cli_value
	env_value = os.environ.get(ENV_ZX0)
	if env_value:
		return env_value
	exe = _vendored("zx0", ["zx0salvador.exe", "zx0salvador", "salvador.exe", "salvador"])
	if exe is None:
		exe = _which_any(["zx0salvador.exe", "zx0salvador", "salvador.exe", "salvador"])
	if exe is None:
		raise ExportError(
			"could not find the zx0 (salvador) packer",
			f"set the {ENV_ZX0} environment variable, place zx0salvador under "
			f"tools/zx0/, or add it to PATH. See {_ZX0_URL}",
		)
	return " ".join([exe, *_ZX0_DEFAULT_ARGS])
