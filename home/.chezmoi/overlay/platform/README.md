# Platform overlays (local | cloud)

Host-platform capability delta lives here, layered over the shared manifest.
Unlike the old (wrong) design, package lists are NOT split into isolated
local/cloud trees — only genuine platform-delta files (e.g. cloud-only service
units, local-only mac application shims) go in this overlay tree.

Layout: home/.chezmoi/overlay/platform/<local|cloud>/<path>

Nothing here yet. `run_onchange_linux-cloud-services.sh.tmpl` is the cloud
provisioning entry; local platform deltas would go here (currently none),
and are excluded on the other side via `.chezmoiignore.tmpl`.