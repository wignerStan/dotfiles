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

`<shared_workspace>/mamba` (or `~/mamba` on macOS/Windows) is the shared
base Python. `shared_workspace` comes from `machine.toml` (only the personal
Linux box sets it, e.g. `/develop`); other machines default to `~/mamba`.
Installed via `mamba-sync-base.sh` — the **scientific stack lives on the
conda-forge channel** (numpy, scipy, gensim, …): conda is the base-env package
manager for native/scientific pieces. Pure-python and well-wheeled packages
(non-scientific pip list in `mamba_base.toml` core) install via pip/uv into the
same base. Anything without a cp314 wheel (e.g. the former spaCy backend
thinc/blis/cymem/…) is NOT installable on the current base python (3.14) and is
kept out of the list.

**L4 facet envs** (`[mamba_base.<facet>]`): each facet gets its OWN env, not a
base merge — e.g. dev → `develop` env (python 3.12 + `ta-lib` + dev pip list),
created by the mamba-sync dev branch. `mamba_sections` is always `["core"]`
(base only).

### Project environments: pixi

**Pixi = project-scoped Conda environment manager with coordinated PyPI
application layer overlay.**

Core value: take Conda/conda-forge from user-level environment management
to Cargo/uv-style project-level management, then allow projects to layer
PyPI applications on top.

Typical project layering:

```
pixi workspace
├── Conda/conda-forge base layer
│   ├── Python runtime
│   ├── NumPy / SciPy / RDKit / GDAL
│   ├── compilers, system libs, CLI tools
│   └── cross-platform binary dependencies
│
└── PyPI application layer
    ├── FastAPI, Pydantic, Uvicorn
    ├── business code dependencies
    └── current project editable install
```

Pixi puts the full project lifecycle in one place:
- `pixi.toml` / `pyproject.toml` manifest
- `pixi.lock` lockfile
- project-local environments (not a global conda env)
- tasks, features, multiple dev/test/cuda environments
- multi-platform dependency declaration

The two-solver bridging is the mechanism that makes mixed environments
work, NOT the core product value. It's still two-stage, Conda-first:

```
1. rattler/resolvo solves Conda dependencies
2. Conda Python packages mapped to PyPI distributions
3. uv solves remaining PyPI dependencies
4. Both results in single pixi.lock
```

**One-way bridge (Conda → PyPI):**
- Conda packages visible to uv (no duplicate numpy)
- Single lockfile, cross-platform, reproducible

**Limitations (not a unified solver):**
- PyPI package can't satisfy Conda dependency
- uv can't trigger Conda solver backtracking
- Name mapping ≠ ABI compatibility guarantee

**Practical rule:** Native/binary packages (python, CUDA, GDAL) →
`[dependencies]` (conda). Pure-Python app packages (fastapi, requests) →
`[pypi-dependencies]`. Not because conda-forge can't install them, but
because they belong to the application layer that follows the project's
pyproject.toml, testing, and release workflow.

Example project:

```toml
[workspace]
channels = ["conda-forge"]
platforms = ["linux-64", "osx-arm64"]

[dependencies]
python = "3.12.*"
numpy = "*"
scipy = "*"
rdkit = "*"

[pypi-dependencies]
fastapi = "*"
uvicorn = "*"
my-project = { path = ".", editable = true }

[tasks]
serve = "uvicorn my_project.app:app --reload"
test = "pytest"
```

Updating dependencies updates the lockfile and environments — no manual
global conda env maintenance.

### Project environments: uv (standalone)

For pure-Python projects with no conda dependencies, use `uv` directly:
- `uv sync` / `uv pip install` into `.venv`
- Shares wheel cache with pixi via `PIXI_CACHE_PYPI_WHEELS_DIR`
- On btrfs: reflinks between cache and `.venv` (near-zero disk overhead)

## Cache sharing

Cache placement is independent from the mamba root. A machine may set
`shared_cache` when a shared workspace exists; the Incus `dev` profile uses
`/develop/cache` (the parent is `2755 dev:dev`, while mutable subdirectories
are account-owned) because it is user-only and cannot assume root-managed ACLs:
```
<shared_cache>/uv                     <- uv + pixi wheel cache
<shared_cache>/rattler                <- pixi conda package cache
<shared_cache>/mamba                  <- conda package cache
<shared_cache>/npm                    <- npm cache redirect
<shared_cache>/pnpm                   <- pnpm store/cache/state/global/bin
<shared_cache>/bun                    <- Bun cache/global/bin (BUN_INSTALL_*)
<shared_cache>/kopia                  <- backup cache (if applicable)
```
Other machines use default user caches (`~/.cache/uv`, `~/.cache/npm`, ...).
The mamba environment root remains at `<shared_workspace>/mamba`; mutable tool
and package caches are under `shared_cache`. Reflinks (btrfs CoW) connect cache
to project venvs on the same filesystem.
