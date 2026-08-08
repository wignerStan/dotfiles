# Facet overlays

Stackable capability overlays, available on ANY tier (simple included).
Declare a facet on a machine via `CHEZMOI_FACETS` env or `machine.toml`.

Overlay layout convention (chezmoi `.chezmoi` overlay dir maps 1:1 to the target
root, so keep a `facets/` prefix to avoid clobbering target paths):

    .chezmoi/overlay/facets/<facet>/<target-path>

Gate them in `.chezmoiignore.tmpl` with `has "<facet>" .facets` (or `.facets`).

Facet          purpose
─────          ─────────────────────────────────────────────────
dev            developer workspace tooling (formerly the develop tier)
research       research workspace: pixi project Python envs (packages.facets.research)
proxy          xray-core / sing-box server (see run_onchange_linux-cloud-services)
ai             sub2api gateway + CLI wrappers (cc/cc2/oc in .zshrc)
hpc            HPC cluster host (spack/fortran/cuda; formerly "calculate")

Current facets have no extra overlay files yet — their package content is in
.chezmoidata/packages.toml; add files here only when a facet needs more than
packages (e.g. a managed xray-core config for proxy).