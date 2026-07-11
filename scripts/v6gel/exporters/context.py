"""Shared types for the v6 asset exporters.

Every exporter implements a single uniform entry point::

    def export(ctx: ExportContext) -> AssetManifest

``ExportContext`` carries everything an exporter needs (resolved paths, tool
locations, options). ``AssetManifest`` is the small, placement-agnostic record
an exporter produces describing the blob it generated; the separate ``v6loads``
tool consumes a set of these manifests to lay out the RAM Disk and emit the FDD
load routines.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Any, Optional

from utils import consts


@dataclass
class ExportContext:
	"""Inputs and options for a single asset export."""

	meta_path: str  # path to the asset meta JSON (e.g. assets/music/song01.json)
	meta: dict  # parsed meta JSON
	asset_type: str  # meta["asset_type"], may be refined by the CLI
	name: str  # asset base name, e.g. "song01"
	out_dir: str  # where *_meta.asm / manifest / optional *_data.asm go
	bin_dir: str  # where the raw .bin blob is written
	v6asm_path: str  # external assembler used to produce the blob
	packer_path: str  # external zx0 packer (format-intrinsic compression only)
	emit_asm: bool = False  # also keep the human-readable *_data.asm (debug)
	temp_dir: str = "build/temp/"
	# Extension (incl. dot) of the file actually stored on the FDD that the
	# linked meta should reference. The exporter always assembles a raw `.bin`;
	# the toolchain may transport-compress it to e.g. `.com`. Defaults to `.bin`.
	stored_ext: str = consts.EXT_BIN
	options: dict = field(default_factory=dict)  # extra per-type options

	@property
	def asset_dir(self) -> str:
		"""Directory containing the asset meta JSON (with trailing separator)."""
		return str(Path(self.meta_path).parent) + os.sep

	def asset_rel(self, key: str) -> str:
		"""Resolve a path stored in the meta JSON relative to the asset dir."""
		return os.path.join(self.asset_dir, self.meta[key])

	# output path helpers -----------------------------------------------------
	@property
	def meta_asm_path(self) -> str:
		return os.path.join(self.out_dir, self.name + "_meta" + consts.EXT_ASM)

	@property
	def data_asm_path(self) -> str:
		return os.path.join(self.out_dir, self.name + "_data" + consts.EXT_ASM)

	@property
	def bin_path(self) -> str:
		from utils import asmgen
		return os.path.join(self.bin_dir, asmgen.cpm_filename(self.name))

	@property
	def stored_path(self) -> str:
		"""Path/name the linked meta references (post transport compression)."""
		from utils import asmgen
		return os.path.join(self.bin_dir, asmgen.cpm_filename(self.name, self.stored_ext))

	@property
	def manifest_path(self) -> str:
		return os.path.join(self.out_dir, self.name + consts.EXT_MANIFEST)


@dataclass
class AssetManifest:
	"""Placement-agnostic description of an exported asset.

	Written next to the asset's outputs as ``<name>.manifest.json`` and later
	consumed by ``v6loads`` for RAM Disk packing and load-routine generation.
	"""

	name: str
	asset_type: str
	bin_path: str  # raw blob produced by the exporter
	bin_len: int  # length of that blob in bytes
	meta_asm_path: str  # linked-in metadata ASM
	data_asm_path: Optional[str] = None  # debug ASM, if --emit-asm
	# RAM Disk requirements (filled in by exporters that need placement):
	ram_disk_after_stack: bool = False  # must be placed in the high segment
	ram_disk_align: int = consts.WORD_LEN
	# Arbitrary exporter-specific extra info for v6loads (init labels etc.):
	extra: dict = field(default_factory=dict)

	def write(self, path: str) -> None:
		os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
		with open(path, "w", encoding="utf-8") as f:
			json.dump(asdict(self), f, indent="\t")

	@staticmethod
	def read(path: str) -> "AssetManifest":
		with open(path, "rb") as f:
			data: dict[str, Any] = json.load(f)
		return AssetManifest(**data)
