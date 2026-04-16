#!/usr/bin/env bash
# Phase A inventory for the audit-config-placement command.
# Emits JSON to stdout. Minimum viable fetch per target:
#   CLAUDE.md : path, line_count, headings (H1/H2 only)
#   rules     : path, line_count
#   skill     : path, name, description (first line only), line_count,
#               has_do_not_use_for, reference_mentions
#   command   : path, name, description (first line only), line_count
#   agent     : path, name, description (first line only), line_count
#
# Env:
#   CLAUDE_HOME   default: $HOME/.claude
#   RECENT_N      default: 5

set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
RECENT_N="${RECENT_N:-5}"

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 2; }

decode_project_path() {
  printf '/%s' "$1" | sed -e 's#^/-#/#' -e 's#-#/#g'
}

# Extract the first value of a single frontmatter field.
# Handles: "field: value", "field: >", "field: |", "field: >-", "field: |-"
# For block scalars, concatenates indented continuation lines (space-joined).
# Stops on next top-level YAML key or closing "---".
extract_fm_field() {
  local field="$1" file="$2"
  awk -v field="$field" '
    BEGIN { state=0 } # 0=pre, 1=in-fm, 2=in-block
    /^---[[:space:]]*$/ {
      if (state == 0) { state=1; next }
      else if (state == 1 || state == 2) {
        if (state == 2) print buf
        exit
      }
    }
    state == 1 {
      pat = "^" field ":"
      if ($0 ~ pat) {
        val = $0
        sub(pat "[[:space:]]*", "", val)
        if (val ~ /^[>|][-+]?[[:space:]]*$/) {
          state=2; buf=""
          next
        }
        print val
        exit
      }
    }
    state == 2 {
      if ($0 ~ /^[A-Za-z_][A-Za-z0-9_-]*:/) {
        print buf
        exit
      }
      line=$0
      sub(/^[[:space:]]+/, "", line)
      if (line == "") next
      buf = (buf == "") ? line : buf " " line
    }
  ' "$file"
}

inventory_claude_md() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    jq -n '{exists: false}'
    return
  fi
  local lines headings
  lines=$(awk 'END{print NR+0}' "$f")
  headings=$(awk '/^#{1,2} / {print}' "$f" | jq -R . | jq -s '.')
  jq -n --arg path "$f" --argjson lines "$lines" --argjson headings "$headings" \
    '{exists: true, path: $path, line_count: $lines, headings: $headings}'
}

inventory_rules_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || { echo '[]'; return; }
  find "$dir" -maxdepth 3 -type f -name "*.md" 2>/dev/null | while read -r f; do
    local lines
    lines=$(awk 'END{print NR+0}' "$f")
    jq -n --arg path "$f" --argjson lines "$lines" \
      '{path: $path, line_count: $lines}'
  done | jq -s '.'
}

inventory_skills_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || { echo '[]'; return; }
  {
    find "$dir" -mindepth 2 -maxdepth 4 -type f -name "SKILL.md" 2>/dev/null
    find "$dir" -mindepth 1 -maxdepth 1 -type f -name "*.md" 2>/dev/null
  } | sort -u | while read -r f; do
    local lines name desc has_not refs
    lines=$(awk 'END{print NR+0}' "$f")
    name=$(extract_fm_field name "$f")
    desc=$(extract_fm_field description "$f")
    if [[ -z "$name" ]]; then
      if [[ "$(basename "$f")" == "SKILL.md" ]]; then
        name=$(basename "$(dirname "$f")")
      else
        name=$(basename "$f" .md)
      fi
    fi
    if grep -qiE 'do NOT use' "$f"; then has_not=true; else has_not=false; fi
    refs=$(grep -cE '(references/|@[A-Za-z])' "$f" 2>/dev/null || true)
    refs=${refs:-0}
    jq -n \
      --arg path "$f" --arg name "$name" --arg desc "$desc" \
      --argjson lines "$lines" --argjson has_not "$has_not" --argjson refs "${refs:-0}" \
      '{
        path: $path, name: $name, description: $desc,
        line_count: $lines,
        has_do_not_use_for: $has_not,
        reference_mentions: $refs
      }'
  done | jq -s '.'
}

inventory_commands_or_agents_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || { echo '[]'; return; }
  find "$dir" -maxdepth 3 -type f -name "*.md" 2>/dev/null | while read -r f; do
    local lines name desc
    lines=$(awk 'END{print NR+0}' "$f")
    name=$(extract_fm_field name "$f")
    desc=$(extract_fm_field description "$f")
    [[ -z "$name" ]] && name=$(basename "$f" .md)
    jq -n \
      --arg path "$f" --arg name "$name" --arg desc "$desc" \
      --argjson lines "$lines" \
      '{path: $path, name: $name, description: $desc, line_count: $lines}'
  done | jq -s '.'
}

# --- Global ---
global_claude=$(inventory_claude_md "$CLAUDE_HOME/CLAUDE.md")
global_rules=$(inventory_rules_dir "$CLAUDE_HOME/rules")
global_skills=$(inventory_skills_dir "$CLAUDE_HOME/skills")
global_commands=$(inventory_commands_or_agents_dir "$CLAUDE_HOME/commands")
global_agents=$(inventory_commands_or_agents_dir "$CLAUDE_HOME/agents")

# --- Recent projects ---
recent_projects='[]'
if [[ -d "$CLAUDE_HOME/projects" ]]; then
  recent_projects=$(
    ls -1t "$CLAUDE_HOME/projects" 2>/dev/null | head -n "$RECENT_N" | while read -r enc; do
      decoded=$(decode_project_path "$enc")
      claude=$(inventory_claude_md "$decoded/CLAUDE.md")
      rules=$(inventory_rules_dir "$decoded/.claude/rules")
      skills=$(inventory_skills_dir "$decoded/.claude/skills")
      commands=$(inventory_commands_or_agents_dir "$decoded/.claude/commands")
      agents=$(inventory_commands_or_agents_dir "$decoded/.claude/agents")
      jq -n \
        --arg path "$decoded" --arg encoded "$enc" \
        --argjson claude "$claude" \
        --argjson rules "$rules" \
        --argjson skills "$skills" \
        --argjson commands "$commands" \
        --argjson agents "$agents" \
        '{
          path: $path, encoded: $encoded,
          claude_md: $claude,
          rules: $rules,
          skills: $skills,
          commands: $commands,
          agents: $agents
        }'
    done | jq -s '.'
  )
fi

jq -n \
  --argjson global_claude "$global_claude" \
  --argjson global_rules "$global_rules" \
  --argjson global_skills "$global_skills" \
  --argjson global_commands "$global_commands" \
  --argjson global_agents "$global_agents" \
  --argjson recent_projects "$recent_projects" \
  '{
    global: {
      claude_md: $global_claude,
      rules: $global_rules,
      skills: $global_skills,
      commands: $global_commands,
      agents: $global_agents
    },
    recent_projects: $recent_projects
  }'
