# zmodload zsh/zprof

# ------------------------------------------------------------------------------
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# ------------------------------------------------------------------------------

source $HOME/.dotfiles/scripts/ostype.sh
source $HOME/.dotfiles/scripts/jump.sh

# Homebrew
if [[ $is_mac_intel -eq 1 ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
if [[ $is_mac_arm -eq 1 ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Completions
# example: appcfg completion zsh > ~/.zsh/completions/_appcfg
autoload -U compinit;
mkdir -p ~/.zsh/completions
fpath+=(~/.zsh/completions)
compinit -C

# ------------------------------------------------------------------------------
# Below code configures zsh-vi-mode to use system clipboard for yank, paste, change, delete
# https://github.com/jeffreytse/zsh-vi-mode/issues/19
cbyank() {
  if [[ $is_mac_os -eq 1 ]]; then
    pbcopy
  elif [[ $is_windows -eq 1 ]]; then
    clip
  else
    xclip -selection clipboard
  fi
}

cbpaste() {
  if [[ $is_mac_os -eq 1 ]]; then
    pbpaste
  elif [[ $is_windows -eq 1 ]]; then
    powershell.exe Get-Clipboard | tr -d '\r'
  else
    xclip -o -selection clipboard
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

my_zvm_vi_substitute() {
  zvm_vi_substitute
  echo -en "${CUTBUFFER}" | cbyank
}

my_zvm_vi_substitute_whole_line() {
  zvm_vi_substitute_whole_line
  echo -en "${CUTBUFFER}" | cbyank
}

my_zvm_vi_replace_selection() {
  CUTBUFFER=$(cbpaste)
  zvm_vi_replace_selection
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
  zvm_define_widget my_zvm_vi_substitute
  zvm_define_widget my_zvm_vi_substitute_whole_line
  zvm_define_widget my_zvm_vi_replace_selection

  zvm_bindkey vicmd 'C' my_zvm_vi_change_eol
  zvm_bindkey vicmd 'P' my_zvm_vi_put_before
  zvm_bindkey vicmd 'S' my_zvm_vi_substitute_whole_line
  zvm_bindkey vicmd 'p' my_zvm_vi_put_after

  zvm_bindkey visual 'p' my_zvm_vi_replace_selection
  zvm_bindkey visual 'c' my_zvm_vi_change
  zvm_bindkey visual 'd' my_zvm_vi_delete
  zvm_bindkey visual 's' my_zvm_vi_substitute
  zvm_bindkey visual 'x' my_zvm_vi_delete
  zvm_bindkey visual 'y' my_zvm_vi_yank
}
# ------------------------------------------------------------------------------

# Set config directory
export XDG_CONFIG_HOME="$HOME/.config"

# Neovim
# https://github.com/curbol/kickstart.nvim
alias vim='nvim'

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi

# Go
export GOPATH=~/go
export PATH=$PATH:$GOPATH/bin
alias gotidy='go mod tidy && go mod vendor'

# Python
# brew install pyenv
export PATH="$HOME/.pyenv/shims:$PATH"

# Gladly stuff
export GOPRIVATE=github.com/sagansystems,github.com/gladly
export BUILD_HARNESS_PATH=$HOME/code/build-harness
export DOCKER_COMPOSE_PATH=$HOME/code/docker-compose
export PATH=$PATH:/opt/pact/bin
export PACT_PROVIDER_VERSION=dev_laptop
export PACT_DISABLE_SSL_VERIFICATION=true
alias auth-local='saganadmin localhost:8001'
alias auth-master='saganadmin https://us-master.gladly.qa'
alias auth-staging='saganadmin https://us-staging.gladly.qa'
alias gladmin-local='docker run -it --rm --name gladmin-local-$(openssl rand -hex 4) -v /Users/curtis/Gladly:/host -e GLADLY_DN=localhost -e ORG=example.org -e GLADLY_JWT_TOKEN=$(saganadmin localhost:8001) sagan/gladmin'
alias gladmin-master='docker run -it --rm --name gladmin-master-$(openssl rand -hex 4) -v /Users/curtis/Gladly:/host -e GLADLY_DN=us-master.gladly.qa -e ORG=gladly.com -e GLADLY_JWT_TOKEN=$(saganadmin https://us-master.gladly.qa) sagan/gladmin'
alias gladmin-staging='docker run -it --rm --name gladmin-staging-$(openssl rand -hex 4) -v /Users/curtis/Gladly:/host -e GLADLY_DN=us-staging.gladly.qa -e ORG=gladly.com -e GLADLY_JWT_TOKEN=$(saganadmin https://us-staging.gladly.qa) sagan/gladmin'
alias appcfg-local="go run ~/code/supernova/tools/appcfg"
alias appcfg-local-beta="go run -tags=beta ~/code/supernova/tools/appcfg"

# Fuzzy finder: https://github.com/junegunn/fzf
eval "$(fzf --zsh)"

# ------------------------------------------------------------------------------
# Added by Powerlevel10k
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
# Git status symbols: https://github.com/romkatv/powerlevel10k/blob/master/README.md#what-do-different-symbols-in-git-status-mean
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# zsh-completions
# https://github.com/zsh-users/zsh-completions
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
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
plugins=(zsh-vi-mode)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# ------------------------------------------------------------------------------

# zprof
