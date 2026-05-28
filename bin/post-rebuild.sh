#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Install skills for AI coding agents
bunx skills add "$DOTFILES_DIR/skills" -g --agent claude-code codex -y
bunx skills add https://github.com/anthropics/skills/tree/main/skills --skill webapp-testing -g --agent claude-code codex -y
bunx skills add https://github.com/mattpocock/skills/tree/main/skills --skill grill-me prototype -g --agent claude-code codex -y
bunx skills add https://github.com/Leonxlnx/taste-skill/tree/main/skills --skill design-taste-frontend -g --agent claude-code codex -y

# Sync AGENTS.md to all agent config locations
agents_src="$DOTFILES_DIR/workflows/base/AGENTS.md"
targets=(
  "$HOME/.claude/CLAUDE.md"
  "$HOME/.agents/AGENTS.md"
)

for target in "${targets[@]}"; do
  mkdir -p "$(dirname "$target")"
  cp "$agents_src" "$target"
done

# Sync per-project agent docs: AGENTS.md is the synced file, CLAUDE.md is a symlink to it.
sync_project_agents() {
  local src="$1" project_dir="$2"
  [ -d "$project_dir" ] || return 0
  cp "$src" "$project_dir/AGENTS.md"
  ln -sfn AGENTS.md "$project_dir/CLAUDE.md"
}

sync_project_agents \
  "$DOTFILES_DIR/workflows/agent-sandbox/AGENTS.md" \
  "$HOME/Projects/agent-sandbox"
