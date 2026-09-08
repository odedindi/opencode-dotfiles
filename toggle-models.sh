#!/bin/bash
# Toggle between free models and github-copilot models for OpenCode
# Uses the canonical dotfiles-repo branches: `free` (opencode/* models) vs `main` (github-copilot/* models).

CONFIG_DIR="$HOME/.config/opencode"
cd "$CONFIG_DIR" || exit 1

usage() {
  echo "Usage: opencode-models [free|copilot|status]"
  echo ""
  echo "  free     Switch to free models  (git checkout free -- oh-my-openagent.json)"
  echo "  copilot  Switch to github-copilot models (git checkout main -- oh-my-openagent.json)"
  echo "  status   Show current model configuration"
}

switch_to_free() {
  git checkout free -- oh-my-openagent.json 2>/dev/null
  if [ $? -eq 0 ]; then
    echo "✓ Switched to free models"
    echo "  Restart OpenCode to apply changes"
  else
    echo "✗ Failed to switch to free models"
    exit 1
  fi
}

switch_to_copilot() {
  git checkout main -- oh-my-openagent.json 2>/dev/null
  if [ $? -eq 0 ]; then
    echo "✓ Switched to github-copilot models"
    echo "  Restart OpenCode to apply changes"
  else
    echo "✗ Failed to switch to github-copilot models"
    exit 1
  fi
}

show_status() {
  echo "Current model assignments:"
  echo ""
  grep -o '"model": "[^"]*"' oh-my-openagent.json | head -20
}

case "$1" in
  free)
    switch_to_free
    ;;
  copilot)
    switch_to_copilot
    ;;
  status)
    show_status
    ;;
  *)
    usage
    ;;
esac