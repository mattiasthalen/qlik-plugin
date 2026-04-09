#!/bin/bash
set -e

gh auth login -h github.com -s admin:ssh_signing_key
gh auth setup-git

# Set git identity from GitHub
GH_USER=$(gh api user --jq '.name')
GH_EMAIL=$(gh api user --jq '.email')
git config --global user.name "$GH_USER"
git config --global user.email "$GH_EMAIL"

ssh-keygen -t ed25519 -C "$(git config --global user.email)" -N "" -f ~/.ssh/id_ed25519_signing
gh ssh-key add ~/.ssh/id_ed25519_signing.pub --type signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519_signing.pub
git config --global commit.gpgsign true

echo "GitHub auth and commit signing configured"
