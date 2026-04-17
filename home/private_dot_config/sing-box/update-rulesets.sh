#!/bin/bash
# Downloads/updates sing-box .srs rule-set files from GitHub
set -euo pipefail

RULESET_DIR="/opt/homebrew/etc/sing-box/rulesets"
BASE_URL="https://raw.githubusercontent.com"

declare -A RULESETS=(
  ["geoip-cn.srs"]="SagerNet/sing-geoip/rule-set/geoip-cn.srs"
  ["geosite-apple.srs"]="SagerNet/sing-geosite/rule-set/geosite-apple.srs"
  ["geosite-category-ads-all.srs"]="SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs"
  ["geosite-category-scholar-!cn.srs"]="SagerNet/sing-geosite/rule-set/geosite-category-scholar-!cn.srs"
  ["geosite-category-scholar-cn.srs"]="SagerNet/sing-geosite/rule-set/geosite-category-scholar-cn.srs"
  ["geosite-cn.srs"]="SagerNet/sing-geosite/rule-set/geosite-cn.srs"
  ["geosite-geolocation-!cn.srs"]="SagerNet/sing-geosite/rule-set/geosite-geolocation-!cn.srs"
  ["geosite-github.srs"]="SagerNet/sing-geosite/rule-set/geosite-github.srs"
  ["geosite-google.srs"]="SagerNet/sing-geosite/rule-set/geosite-google.srs"
  ["geosite-netflix.srs"]="SagerNet/sing-geosite/rule-set/geosite-netflix.srs"
  ["geosite-openai.srs"]="SagerNet/sing-geosite/rule-set/geosite-openai.srs"
  ["geosite-spotify.srs"]="SagerNet/sing-geosite/rule-set/geosite-spotify.srs"
  ["geosite-telegram.srs"]="SagerNet/sing-geosite/rule-set/geosite-telegram.srs"
  ["geosite-tiktok.srs"]="SagerNet/sing-geosite/rule-set/geosite-tiktok.srs"
  ["geosite-youtube.srs"]="SagerNet/sing-geosite/rule-set/geosite-youtube.srs"
)

for file in "${!RULESETS[@]}"; do
  url="${BASE_URL}/${RULESETS[$file]}"
  dest="${RULESET_DIR}/${file}"
  tmp="${dest}.tmp"
  if curl -fsSL -o "$tmp" "$url"; then
    mv "$tmp" "$dest"
    echo "Updated: ${file}"
  else
    rm -f "$tmp"
    echo "Failed:  ${file} (keeping existing)" >&2
  fi
done

# Reload sing-box if running as brew service
if brew services info sing-box --json 2>/dev/null | grep -q '"running"'; then
  sudo brew services restart sing-box
fi
