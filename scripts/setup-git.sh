#!/bin/bash
set -e

gh auth login
gh auth setup-git

ssh-keygen -t ed25519 -C "$(git config --global user.email)" -N "" -f ~/.ssh/id_ed25519_signing
gh ssh-key add ~/.ssh/id_ed25519_signing.pub --type signing
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519_signing.pub
git config --global commit.gpgsign true

echo "GitHub auth and commit signing configured"
