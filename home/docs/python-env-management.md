# Python Environment Management — Selection Guide

## Three package managers, three purposes

```
conda-forge:  Fast, complete, pre-built R&D environments
Spack:        Deep custom builds, HPC, infra, performance tuning
PyPI/uv:      Upstream Python ecosystem, standard project workflow
```

### conda-forge (mamba/micromamba)

Use when:
- Quick scientific dev environment setup
- Frequently swapping packages and versions
- Don't want to manually handle BLAS, GDAL, MPI, compilers
- Notebook prototyping, team R&D environments

Trade-off: Sacrifice low-level customization for pre-compiled binaries,
unified solving, and fast iteration.

### Spack

Use when:
- HPC clusters
- Custom compiler flags and build parameters
- Specific CPU microarchitecture optimization
- Precise MPI, CUDA, BLAS provider selection
- Multiple ABI/variants coexisting
- Infrastructure, performance tuning, reproducible native software stack

Trade-off: Manages the entire native dependency DAG as infrastructure.

### PyPI/uv

Use when:
- Standard Python applications (web, data processing, automation)
- ML training and inference (PyTorch/JAX/TensorFlow official wheels)
- Production where upstream wheels provide complete coverage
- Containerized deployment and CI

Trade-off: Accept the native dependency combination decided by upstream
wheels — get the most direct upstream version and simplest install path.

## Decision matrix

```
Want to get environment running fast → conda-forge
Want to control every low-level link   → Spack
Want Python project's official install → PyPI/uv
```

All three are production-capable. The difference is what production values:
- **PyPI**: upstream consistency, simplest path
- **Conda**: entire binary stack coordination
- **Spack**: low-level controllability

## How this dotfiles uses them

### Base environment: mamba (conda-forge)

`/develop/mamba` (or `~/mamba` on macOS/Windows) is the shared base Python.
Installed via `mamba-sync-base.sh` — conda-forge for the scientific stack
(numpy, scipy, pandas, matplotlib, etc).

Currently pivoting to **pip-first**: all packages installed via pip/uv into
mamba base, since PyPI wheels now provide complete coverage including
numpy/scipy/rdkit. Conda-forge only needed when a package has no wheel or
requires specific native library coordination.

### Project environments: pixi

Pixi's core value: **projectize conda** and allow overlaying PyPI pure-Python
application layer (fastapi, etc) on top.

Pixi is NOT a unified solver. It's a two-stage solver with one-way bridging:

```
1. rattler/resolvo solves Conda dependencies first
2. Conda Python packages mapped to PyPI projects (via conda-pypi-map)
3. Mapped packages passed to uv as pinned/installed conditions
4. uv solves remaining PyPI dependencies
5. Both results written to single pixi.lock
```

**What works (one-way bridge):**
- Conda packages visible to uv solver (no duplicate numpy installs)
- Single lockfile for both ecosystems
- Cross-platform environments, features, tasks

**What doesn't work:**
- PyPI package can't satisfy Conda dependency (Conda solver runs first)
- uv can't trigger Conda solver backtracking (e.g., version conflict)
- Name mapping ≠ ABI compatibility guarantee

**Practical rule:** Put native/binary packages (python, CUDA, GDAL) in
`[dependencies]` (conda), put pure-Python app packages (fastapi, requests)
in `[pypi-dependencies]`.

### Project environments: uv (standalone)

For pure-Python projects with no conda dependencies, use `uv` directly:
- `uv sync` / `uv pip install` into `.venv`
- Shares wheel cache with pixi via `PIXI_CACHE_PYPI_WHEELS_DIR`
- On btrfs: reflinks between cache and `.venv` (near-zero disk overhead)

## Cache sharing

```
/develop/.cache/uv         ← shared by uv + pixi (wheel cache)
/develop/.cache/rattler    ← pixi conda package cache
/develop/.cache/kopia      ← backup cache (if applicable)
```

Both jacob and dev users share these caches (2770, group dev).
Reflinks (btrfs CoW) connect cache → project venvs on same filesystem.
