# ------------------------------------------------------------------------------
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# ------------------------------------------------------------------------------

source $HOME/.dotfiles/ostype.sh

# Homebrew
if [[ $is_mac_os -eq 1 ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ------------------------------------------------------------------------------
# Below code configures zsh-vi-mode to use system clipboard for yank, paste, change, delete
# https://github.com/jeffreytse/zsh-vi-mode/issues/19
cbyank() {
  if [[ $is_mac_os -eq 1 ]]; then
    xclip -selection primary -i -f | xclip -selection secondary -i -f | xclip -selection clipboard -i
  elif [[ $is_windows -eq 1 ]]; then
    clip
  else
    pbcopy
  fi
}

cbpaste() {
  if [[ $is_mac_os -eq 1 ]]; then
    if   x=$(xclip -o -selection clipboard 2> /dev/null); then
      echo -n $x
    elif x=$(xclip -o -selection primary   2> /dev/null); then
      echo -n $x
    elif x=$(xclip -o -selection secondary 2> /dev/null); then
      echo -n $x
    fi
  elif [[ $is_windows -eq 1 ]]; then
    powershell.exe Get-Clipboard | tr -d '\r'
  else
    pbpaste
  fi
}

my_zvm_vi_yank() {
  zvm_vi_yank
  echo -en "${CUTBUFFER}" | cbyank
}

my_zvm_vi_delete() {
  zvm_vi_delete
  echo -en "${CUTBUFFER}" | cbyank
}

my_zvm_vi_change() {
  zvm_vi_change
  echo -en "${CUTBUFFER}" | cbyank
}

my_zvm_vi_change_eol() {
  zvm_vi_change_eol
  echo -en "${CUTBUFFER}" | cbyank
}

my_zvm_vi_put_after() {
  CUTBUFFER=$(cbpaste)
  zvm_vi_put_after
  zvm_highlight clear # zvm_vi_put_after introduces weird highlighting
}

my_zvm_vi_put_before() {
  CUTBUFFER=$(cbpaste)
  zvm_vi_put_before
  zvm_highlight clear # zvm_vi_put_before introduces weird highlighting
}

zvm_after_lazy_keybindings() {
  zvm_define_widget my_zvm_vi_yank
  zvm_define_widget my_zvm_vi_delete
  zvm_define_widget my_zvm_vi_change
  zvm_define_widget my_zvm_vi_change_eol
  zvm_define_widget my_zvm_vi_put_after
  zvm_define_widget my_zvm_vi_put_before

  zvm_bindkey visual 'y' my_zvm_vi_yank
  zvm_bindkey visual 'd' my_zvm_vi_delete
  zvm_bindkey visual 'x' my_zvm_vi_delete
  zvm_bindkey vicmd  'C' my_zvm_vi_change_eol
  zvm_bindkey visual 'c' my_zvm_vi_change
  zvm_bindkey vicmd  'p' my_zvm_vi_put_after
  zvm_bindkey vicmd  'P' my_zvm_vi_put_before
}
# ------------------------------------------------------------------------------

# Set config directory
export XDG_CONFIG_HOME="$HOME/.config"

# Neovim
# https://github.com/curbol/kickstart.nvim
alias vim='nvim'

# Go
export GOPATH=~/go
export PATH=$PATH:$GOPATH/bin

# andromeda stuff
export GOPRIVATE=github.com/getnacelle/*
alias gotidy='go mod tidy && go mod vendor'
alias gobuild='go build ./...'
alias gobuilde2e='go build -tags e2e ./...'

# nacelle stuff
export PATH="$HOME/code/nacelle-dev-tools/bin:$PATH"
export NPM_TOKEN=
alias awsdev='export AWS_REGION=us-east-2 && aws-vault exec platform-development -- bash -c "rm -rf ~/.kube/* && aws eks update-kubeconfig --name nacelle-development-shared-infra-cluster --region us-east-2 && zsh"'
alias awsprod='export AWS_REGION=us-east-2 && aws-vault exec platform-production -- bash -c "rm -rf ~/.kube/* && aws eks update-kubeconfig --name nacelle-production-shared-infra-cluster --region us-east-2 && zsh"'
alias awsprodwest='export AWS_REGION=us-west-1 && aws-vault exec platform-production-west -- bash -c "rm -rf ~/.kube/* && aws eks update-kubeconfig --name nacelle-production-west-shared-infra-cluster --region us-west-1 && zsh"'
alias awsprod-legacy='export AWS_REGION=us-east-1 && aws-vault exec nacelle-master --no-session --duration=1h -- zsh'
alias kdilithium='kubectl -n dilithium'
alias khailfrequency='kubectl -n hail-frequency'
alias kadmin='kubectl -n admin'
alias kshopifyconnector='kubectl -n shopify-connector'
alias kcontentfulconnector='kubectl -n contentful-connector'
alias knativedata='kubectl -n native-data'
alias ksanityconnector='kubectl -n sanity-connector'
alias kpreviewdata='kubectl -n preview-data'
alias ktricorder='kubectl -n tricorder'
alias ksalesforce='kubectl -n salesforce-connector'
alias kcomlink='kubectl -n comlink'
alias knoms='kubectl -n noms'
alias kschema='kubectl -n schema'
alias kprogresstracking='kubectl -n progress-tracking'
alias kgenesis='kubectl -n genesis'

# Fuzzy finder: https://github.com/junegunn/fzf
eval "$(fzf --zsh)"

# Attach to existing tmux session or create a new one
tm() {
    if [[ $# -eq 0 ]]; then
        # No argument given, attach to the most recent session or create a new one
        tmux attach || tmux new
    else
        # Argument given, use it as the session name
        local session_name="$1"
        tmux attach -t $session_name || tmux new -s $session_name
    fi
}

# ------------------------------------------------------------------------------
# Added by Powerlevel10k
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# Git status symbols: https://github.com/romkatv/powerlevel10k/blob/master/README.md#what-do-different-symbols-in-git-status-mean
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# oh-my-zsh
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(jump)
# Custom plugins:
plugins+=(zsh-vi-mode)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi
# ------------------------------------------------------------------------------
