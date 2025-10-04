#!/bin/bash
# Append uploaded temporary public key to authorized_keys and secure permissions
mkdir -p "$HOME/.ssh"
if [ -f "$HOME/.ssh/id_ed25519.pub.tmp" ]; then
  cat "$HOME/.ssh/id_ed25519.pub.tmp" >> "$HOME/.ssh/authorized_keys"
  rm -f "$HOME/.ssh/id_ed25519.pub.tmp"
fi
chmod 700 "$HOME/.ssh"
chmod 600 "$HOME/.ssh/authorized_keys"
exit 0
