alias k=kubectl
alias h=helm
alias helmfile=helmfile
alias terraform=tofu
alias tf=tofu

if [[ -n "${ZSH_VERSION}" ]]; then
    SCRIPT_PATH="${(%):-%N}"
elif [[ -n "${BASH_VERSION}" ]]; then
    SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
else
    SCRIPT_PATH="$0"
fi

SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

zfunc_dir="${SCRIPT_DIR}/.zfunctions"

# Define commands and their completion syntax
typeset -a completions
completions=(
  "kubectl completion zsh" "_kubectl"
  "helmfile completion zsh" "_helmfile"
  "scw autocomplete script shell=zsh" "_scw"
)


# Create directory if needed
mkdir -p "$zfunc_dir"

for ((i = 2; i <= ${#completions[@]}; i += 2)); do
  local cmd_str=${completions[$i - 1]}
  local target="$zfunc_dir/${completions[$i]}"
  local cmd=${cmd_str%% *} # Extract first word
  echo $cmd_str, $target, $cmd
  command -v $cmd >/dev/null 2>&1 && [[ ! -f "$target" ]] && eval "$cmd_str" >"$target"
done

fpath+=("$zfunc_dir")

unset zfunc_dir
unset script_dir

autoload -Uz compinit && compinit


