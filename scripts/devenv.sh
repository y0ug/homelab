#!/usr/bin/env zsh

[[ -f ~/.config/zsh/functions.zsh ]] && source ~/.config/zsh/functions.zsh

load_env llm
nix develop
scripts/secrets.activate
tmux new-session -As homelab
