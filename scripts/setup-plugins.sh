#!/bin/bash
set -e

echo "Setting up AI agent plugins..."

# --- Claude Code Plugins ---
if command -v claude &> /dev/null; then
  echo "Adding Claude Code plugin marketplaces..."
  claude plugin marketplace add openai/codex-plugin-cc 2>/dev/null || true
  claude plugin marketplace add JuliusBrussee/caveman 2>/dev/null || true
  claude plugin marketplace add obra/superpowers 2>/dev/null || true

  echo "Installing Claude Code plugins..."
  claude plugin install codex@openai-codex 2>/dev/null || true
  claude plugin install caveman@caveman 2>/dev/null || true
  claude plugin install superpowers@superpowers-dev 2>/dev/null || true
else
  echo "Claude Code CLI not found, skipping Claude Code plugins."
fi

# --- Codex Skills ---
echo "Installing Codex skills..."
npx -y skills add JuliusBrussee/caveman -y -a codex 2>/dev/null || true
npx -y skills add obra/superpowers -y -a codex 2>/dev/null || true

echo "Plugin setup complete."
