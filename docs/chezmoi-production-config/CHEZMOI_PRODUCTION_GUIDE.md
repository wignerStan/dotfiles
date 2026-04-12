# Production-Ready Chezmoi Configuration Guide

> **Level**: Production-Ready (Not Quick-Start)  
> **Audience**: DevOps Engineers, System Administrators, Power Users  
> **Last Updated**: 2026-01-11

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Key Features](#key-features)
4. [Setup & Installation](#setup--installation)
5. [Configuration Files](#configuration-files)
6. [Daily Operations](#daily-operations)
7. [Security Best Practices](#security-best-practices)
8. [Advanced Patterns](#advanced-patterns)
9. [Troubleshooting](#troubleshooting)

---

## Overview

### What Makes This "Production-Ready"?

This configuration goes beyond basic dotfile management by implementing:

- **🔐 Secure Secret Management**: Using `age` encryption for sensitive files
- **📦 Declarative Package Management**: OS-agnostic package manifests
- **🔄 Idempotent Operations**: Smart scripts that only run when needed
- **🎯 Profile-Based Configuration**: Separate work/personal machine setups
- **🌐 External Resource Management**: Frameworks and plugins without repo bloat
- **🧩 Modular Templates**: DRY principles with reusable template blocks
- **🔍 OS & Distro Detection**: Automatic adaptation to the target system

---

## Architecture

### Directory Structure

```
chezmoi-production-config/
├── .chezmoi.toml.tmpl              # ⚙️  Config template (interactive init)
├── .chezmoiignore                  # 🚫 Conditional file exclusions
├── .chezmoiexternal.toml           # 🌐 External resources (frameworks, fonts)
│
├── .chezmoidata/                   # 📊 Structured data (YAML/JSON/TOML)
│   └── packages.yaml               # Package manifests per OS
│
├── .chezmoitemplates/              # 🧩 Reusable template fragments
│   └── aliases.sh                  # Shared shell aliases
│
├── run_onchange_*.sh.tmpl          # 🔄 Scripts that re-run on data changes
│   └── install-packages.sh.tmpl    # Smart package installer
│
├── dot_gitconfig.tmpl              # 📝 Templated dotfiles
├── dot_zshrc.tmpl
│
└── private_dot_ssh/                # 🔐 Encrypted secrets
    └── private_id_rsa.age          # Age-encrypted SSH key
```

### File Naming Convention

Chezmoi uses special prefixes to control file behavior:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `dot_` | Creates file with `.` prefix | `dot_zshrc` → `~/.zshrc` |
| `private_` | Sets file permissions to `0600` | `private_id_rsa` → `~/.ssh/id_rsa` (600) |
| `.tmpl` | Processes file as Go template | `dot_gitconfig.tmpl` → evaluated template |
| `run_once_` | Runs script only once | `run_once_install-homebrew.sh` |
| `run_onchange_` | Re-runs when script changes | `run_onchange_install-packages.sh.tmpl` |
| `.age` | Encrypted with age | `private_key.age` → decrypted on apply |

---

## Key Features

### 1. 🔐 Secret Management with Age

**Why Age?**
- Modern, secure encryption (better than GPG for most use cases)
- No keyserver dependencies
- Simple key management

**Setup:**
```bash
# Generate age identity
age-keygen -o ~/.config/chezmoi/key.txt

# Get your public key (recipient)
age-keygen -y ~/.config/chezmoi/key.txt

# Update .chezmoi.toml.tmpl with your public key
```

**Encrypt a file:**
```bash
chezmoi encrypt --output private_dot_ssh/private_id_rsa.age ~/.ssh/id_rsa
```

**Decrypt locally (for viewing):**
```bash
chezmoi decrypt private_dot_ssh/private_id_rsa.age
```

### 2. 📦 Declarative Package Management

**File**: `.chezmoidata/packages.yaml`

This YAML file defines packages to install across different operating systems.

**Benefits:**
- ✅ Single source of truth for package requirements
- ✅ OS-specific package names handled automatically
- ✅ Re-runs when packages change (via `run_onchange_` hash)

### 3. 🔄 Smart Scripts (run_onchange_)

The `run_onchange_install-packages.sh.tmpl` script includes a hash of `packages.yaml`:

```bash
# Hash: {{ include ".chezmoidata/packages.yaml" | sha256sum }}
```

**How it works:**
1. When `packages.yaml` changes, the hash in the script changes
2. Chezmoi detects the script has changed
3. The script re-runs automatically on `chezmoi apply`

---

## Setup & Installation

### Initial Setup

1. **Install Chezmoi:**
   ```bash
   # macOS (Homebrew)
   brew install chezmoi
   
   # Linux (script)
   sh -c "$(curl -fsLS get.chezmoi.io)"
   ```

2. **Generate Age Key (for encryption):**
   ```bash
   mkdir -p ~/.config/chezmoi
   age-keygen -o ~/.config/chezmoi/key.txt
   
   # Save your public key
   age-keygen -y ~/.config/chezmoi/key.txt
   ```

3. **Initialize Chezmoi with this config:**
   ```bash
   # If you're creating a new repo
   chezmoi init --source=~/path/to/chezmoi-production-config
   
   # If you're cloning from GitHub
   chezmoi init --apply https://github.com/yourusername/dotfiles.git
   ```

4. **Answer Interactive Prompts:**
   - Email address (for Git)
   - Full name (for Git)
   - Machine profile (personal/work)
   - Encryption preference (age/gpg)

5. **Apply Configuration:**
   ```bash
   chezmoi apply
   ```

---

## Daily Operations

### Common Workflows

#### 1. **Edit a Dotfile**
```bash
# Edit in your preferred editor
chezmoi edit ~/.zshrc

# Review changes
chezmoi diff

# Apply changes
chezmoi apply
```

#### 2. **Add a New File**
```bash
# Add existing file to chezmoi
chezmoi add ~/.tmux.conf

# Edit it as a template
chezmoi edit ~/.tmux.conf
```

#### 3. **Update All Machines**
```bash
# On machine A: Make changes and push
chezmoi cd
git add .
git commit -m "Update zsh config"
git push

# On machine B: Pull and apply
chezmoi update
```

---

## Security Best Practices

### 1. **Never Commit Unencrypted Secrets**

❌ **Bad:**
```bash
chezmoi add ~/.ssh/id_rsa  # Stores plaintext!
```

✅ **Good:**
```bash
chezmoi encrypt --output private_dot_ssh/private_id_rsa.age ~/.ssh/id_rsa
```

### 2. **Use Age Identity File Permissions**

```bash
chmod 600 ~/.config/chezmoi/key.txt
```

### 3. **Audit Before Apply**

Always review changes before applying:
```bash
chezmoi diff | less
chezmoi apply --dry-run -v
```

---

## Troubleshooting

### Issue: "age: error: no identity matched any of the file's recipients"

**Cause**: Your age public key in `.chezmoi.toml.tmpl` doesn't match your identity file.

**Fix:**
```bash
# Get your correct public key
age-keygen -y ~/.config/chezmoi/key.txt

# Update .chezmoi.toml.tmpl with the correct recipient
chezmoi edit-config-template
```

### Issue: Scripts not re-running when data changes

**Cause**: Missing or incorrect hash in script comment.

**Fix:** Ensure the script has:
```bash
# Hash: {{ include ".chezmoidata/packages.yaml" | sha256sum }}
```

---

## Comparison: Quick-Start vs. Production-Ready

| Feature | Quick-Start | Production-Ready (This Config) |
|---------|-------------|-------------------------------|
| **Encryption** | None | ✅ Age encryption for secrets |
| **Package Management** | Manual | ✅ Declarative YAML manifest |
| **OS Detection** | Basic | ✅ Distro-level detection |
| **External Resources** | Store in repo | ✅ Auto-download with `.chezmoiexternal` |
| **Modularity** | Duplicate code | ✅ Reusable templates |
| **Profile Support** | None | ✅ Work/Personal separation |
| **Smart Scripts** | Simple `run_once` | ✅ `run_onchange` with data hashing |
| **Interactive Setup** | Manual editing | ✅ Prompts during init |

---

## References

- [Official Chezmoi Documentation](https://www.chezmoi.io/)
- [Age Encryption Tool](https://age-encryption.org/)
- [Go Template Documentation](https://pkg.go.dev/text/template)

---

**Generated by your AI assistant** 🤖
