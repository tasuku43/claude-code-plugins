#!/usr/bin/env bash
# Phase A inventory for the audit-context-cost command.
# Emits JSON to stdout. Counts and metadata only — no log bodies, no skill bodies.
#
# Env:
#   CLAUDE_HOME   default: $HOME/.claude
#   RECENT_N      default: 5    (number of recent projects to inspect for logs)
#   TOP_LOGS      default: 3    (largest log files per project)

set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
RECENT_N="${RECENT_N:-5}"
TOP_LOGS="${TOP_LOGS:-3}"

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

decode_project_path() {
  printf '/%s' "$1" | sed -e 's#^/-#/#' -e 's#-#/#g'
}

read_settings() {
  local f="$CLAUDE_HOME/settings.json"
  if [[ -f "$f" ]]; then cat "$f"; else echo '{}'; fi
}

count_files() {
  local dir="$1" pattern="$2"
  [[ -d "$dir" ]] || { echo 0; return; }
  find "$dir" -type f -name "$pattern" 2>/dev/null | wc -l | tr -d ' '
}

mtime_epoch() {
  stat -f '%m' "$1" 2>/dev/null || stat -c '%Y' "$1" 2>/dev/null || echo 0
}

settings=$(read_settings)

# --- Enabled plugin inventory ---
enabled_plugins_list=$(jq -r '(.enabledPlugins // {}) | to_entries[] | select(.value == true) | .key' <<<"$settings")

plugin_inventory='[]'
plugins_cache="$CLAUDE_HOME/plugins/cache"
if [[ -n "$enabled_plugins_list" && -d "$plugins_cache" ]]; then
  # Build lookup of all installed plugin roots by reading their plugin.json
  plugin_manifests=$(find "$plugins_cache" -maxdepth 8 -type f -path "*/.claude-plugin/plugin.json" 2>/dev/null || true)
  plugin_inventory=$(
    while IFS= read -r raw_name; do
      [[ -z "$raw_name" ]] && continue
      plugin_name="${raw_name%@*}"
      plugin_root=""
      while IFS= read -r pj; do
        [[ -z "$pj" ]] && continue
        name_in_json=$(jq -r '.name // ""' "$pj" 2>/dev/null || true)
        if [[ "$name_in_json" == "$plugin_name" ]]; then
          plugin_root=$(dirname "$(dirname "$pj")")
          break
        fi
      done <<<"$plugin_manifests"
      if [[ -z "$plugin_root" ]]; then
        jq -n --arg n "$raw_name" '{name: $n, found: false, skills: 0, commands: 0, agents: 0}'
        continue
      fi
      sc=$(count_files "$plugin_root/skills" "SKILL.md")
      cc=$(count_files "$plugin_root/commands" "*.md")
      ac=$(count_files "$plugin_root/agents" "*.md")
      jq -n \
        --arg name "$raw_name" --arg path "$plugin_root" \
        --argjson sc "$sc" --argjson cc "$cc" --argjson ac "$ac" \
        '{name: $name, path: $path, found: true, skills: $sc, commands: $cc, agents: $ac}'
    done <<<"$enabled_plugins_list" | jq -s '.'
  )
fi

# --- Custom (non-plugin) assets ---
custom=$(jq -n \
  --argjson gs "$(count_files "$CLAUDE_HOME/skills" SKILL.md)" \
  --argjson gc "$(count_files "$CLAUDE_HOME/commands" '*.md')" \
  --argjson ga "$(count_files "$CLAUDE_HOME/agents" '*.md')" \
  '{
    skills_global: $gs,
    commands_global: $gc,
    agents_global: $ga
  }')

# --- MCP servers ---
mcp=$(jq '{
  servers: ((.mcpServers // {}) | keys),
  count:   ((.mcpServers // {}) | length)
}' <<<"$settings")

# --- SessionStart hook commands ---
session_start_hooks=$(jq '[
  ((.hooks.SessionStart // [])[] | .hooks[]? | (.command // ""))
]' <<<"$settings")

# --- Recent project log metadata ---
recent_logs='[]'
projects_dir="$CLAUDE_HOME/projects"
if [[ -d "$projects_dir" ]]; then
  recent_logs=$(
    ls -1t "$projects_dir" 2>/dev/null | head -n "$RECENT_N" | while read -r enc; do
      decoded=$(decode_project_path "$enc")
      project_log_dir="$projects_dir/$enc"
      logs_json='[]'
      if [[ -d "$project_log_dir" ]]; then
        top_files=$(
          find "$project_log_dir" -maxdepth 1 -type f -name "*.jsonl" 2>/dev/null | while read -r lf; do
            size=$(wc -c <"$lf" 2>/dev/null | tr -d ' ')
            mt=$(mtime_epoch "$lf")
            printf '%s|%s|%s\n' "${size:-0}" "${mt:-0}" "$lf"
          done | sort -t'|' -k1 -nr | head -n "$TOP_LOGS" || true
        )
        if [[ -n "$top_files" ]]; then
          logs_json=$(
            printf '%s\n' "$top_files" | while IFS='|' read -r size mt path; do
              [[ -z "$path" ]] && continue
              jq -n --arg path "$path" \
                --argjson size "${size:-0}" --argjson mt "${mt:-0}" \
                '{path: $path, size_bytes: $size, mtime_epoch: $mt}'
            done | jq -s '.'
          )
        fi
      fi
      jq -n \
        --arg project "$decoded" --arg encoded "$enc" \
        --argjson logs "$logs_json" \
        '{project: $project, encoded: $encoded, top_logs: $logs}'
    done | jq -s '.'
  )
fi

jq -n \
  --argjson plugins "$plugin_inventory" \
  --argjson custom "$custom" \
  --argjson mcp "$mcp" \
  --argjson ssh "$session_start_hooks" \
  --argjson logs "$recent_logs" \
  '{
    enabled_plugins: $plugins,
    custom: $custom,
    mcp: $mcp,
    session_start_hooks: $ssh,
    recent_log_metadata: $logs
  }'
