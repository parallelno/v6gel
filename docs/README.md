# v6gel Documentation Hub

Welcome to the documentation for the **v6gel game engine library** for the
Vector-06c. This hub links to topic-focused guides covering the engine, the
asset pipeline, and how to build everything.
New here? Start with the [Project Overview](01-overview.md), then read
[Building & Tooling](02-building.md).

## Table of Contents

| # | Topic | Description |
|---|-------|-------------|
| 1 | [Project Overview](01-overview.md) | What v6gel is, its goals, repository structure, and prerequisites. |
| 2 | [Building & Tooling](02-building.md) | How to build the library and assets; the tools the pipeline requires; CLI commands and flags. |
| 3 | [Asset Pipeline & Data Layout](03-asset-pipeline.md) | Source vs exported formats, the build config, and every asset type. |
| 4 | [v6gel Library Reference](04-engine-library.md) | The engine's public API: graphics, sound, controls, OS/files, and utilities. |

## Quick links

- **Build the engine:** [`v6/build.bat`](../v6/build.bat) → see [Building & Tooling](02-building.md#building-the-engine-library)
- **Build all assets:** `python scripts/build_assets.py assets/config.json -o build/release` → see [Building & Tooling](02-building.md#whole-build--build_assets)
- **Add a new asset:** [Asset Pipeline → Adding a new asset](03-asset-pipeline.md#adding-a-new-asset)

---

← Back to the [project README](../README.md).
