#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Install skills for AI coding agents
bunx skills add "$DOTFILES_DIR/skills" -g --agent claude-code codex -y
bunx skills add https://github.com/anthropics/skills/tree/main/skills --skill webapp-testing frontend-design -g --agent claude-code codex -y
bunx skills add https://github.com/mattpocock/skills/tree/main/skills --skill grill-me prototype -g --agent claude-code codex -y

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
