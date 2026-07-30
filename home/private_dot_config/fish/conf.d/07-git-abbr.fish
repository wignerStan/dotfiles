# ── Git Abbreviations ──────────────────────────────────────────
# Migrated from oh-my-zsh git plugin.
# Fish abbreviations expand on space/tab — type the short form, press space,
# and it expands in-place so you can review/edit before pressing Enter.

# ── Core ────────────────────────────────────────────────────────
abbr g    git
abbr ga   git add
abbr gaa  git add --all
abbr gapa git add --patch
abbr gau  git add --update

# ── Branch ──────────────────────────────────────────────────────
abbr gb   git branch
abbr gba  git branch --all
abbr gbd  git branch --delete
abbr gbD  git branch --delete --force
abbr gbm  git branch --move
abbr gbnm git branch --no-merged
abbr gbr  git branch --remote

# ── Checkout / Switch ──────────────────────────────────────────
abbr gco  git checkout
abbr gcb  git checkout -b
abbr gsw  git switch
abbr gswc git switch --create

# ── Commit ──────────────────────────────────────────────────────
abbr gc   git commit --verbose
abbr gca  git commit --verbose --all
abbr gcam git commit --all --message
abbr gcmsg git commit --message
abbr gc!  git commit --verbose --amend
abbr gca! git commit --verbose --all --amend
abbr gcn  git commit --verbose --no-edit
abbr gcn! git commit --verbose --no-edit --amend

# ── Diff ────────────────────────────────────────────────────────
abbr gd   git diff
abbr gdca git diff --cached
abbr gds  git diff --staged
abbr gdw  git diff --word-diff
abbr gdup git diff @{upstream}

# ── Fetch / Pull / Push ────────────────────────────────────────
abbr gf   git fetch
abbr gfo  git fetch origin
abbr gl   git pull
abbr gpr  git pull --rebase
abbr gp   git push
abbr gpf! git push --force
abbr gpd  git push --dry-run
abbr gpod git push origin --delete

# ── Rebase / Merge ─────────────────────────────────────────────
abbr grb  git rebase
abbr grba git rebase --abort
abbr grbc git rebase --continue
abbr grbi git rebase --interactive
abbr gm   git merge
abbr gma  git merge --abort

# ── Remote ──────────────────────────────────────────────────────
abbr gr   git remote
abbr grv  git remote --verbose
abbr gra  git remote add
abbr grrm git remote remove

# ── Reset / Restore ────────────────────────────────────────────
abbr grh  git reset
abbr grhh git reset --hard
abbr grs  git restore
abbr grst git restore --staged

# ── Status / Stash ─────────────────────────────────────────────
abbr gst  git status
abbr gss  git status --short
abbr gsb  git status --short --branch
abbr gsta git stash
abbr gstp git stash pop
abbr gstd git stash drop
abbr gstl git stash list
abbr gsts git stash show --patch

# ── Log / Show ──────────────────────────────────────────────────
abbr glog git log --oneline --decorate --graph
abbr glo  git log --oneline --decorate
abbr gsh  git show

# ── Worktree ────────────────────────────────────────────────────
abbr gwt  git worktree
abbr gwta git worktree add
abbr gwtls git worktree list
abbr gwtrm git worktree remove

# ── Tag / Clone ────────────────────────────────────────────────
abbr gta  git tag --annotate
abbr gcl  git clone --recurse-submodules

# ── Functions for complex operations ────────────────────────────

function gpsup --description 'Push current branch and set upstream'
    git push --set-upstream origin (git branch --show-current)
end

function gbgd --description 'Delete local branches whose upstream is gone (safe)'
    LANG=C git branch --no-color -vv | grep ': gone]' | cut -c 3- | awk '{print $1}' | xargs git branch -d
end

function gbgD --description 'Force-delete local branches whose upstream is gone'
    LANG=C git branch --no-color -vv | grep ': gone]' | cut -c 3- | awk '{print $1}' | xargs git branch -D
end
