#!/usr/bin/env python3
"""Fetch subscription, convert proxy nodes to sing-box outbounds, inject into config.

Auto-detects subscription format:
  - Sing-box JSON (outbounds array or list of outbound objects)
  - Clash/Mihomo YAML (proxies: list)
  - SIP008 JSON (Shadowsocks servers array)
  - Base64-encoded proxy URI links
  - Plain proxy URI links (ss://, vmess://, vless://, trojan://, etc.)

Usage:
  # Fetch from URL, inject into rendered template, output to file
  chezmoi execute-template < config.json.tmpl | ./inject-sub.py -s URL -o config.json

  # Android
  chezmoi execute-template < config-android.json.tmpl | ./inject-sub.py -s URL -o config-android.json

  # Read from local file
  ./inject-sub.py -s sub.yaml -o config.json < base_config.json

  # Pipe subscription content via stdin (config on file)
  ./inject-sub.py -f sub.yaml -o config.json < base_config.json
"""

import argparse
import base64
import json
import re
import sys
import urllib.parse
from collections import defaultdict
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None

REGION_MAP = {
    "HK": ["香港", "HK", "Hong Kong"],
    "TW": ["台湾", "🇹🇼", "Taiwan"],
    "SG": ["新加坡", "🇸🇬", "Singapore"],
    "KR": ["韩国", "🇰🇷", "Korea"],
    "JP": ["日本", "🇯🇵", "Japan"],
    "UK": ["英国", "🇬🇧", "United Kingdom"],
    "US": ["美国", "🇺🇸", "United States"],
    "DE": ["德国", "🇩🇪", "Germany"],
    "FR": ["法国", "🇫🇷", "France"],
    "AU": ["澳大利亚", "🇦🇺", "Australia"],
    "CA": ["加拿大", "🇨🇦", "Canada"],
    "RU": ["俄罗斯", "🇷🇺", "Russia"],
    "IN": ["印度", "🇮🇳", "India"],
    "TH": ["泰国", "🇹🇭", "Thailand"],
    "MY": ["马来西亚", "🇲🇾", "Malaysia"],
    "PH": ["菲律宾", "🇵🇭", "Philippines"],
    "NL": ["荷兰", "🇳🇱", "Netherlands"],
}


def detect_region(name):
    for region, keywords in REGION_MAP.items():
        for kw in keywords:
            if kw in name:
                return region
    return None


def parse_uri_links(text):
    nodes = []
    schemes = ("anytls://", "vmess://", "vless://", "trojan://", "ss://", "hysteria2://", "hy2://")
    for line in text.strip().splitlines():
        line = line.strip()
        matched = None
        for s in schemes:
            if line.startswith(s):
                matched = s
                break
        if not matched:
            continue

        main, _, fragment = line.partition("#")
        name = urllib.parse.unquote(fragment) or "unknown"
        scheme = matched.rstrip("://")
        body = main[len(matched):]

        try:
            if scheme == "vmess":
                # vmess://base64json
                decoded = base64.b64decode(body).decode("utf-8", errors="replace")
                v = json.loads(decoded)
                nodes.append({
                    "type": "vmess", "name": v.get("ps", name),
                    "server": v["add"], "port": int(v["port"]),
                    "uuid": v["id"], "alter_id": v.get("aid", 0),
                    "cipher": v.get("scy", "auto"),
                    "tls": v.get("tls", "") == "tls",
                    "sni": v.get("sni", ""), "insecure": v.get("allowInsecure", False),
                    "network": v.get("net", ""),
                    "ws_opts": {"path": v.get("path", "/"), "headers": v.get("host", {}).get("Host", "")} if v.get("net") == "ws" else None,
                    "grpc_opts": {"grpc-service-name": v.get("path", "")} if v.get("net") == "grpc" else None,
                })
            elif scheme == "vless":
                uuid, _, rest = body.partition("@")
                server_port = rest.split("/")[0].split("?")[0]
                server, _, port = server_port.rpartition(":")
                querypart = rest.split("?", 1)[-1] if "?" in rest else ""
                params = dict(urllib.parse.parse_qsl(querypart))
                ptype = params.get("type", "")
                nodes.append({
                    "type": "vless", "name": name,
                    "server": server, "port": int(port),
                    "uuid": uuid, "flow": params.get("flow", ""),
                    "tls": params.get("security", "") in ("tls", "reality"),
                    "sni": params.get("sni", ""), "insecure": params.get("allowInsecure", "0") == "1",
                    "network": ptype,
                    "ws_opts": {"path": params.get("path", "/"), "headers": {"Host": params.get("host", "")}} if ptype == "ws" else None,
                    "grpc_opts": {"grpc-service-name": params.get("serviceName", "")} if ptype == "grpc" else None,
                    "reality_opts": {"public-key": params.get("pbk", ""), "short-id": params.get("sid", "")} if params.get("security") == "reality" else None,
                    "client_fingerprint": params.get("fp", ""),
                })
            elif scheme == "trojan":
                password, _, rest = body.partition("@")
                server_port = rest.split("/")[0].split("?")[0]
                server, _, port = server_port.rpartition(":")
                querypart = rest.split("?", 1)[-1] if "?" in rest else ""
                params = dict(urllib.parse.parse_qsl(querypart))
                ptype = params.get("type", "")
                nodes.append({
                    "type": "trojan", "name": name,
                    "server": server, "port": int(port),
                    "password": password,
                    "sni": params.get("sni", server), "insecure": params.get("allowInsecure", "0") == "1",
                    "network": ptype,
                    "ws_opts": {"path": params.get("path", "/"), "headers": {"Host": params.get("host", "")}} if ptype == "ws" else None,
                    "grpc_opts": {"grpc-service-name": params.get("serviceName", "")} if ptype == "grpc" else None,
                })
            elif scheme == "ss":
                # ss://base64(method:password)@server:port or ss://base64#name
                if "@" in body:
                    method_pwd, _, rest = body.partition("@")
                    decoded = base64.b64decode(method_pwd + "==").decode("utf-8", errors="replace")
                    method, _, password = decoded.partition(":")
                    server_port = rest.split("/")[0].split("?")[0]
                    server, _, port = server_port.rpartition(":")
                else:
                    decoded = base64.b64decode(body + "==").decode("utf-8", errors="replace")
                    method, _, rest2 = decoded.partition(":")
                    password, _, server_port = rest2.partition("@")
                    server, _, port = server_port.rpartition(":")
                nodes.append({
                    "type": "ss", "name": name,
                    "server": server, "port": int(port),
                    "cipher": method, "password": password,
                    "plugin": "", "plugin_opts": None,
                })
            elif scheme in ("hysteria2", "hy2"):
                password, _, rest = body.partition("@")
                server_port = rest.split("/")[0].split("?")[0]
                server, _, port = server_port.rpartition(":")
                querypart = rest.split("?", 1)[-1] if "?" in rest else ""
                params = dict(urllib.parse.parse_qsl(querypart))
                nodes.append({
                    "type": "hysteria2", "name": name,
                    "server": server, "port": int(port),
                    "password": password,
                    "sni": params.get("sni", server), "insecure": params.get("insecure", "0") == "1",
                    "obfs": params.get("obfs"), "obfs_password": params.get("obfs-password"),
                })
            elif scheme == "anytls":
                password, _, serverpart = body.partition("@")
                server_port = serverpart.split("/")[0].split("?")[0]
                server, _, port = server_port.rpartition(":")
                querypart = serverpart.split("?", 1)[-1] if "?" in serverpart else ""
                params = dict(urllib.parse.parse_qsl(querypart))
                nodes.append({
                    "type": "anytls", "name": name,
                    "server": server, "port": int(port),
                    "password": password,
                    "sni": params.get("sni", server),
                    "insecure": params.get("allow_insecure", "0") == "1",
                })
        except Exception:
            continue
    return nodes


def parse_clash_proxies(proxies):
    nodes = []
    for p in proxies:
        ptype = p.get("type", "")
        name = p.get("name", "")

        if ptype == "anytls":
            nodes.append({
                "type": "anytls",
                "name": name,
                "server": p["server"],
                "port": p["port"],
                "password": p["password"],
                "sni": p.get("sni", p.get("server-name", p["server"])),
                "insecure": p.get("skip-cert-verify", False),
                "fingerprint": p.get("client-fingerprint", "chrome"),
                "alpn": p.get("alpn"),
            })
        elif ptype == "vmess":
            nodes.append({
                "type": "vmess",
                "name": name,
                "server": p["server"],
                "port": p["port"],
                "uuid": p["uuid"],
                "alter_id": p.get("alterId", 0),
                "cipher": p.get("cipher", "auto"),
                "tls": p.get("tls", False),
                "sni": p.get("servername", ""),
                "insecure": p.get("skip-cert-verify", False),
                "network": p.get("network", ""),
                "ws_opts": p.get("ws-opts"),
                "h2_opts": p.get("h2-opts"),
                "grpc_opts": p.get("grpc-opts"),
            })
        elif ptype == "vless":
            nodes.append({
                "type": "vless",
                "name": name,
                "server": p["server"],
                "port": p["port"],
                "uuid": p["uuid"],
                "flow": p.get("flow", ""),
                "tls": p.get("tls", False),
                "sni": p.get("servername", ""),
                "insecure": p.get("skip-cert-verify", False),
                "network": p.get("network", ""),
                "ws_opts": p.get("ws-opts"),
                "grpc_opts": p.get("grpc-opts"),
                "reality_opts": p.get("reality-opts"),
                "client_fingerprint": p.get("client-fingerprint", ""),
            })
        elif ptype == "trojan":
            nodes.append({
                "type": "trojan",
                "name": name,
                "server": p["server"],
                "port": p["port"],
                "password": p["password"],
                "sni": p.get("sni", ""),
                "insecure": p.get("skip-cert-verify", False),
                "network": p.get("network", ""),
                "ws_opts": p.get("ws-opts"),
                "grpc_opts": p.get("grpc-opts"),
            })
        elif ptype == "ss":
            nodes.append({
                "type": "ss",
                "name": name,
                "server": p["server"],
                "port": p["port"],
                "cipher": p["cipher"],
                "password": p["password"],
                "plugin": p.get("plugin", ""),
                "plugin_opts": p.get("plugin-opts"),
            })
        elif ptype == "ssr":
            nodes.append({
                "type": "ssr",
                "name": name,
                "server": p["server"],
                "port": p["port"],
                "cipher": p["cipher"],
                "password": p["password"],
                "protocol": p.get("protocol", ""),
                "protocol_param": p.get("protocol-param", ""),
                "obfs": p.get("obfs", ""),
                "obfs_param": p.get("obfs-param", ""),
            })
        elif ptype == "hysteria2" or ptype == "hy2":
            nodes.append({
                "type": "hysteria2",
                "name": name,
                "server": p["server"],
                "port": p.get("port") or p.get("ports", 443),
                "password": p.get("password", p.get("auth", "")),
                "sni": p.get("sni", ""),
                "insecure": p.get("skip-cert-verify", False),
                "obfs": p.get("obfs"),
                "obfs_password": p.get("obfs-password"),
            })
    return nodes


def to_singbox_outbound(node):
    ntype = node["type"]
    tag = node["name"]

    if ntype == "_raw_singbox":
        return dict(node["_raw"])

    if ntype == "anytls":
        ob = {
            "type": "anytls",
            "tag": tag,
            "server": node["server"],
            "server_port": node["port"],
            "password": node["password"],
            "min_idle_session": 2,
            "tls": {
                "enabled": True,
                "server_name": node["sni"],
                "insecure": node["insecure"],
                "utls": {"enabled": True, "fingerprint": "chrome"},
            },
        }
        return ob

    if ntype == "vmess":
        ob = {
            "type": "vmess",
            "tag": tag,
            "server": node["server"],
            "server_port": node["port"],
            "uuid": node["uuid"],
            "alter_id": node["alter_id"],
            "security": node["cipher"],
        }
        if node["tls"]:
            ob["tls"] = {
                "enabled": True,
                "server_name": node["sni"],
                "insecure": node["insecure"],
                "utls": {"enabled": True, "fingerprint": "chrome"},
            }
        if node["network"] == "ws" and node["ws_opts"]:
            wo = node["ws_opts"]
            transport = {"type": "ws"}
            if "path" in wo:
                transport["path"] = wo["path"]
            if "headers" in wo:
                transport["headers"] = wo["headers"]
            ob["transport"] = transport
        elif node["network"] == "grpc" and node["grpc_opts"]:
            ob["transport"] = {"type": "grpc", "service_name": node["grpc_opts"].get("grpc-service-name", "")}
        return ob

    if ntype == "vless":
        ob = {
            "type": "vless",
            "tag": tag,
            "server": node["server"],
            "server_port": node["port"],
            "uuid": node["uuid"],
        }
        if node["flow"]:
            ob["flow"] = node["flow"]
        if node["tls"]:
            ob["tls"] = {
                "enabled": True,
                "server_name": node["sni"],
                "insecure": node["insecure"],
                "utls": {"enabled": True, "fingerprint": node["client_fingerprint"] or "chrome"},
            }
        if node.get("reality_opts"):
            ob.setdefault("tls", {})["reality"] = {
                "enabled": True,
                "public_key": node["reality_opts"].get("public-key", ""),
                "short_id": node["reality_opts"].get("short-id", ""),
            }
        if node["network"] == "ws" and node["ws_opts"]:
            wo = node["ws_opts"]
            transport = {"type": "ws"}
            if "path" in wo:
                transport["path"] = wo["path"]
            if "headers" in wo:
                transport["headers"] = wo["headers"]
            ob["transport"] = transport
        elif node["network"] == "grpc" and node["grpc_opts"]:
            ob["transport"] = {"type": "grpc", "service_name": node["grpc_opts"].get("grpc-service-name", "")}
        return ob

    if ntype == "trojan":
        ob = {
            "type": "trojan",
            "tag": tag,
            "server": node["server"],
            "server_port": node["port"],
            "password": node["password"],
            "tls": {
                "enabled": True,
                "server_name": node["sni"],
                "insecure": node["insecure"],
                "utls": {"enabled": True, "fingerprint": "chrome"},
            },
        }
        if node["network"] == "ws" and node["ws_opts"]:
            wo = node["ws_opts"]
            transport = {"type": "ws"}
            if "path" in wo:
                transport["path"] = wo["path"]
            if "headers" in wo:
                transport["headers"] = wo["headers"]
            ob["transport"] = transport
        elif node["network"] == "grpc" and node["grpc_opts"]:
            ob["transport"] = {"type": "grpc", "service_name": node["grpc_opts"].get("grpc-service-name", "")}
        return ob

    if ntype == "ss":
        ob = {
            "type": "shadowsocks",
            "tag": tag,
            "server": node["server"],
            "server_port": node["port"],
            "method": node["cipher"],
            "password": node["password"],
        }
        if node["plugin"] == "obfs" and node["plugin_opts"]:
            opts = node["plugin_opts"]
            ob["plugin"] = "obfs-local"
            ob["plugin_opts"] = opts
        return ob

    if ntype == "hysteria2":
        ob = {
            "type": "hysteria2",
            "tag": tag,
            "server": node["server"],
            "server_port": node["port"],
            "password": node["password"],
        }
        if node["sni"]:
            ob["tls"] = {
                "enabled": True,
                "server_name": node["sni"],
                "insecure": node["insecure"],
            }
        if node.get("obfs"):
            ob["obfs"] = {"type": node["obfs"], "password": node.get("obfs_password", "")}
        return ob

    return None


def fetch_subscription(url):
    import subprocess
    r = subprocess.run(
        ["curl", "-sS", "-k", "--max-time", "30",
         "-H", "User-Agent: ClashMetaForAndroid/2.10.1.Meta Mihomo/1.18",
         url],
        capture_output=True, text=True, timeout=60,
    )
    if r.returncode != 0:
        raise RuntimeError(f"curl failed ({r.returncode}): {r.stderr.strip()}")
    return r.stdout


SINGBOX_PROXY_TYPES = frozenset({
    "vless", "vmess", "trojan", "shadowsocks", "shadow-tls",
    "hysteria", "hysteria2", "anytls", "tuic", "wireguard",
    "naive", "http", "socks",
})


def parse_singbox_json(content):
    """Parse sing-box native JSON: {"outbounds": [...]} or bare array of outbound objects."""
    try:
        data = json.loads(content)
    except (json.JSONDecodeError, ValueError):
        return None

    outbounds = []
    if isinstance(data, dict):
        outbounds = data.get("outbounds", [])
    elif isinstance(data, list):
        outbounds = data

    if not outbounds or not isinstance(outbounds[0], dict):
        return None

    # Validate: at least one entry must be a known sing-box proxy type
    proxy_outbounds = [ob for ob in outbounds
                       if isinstance(ob, dict) and ob.get("type") in SINGBOX_PROXY_TYPES]
    if not proxy_outbounds:
        return None

    nodes = []
    for ob in proxy_outbounds:
        nodes.append({
            "type": "_raw_singbox",
            "name": ob.get("tag", ob.get("server", "unknown")),
            "_raw": ob,
        })
    return nodes


def parse_sip008(content):
    """Parse SIP008 JSON: {"servers": [{server, server_port, method, password, ...}]}."""
    try:
        data = json.loads(content)
    except (json.JSONDecodeError, ValueError):
        return None

    if not isinstance(data, dict):
        return None
    servers = data.get("servers", [])
    if not servers or not isinstance(servers[0], dict):
        return None

    # Validate SIP008 fields
    required = {"server", "method", "password"}
    if not all(k in servers[0] for k in required):
        return None

    nodes = []
    for s in servers:
        nodes.append({
            "type": "ss",
            "name": s.get("remarks", s.get("server", "unknown")),
            "server": s["server"],
            "port": s.get("server_port", s.get("port", 0)),
            "cipher": s["method"],
            "password": s["password"],
            "plugin": s.get("plugin", ""),
            "plugin_opts": s.get("plugin_opts"),
        })
    return nodes


def parse_subscription(content):
    content = content.strip()

    # 1. Sing-box JSON (fast, deterministic)
    nodes = parse_singbox_json(content)
    if nodes is not None:
        print(f"detected format: sing-box JSON ({len(nodes)} nodes)", file=sys.stderr)
        return nodes

    # 2. SIP008 JSON (Shadowsocks standard)
    nodes = parse_sip008(content)
    if nodes is not None:
        print(f"detected format: SIP008 JSON ({len(nodes)} nodes)", file=sys.stderr)
        return nodes

    # 3. Clash/Mihomo YAML
    if yaml:
        try:
            data = yaml.safe_load(content)
            if isinstance(data, dict) and "proxies" in data:
                nodes = parse_clash_proxies(data["proxies"])
                print(f"detected format: Clash YAML ({len(nodes)} nodes)", file=sys.stderr)
                return nodes
        except Exception:
            pass

    # 4. Base64 decode
    schemes = ("anytls://", "vmess://", "vless://", "trojan://", "ss://", "hysteria2://", "hy2://")
    if not any(content.lstrip().startswith(s) for s in schemes) and "mixed-port:" not in content[:200] and "proxies:" not in content[:5000]:
        try:
            decoded = base64.b64decode(content, validate=True).decode("utf-8", errors="replace")
            if any(s in decoded for s in schemes):
                print("detected format: base64-encoded URI links", file=sys.stderr)
                content = decoded
        except Exception:
            pass

    # 5. Plain URI links
    nodes = parse_uri_links(content)
    if nodes:
        print(f"detected format: URI links ({len(nodes)} nodes)", file=sys.stderr)
    return nodes


def build_groups(nodes):
    regions = defaultdict(list)
    ungrouped = []
    for n in nodes:
        r = detect_region(n["name"])
        if r:
            regions[r].append(n)
        else:
            ungrouped.append(n)

    outbounds = []
    region_tags = []
    auto_nodes = []

    # Regional groups
    for r in sorted(regions.keys()):
        rnodes = regions[r]
        rtags = [n["name"] for n in rnodes]
        region_tags.append(r)
        auto_nodes.append(rtags[0])

        if len(rtags) > 1:
            outbounds.append({"type": "selector", "tag": r,
                              "outbounds": [f"{r}-auto"] + rtags, "default": f"{r}-auto"})
            outbounds.append({"type": "urltest", "tag": f"{r}-auto",
                              "outbounds": rtags,
                              "url": "https://www.gstatic.com/generate_204", "interval": "5m"})
        else:
            outbounds.append({"type": "selector", "tag": r, "outbounds": rtags})

    # Ungrouped
    for n in ungrouped:
        region_tags.append(n["name"])
        auto_nodes.append(n["name"])

    return outbounds, region_tags, auto_nodes


INFRA_TAGS = frozenset({
    "VLESS", "VLESS-CDN", "proxy", "auto-proxy", "ai-chain", "auto-ai",
    "warp-ep", "direct", "block",
})


def inject_macos(config, nodes):
    """macOS: subscription nodes connect directly (SS relays only accept CN IPs).
    DNS + route rules ensure server domains resolve via real DNS and go direct."""
    node_outbounds = []
    for n in nodes:
        ob = to_singbox_outbound(n)
        if ob:
            node_outbounds.append(ob)

    if not node_outbounds:
        return config

    groups, region_tags, auto_nodes = build_groups(nodes)

    outbounds = config.get("outbounds", [])
    ai_chain = next((o for o in outbounds if o.get("tag") == "ai-chain"), None)

    direct_idx = next(
        (i for i, o in enumerate(outbounds) if o.get("tag") == "direct"),
        len(outbounds),
    )

    for ob in reversed(node_outbounds):
        outbounds.insert(direct_idx, ob)

    direct_idx = next(
        (i for i, o in enumerate(outbounds) if o.get("tag") == "direct"),
        len(outbounds),
    )
    for g in reversed(groups):
        outbounds.insert(direct_idx, g)

    # Create auto-ai urltest across all regional auto groups
    auto_tags = [f"{r}-auto" for r in region_tags if any(
        o.get("tag") == f"{r}-auto" for o in groups
    )]
    if auto_tags:
        auto_ai_ob = {"type": "urltest", "tag": "auto-ai",
                      "outbounds": auto_tags,
                      "url": "https://www.gstatic.com/generate_204", "interval": "5m"}
        direct_idx = next(
            (i for i, o in enumerate(outbounds) if o.get("tag") == "direct"),
            len(outbounds),
        )
        outbounds.insert(direct_idx, auto_ai_ob)

    if ai_chain:
        ai_chain["outbounds"] = ["VLESS", "VLESS-CDN", "warp-ep"] + (["auto-ai"] if auto_tags else []) + region_tags

    config["outbounds"] = outbounds

    # Collect subscription server domains for DNS and route rules.
    # These must bypass fakeip DNS and route through direct (not proxy).
    sub_domains = set()
    for ob in node_outbounds:
        srv = ob.get("server", "")
        parts = srv.split(".")
        if len(parts) >= 2:
            sub_domains.add(".".join(parts[-2:]))
    if sub_domains:
        dns_rules = config.get("dns", {}).get("rules", [])
        dns_rules.insert(0, {
            "domain_suffix": sorted(sub_domains),
            "server": "dns-domestic",
        })
        config.setdefault("dns", {})["rules"] = dns_rules

    # Add route rules for subscription server domains to go direct.
    # Without this, the SS server connections route through proxy (VLESS) by default.
    route_rules = config.get("route", {}).get("rules", [])
    route_rules.insert(0, {
        "domain_suffix": sorted(sub_domains),
        "outbound": "direct",
    })
    config.setdefault("route", {})["rules"] = route_rules

    return config


def inject_android(config, nodes):
    """Android: original regional group mode. Nodes injected into proxy selector with regional groups."""
    node_outbounds = []
    for n in nodes:
        ob = to_singbox_outbound(n)
        if ob:
            node_outbounds.append(ob)

    if not node_outbounds:
        return config

    groups, region_tags, auto_nodes = build_groups(nodes)

    outbounds = config.get("outbounds", [])
    outbounds = [o for o in outbounds if o.get("tag") != "VLESS"]

    proxy_sel = next((o for o in outbounds if o.get("tag") == "proxy"), None)

    auto_ob = {
        "type": "urltest",
        "tag": "auto",
        "outbounds": auto_nodes,
        "url": "https://www.gstatic.com/generate_204",
        "interval": "5m",
    }
    insert_at = 1
    outbounds.insert(insert_at, auto_ob)

    for g in groups:
        insert_at += 1
        outbounds.insert(insert_at, g)

    direct_idx = next((i for i, o in enumerate(outbounds) if o.get("tag") == "direct"), len(outbounds))
    for ob in reversed(node_outbounds):
        outbounds.insert(direct_idx, ob)

    if proxy_sel:
        proxy_sel["outbounds"] = ["auto"] + region_tags
        proxy_sel["default"] = "auto"

    config["outbounds"] = outbounds
    return config


def inject(config, nodes):
    outbounds = config.get("outbounds", [])
    has_ai_chain = any(o.get("tag") == "ai-chain" for o in outbounds)
    if has_ai_chain:
        return inject_macos(config, nodes)
    return inject_android(config, nodes)


def main():
    parser = argparse.ArgumentParser(description="Inject subscription nodes into sing-box config")
    parser.add_argument("-s", "--sub", help="Subscription URL")
    parser.add_argument("-f", "--file", help="Read subscription from file")
    parser.add_argument("-o", "--output", help="Output file (default: stdout)")
    args = parser.parse_args()

    config = json.load(sys.stdin)

    if not args.sub and not args.file:
        # No subscription, output as-is
        out = json.dumps(config, indent=2, ensure_ascii=False) + "\n"
        if args.output:
            Path(args.output).write_text(out)
        else:
            sys.stdout.write(out)
        return

    if args.file:
        content = Path(args.file).read_text()
    else:
        print(f"fetching subscription...", file=sys.stderr)
        content = fetch_subscription(args.sub)

    nodes = parse_subscription(content)
    info_keywords = ["预计", "等级", "官网", "失联", "客服", "流量", "到期", "重置", "套餐"]
    nodes = [n for n in nodes if not any(kw in n["name"] for kw in info_keywords)]

    if not nodes:
        print("no proxy nodes found in subscription", file=sys.stderr)
        out = json.dumps(config, indent=2, ensure_ascii=False) + "\n"
        if args.output:
            Path(args.output).write_text(out)
        else:
            sys.stdout.write(out)
        return

    print(f"found {len(nodes)} nodes", file=sys.stderr)
    config = inject(config, nodes)
    print(f"injected into config ({len(config['outbounds'])} outbounds)", file=sys.stderr)

    out = json.dumps(config, indent=2, ensure_ascii=False) + "\n"
    if args.output:
        Path(args.output).write_text(out)
        print(f"written to {args.output}", file=sys.stderr)
    else:
        sys.stdout.write(out)


if __name__ == "__main__":
    main()
