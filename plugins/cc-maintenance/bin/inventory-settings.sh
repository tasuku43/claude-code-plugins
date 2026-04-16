#!/usr/bin/env bash
# Phase A inventory for the audit-settings command.
# Emits a JSON document to stdout. No file bodies — only metadata and counts.
#
# Env:
#   CLAUDE_HOME   default: $HOME/.claude
#   RECENT_N      default: 5

set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
RECENT_N="${RECENT_N:-5}"

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

decode_project_path() {
  # ~/.claude/projects/-Users-alice-app -> /Users/alice/app
  printf '/%s' "$1" | sed -e 's#^/-#/#' -e 's#-#/#g'
}

read_settings() {
  local f="$CLAUDE_HOME/settings.json"
  if [[ -f "$f" ]]; then cat "$f"; else echo '{}'; fi
}

inventory_hook_scripts() {
  local dir="$CLAUDE_HOME/hooks"
  [[ -d "$dir" ]] || { echo '[]'; return; }
  find "$dir" -maxdepth 2 -type f 2>/dev/null | while read -r f; do
    local lines size
    lines=$(awk 'END{print NR+0}' "$f" 2>/dev/null || echo 0)
    size=$(wc -c <"$f" 2>/dev/null | tr -d ' ')
    jq -n --arg path "$f" --argjson lines "${lines:-0}" --argjson size "${size:-0}" \
      '{path: $path, line_count: $lines, size_bytes: $size}'
  done | jq -s '.'
}

inventory_recent_projects() {
  local dir="$CLAUDE_HOME/projects"
  [[ -d "$dir" ]] || { echo '[]'; return; }
  ls -1t "$dir" 2>/dev/null | head -n "$RECENT_N" | while read -r enc; do
    local decoded local_settings exists allow deny ask
    decoded=$(decode_project_path "$enc")
    local_settings="$decoded/.claude/settings.local.json"
    if [[ -f "$local_settings" ]]; then
      exists=true
      allow=$(jq '(.permissions.allow // []) | length' "$local_settings" 2>/dev/null || echo 0)
      deny=$(jq '(.permissions.deny // []) | length' "$local_settings" 2>/dev/null || echo 0)
      ask=$(jq '(.permissions.ask // []) | length' "$local_settings" 2>/dev/null || echo 0)
    else
      exists=false; allow=0; deny=0; ask=0
    fi
    jq -n \
      --arg path "$decoded" --arg encoded "$enc" \
      --argjson exists "$exists" \
      --argjson allow "$allow" --argjson deny "$deny" --argjson ask "$ask" \
      '{
        path: $path, encoded: $encoded,
        settings_local_exists: $exists,
        permissions: {allow: $allow, deny: $deny, ask: $ask}
      }'
  done | jq -s '.'
}

settings=$(read_settings)

perms=$(jq '{
  allow: (.permissions.allow // []),
  deny:  (.permissions.deny  // []),
  ask:   (.permissions.ask   // []),
  counts: {
    allow: ((.permissions.allow // []) | length),
    deny:  ((.permissions.deny  // []) | length),
    ask:   ((.permissions.ask   // []) | length)
  }
}' <<<"$settings")

hooks=$(jq '[
  (.hooks // {}) | to_entries[] |
  {
    event: .key,
    entries: [ .value[] | {
      matcher: (.matcher // ""),
      commands: [ .hooks[]? | (.command // "") ]
    }]
  }
]' <<<"$settings")

plugins=$(jq '{
  enabled:  [ (.enabledPlugins // {}) | to_entries[] | select(.value == true)  | .key ],
  disabled: [ (.enabledPlugins // {}) | to_entries[] | select(.value == false) | .key ]
}' <<<"$settings")

mcp_servers=$(jq '[
  (.mcpServers // {}) | to_entries[] | {
    name: .key,
    type: (.value.type // "stdio"),
    command: (.value.command // null),
    url: (.value.url // null),
    args_count: ((.value.args // []) | length),
    env_keys: [ (.value.env // {}) | keys[]? ]
  }
]' <<<"$settings")

env_keys=$(jq '[ (.env // {}) | keys[]? ]' <<<"$settings")

hook_scripts=$(inventory_hook_scripts)
recent_projects=$(inventory_recent_projects)

jq -n \
  --arg settings_path "$CLAUDE_HOME/settings.json" \
  --argjson perms "$perms" \
  --argjson hooks "$hooks" \
  --argjson plugins "$plugins" \
  --argjson mcp_servers "$mcp_servers" \
  --argjson env_keys "$env_keys" \
  --argjson hook_scripts "$hook_scripts" \
  --argjson recent_projects "$recent_projects" \
  '{
    settings_global: {
      path: $settings_path,
      permissions: $perms,
      hooks: $hooks,
      plugins: $plugins,
      mcp_servers: $mcp_servers,
      env_keys: $env_keys
    },
    hook_scripts: $hook_scripts,
    recent_projects: $recent_projects
  }'
