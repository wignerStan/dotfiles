# Incident: Ghostty vi mode broken over SSH

**Date:** 2026-03-27
**Terminal:** Ghostty 1.3.1 (stable) on macOS
**Shell:** Fish 4.5 with `fish_vi_key_bindings`, `jk` escape chord, 30ms escape delay

## Affected Hosts

| Host | Type | Shell | Vi Mode Status | Notes |
|------|------|-------|----------------|-------|
| Local VM | LXC container | Fish | Works, but corrupts after GUI/nested SSH | Terminfo installed correctly |
| HPC cluster | Remote HPC | zsh 5.0.2 | Completely broken | xterm-ghostty terminfo was missing |

## Root Cause

### HPC cluster -- Stale ssh-terminfo cache + missing terminfo file

1. Ghostty's `ssh-terminfo` shell integration wraps the `ssh` command as a fish function
2. It maintains a cache of remote hosts where terminfo was installed: `~/.local/state/ghostty/ssh_cache`
3. The cache entry was stale, marked as "installed"
4. However, the actual file `~/.terminfo/x/xterm-ghostty` was **absent** on the remote
5. The SSH wrapper trusted the stale cache → set `TERM=xterm-ghostty` → remote had no terminfo definition → all terminal capabilities unknown → every key sequence broken

**Why the file went missing:** The HPC likely has periodic cleanup jobs or quota enforcement on `~/.terminfo/`.

**Why iTerm2 works:** iTerm2 sends `TERM=xterm-256color`, which exists on every system via `/usr/share/terminfo`. No custom terminfo installation needed.

**HPC complication:** The server has `sshd ForceCommand` configured. ForceCommand wraps the login in a script that shows a welcome banner. Despite this, TERM propagates correctly when PTY is allocated (`ssh -t`).

### Local VM -- Terminal state corruption after GUI/nested SSH

1. xterm-ghostty terminfo IS correctly installed
2. Fish vi mode works correctly in normal usage
3. After running GUI applications or nesting SSH sessions, the terminal state gets corrupted
4. `Super+Shift+R` (terminal reset, already configured in keybinds) restores normal operation
5. Known Ghostty behavior -- programs that modify terminal modes may not restore them properly on exit

## Environment Details

### Local (Ghostty)
```
TERM=xterm-ghostty
TERM_PROGRAM=ghostty
TERM_PROGRAM_VERSION=1.3.1
COLORTERM=truecolor
SHELL=fish 4.5
```

### Ghostty Config (relevant)
```
shell-integration = fish
shell-integration-features = ssh-terminfo,ssh-env,no-cursor,title
cursor-style = block
cursor-color = #ff9e64
```

### Fish Vi Mode Config (`~/.config/fish/conf.d/10-vi-mode.fish`)
```fish
function fish_user_key_bindings
    fish_vi_key_bindings
end
bind --mode insert --sets-mode default jk repaint
set -g fish_escape_delay_ms 30
function fish_mode_prompt; end
```

### Remote Environment (HPC)
```
SHELL=/bin/bash (login shell)
zsh 5.0.2 -- forced via ssh -t '/bin/zsh'
KEYTIMEOUT=40 (400ms, zsh centiseconds)
```

## Known Ghostty Bugs Referenced

- [#11031](https://github.com/ghostty-org/ghostty/discussions/11031) -- ssh-terminfo corrupts terminfo in zsh
- [#9251](https://github.com/ghostty-org/ghostty/issues/9251) -- ssh-terminfo cache doesn't distinguish domain vs IPv4
- [#9393](https://github.com/ghostty-org/ghostty/issues/9393) -- cache fails if `~/.local/state/` missing
- [#10364](https://github.com/ghostty-org/ghostty/discussions/10364) -- cache broken if `$TMPDIR` and `$XDG_STATE_HOME` differ
- [#9083](https://github.com/ghostty-org/ghostty/discussions/9083) -- screen update issues after terminfo install
- [#10102](https://github.com/ghostty-org/ghostty/discussions/10102) -- strange behavior via SSH (terminfo related)
- [#11206](https://github.com/ghostty-org/ghostty/discussions/11206) -- fish v4 escape sequence issues

## Temporary Fix Applied

Reinstalled terminfo manually:
```bash
infocmp -x xterm-ghostty | ssh <host> -- tic -x -
```

## Permanent Fix Options (not yet applied)

1. **Disable ssh-terminfo:** Change `ssh-terminfo` to `no-ssh-terminfo` in Ghostty config. Remote TERM becomes `xterm-256color` (same as iTerm2). Loses Ghostty-specific terminfo on remote but prevents recurrence.

2. **Clear cache periodically:** `ghostty +ssh-cache --clear` forces re-check on next connection. Fragile -- same issue will recur if HPC cleans up again.

3. **Force TERM globally:** Add `term = xterm-256color` to Ghostty config. Most aggressive -- also affects local terminfo.
