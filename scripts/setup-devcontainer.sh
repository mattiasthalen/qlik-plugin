#!/bin/bash
set -e

lefthook install

# Install qlik-cli for integration testing
if ! command -v qlik &> /dev/null; then
  echo "Installing qlik-cli..."
  curl -sL https://github.com/qlik-oss/qlik-cli/releases/latest/download/qlik-Linux-x86_64.tar.gz | sudo tar xz -C /usr/local/bin qlik
  echo "qlik-cli installed: $(qlik version)"
fi

# Install qs for syncing Qlik apps
if ! command -v qs &> /dev/null; then
  echo "Installing qs..."
  curl -sL https://github.com/mattiasthalen/qlik-sync/releases/latest/download/qs-Linux-x86_64.tar.gz | sudo tar xz -C /usr/local/bin qs
  echo "qs installed: $(qs version)"
fi

# Verify jq is available (installed by base devcontainer image)
if ! command -v jq &> /dev/null; then
  echo "Installing jq..."
  sudo apt-get update -qq && sudo apt-get install -y -qq jq
  echo "jq installed: $(jq --version)"
fi
