# Shared Shell Aliases
# This template is included in both .bashrc and .zshrc for consistency

# Navigation aliases
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'

# Use modern replacements if available
{{- if lookPath "eza" }}
alias ls='eza --icons --group-directories-first'
alias ll='eza -lah --icons --group-directories-first'
alias la='eza -a --icons --group-directories-first'
alias lt='eza --tree --icons --group-directories-first'
{{- else }}
alias ll='ls -lAh'
alias la='ls -A'
{{- end }}

{{- if lookPath "bat" }}
alias cat='bat --style=auto'
{{- end }}

# Git aliases
alias g='git'
alias gs='git status'
alias gp='git pull'
alias gP='git push'
alias gc='git commit'
alias gca='git commit -a'
alias gco='git checkout'
alias gb='git branch'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate'
alias gla='git log --oneline --graph --decorate --all'

# Docker aliases (if docker is available)
{{- if lookPath "docker" }}
alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias di='docker images'
alias dex='docker exec -it'
alias dlogs='docker logs -f'
{{- end }}

# Kubernetes aliases (if kubectl is available)
{{- if lookPath "kubectl" }}
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgd='kubectl get deployments'
alias kdp='kubectl describe pod'
alias kl='kubectl logs -f'
{{- end }}

# Chezmoi aliases for convenience
alias cz='chezmoi'
alias cza='chezmoi apply'
alias czd='chezmoi diff'
alias cze='chezmoi edit'
alias czu='chezmoi update'
alias czcd='chezmoi cd'

# Safety aliases
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# System-specific aliases
{{- if eq .chezmoi.os "darwin" }}
alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
alias showfiles='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder'
alias hidefiles='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder'
{{- end }}

{{- if eq .chezmoi.os "linux" }}
alias update='sudo apt update && sudo apt upgrade'
alias install='sudo apt install'
{{- end }}

# Networking
alias myip='curl -s ifconfig.me'
alias ports='netstat -tulanp'

# Disk usage
alias ducks='du -cks * | sort -rn | head'

# Process management
{{- if lookPath "htop" }}
alias top='htop'
{{- end }}

# Editor
{{- if lookPath "code" }}
alias e='code'
{{- else if lookPath "vim" }}
alias e='vim'
{{- end }}
