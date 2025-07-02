# zmodload zsh/zprof

# ------------------------------------------------------------------------------
# Starship prompt - https://github.com/starship/starship
eval "$(starship init zsh)"
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load Secrets
if [ -f ~/.config/zsh/.zshrc.local ]; then
  . ~/.config/zsh/.zshrc.local
fi
if [ -n "$GIT_SIGNING_KEY_ID" ]; then # Set GPG signing key in git config if defined
  local_git_config_file="$HOME/.gitconfig.local"
  if [[ ! -f "$local_git_config_file" ]]; then
    touch "$local_git_config_file"
  fi
  current_git_signing_key=$(git config --file "$local_git_config_file" --get user.signingkey 2>/dev/null)
  if [ "$current_git_signing_key" != "$GIT_SIGNING_KEY_ID" ]; then
    git config --file "$local_git_config_file" user.signingkey "$GIT_SIGNING_KEY_ID"
  fi
  git config --file "$local_git_config_file" commit.gpgsign true
fi
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load Scripts
source "$HOME/.dotfiles/scripts/jump.sh"
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Homebrew
export HOMEBREW_AUTO_UPDATE_SECS=86400 # Set Homebrew auto-update interval to 24 hours
if [[ $is_mac_intel -eq 1 ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
if [[ $is_mac_arm -eq 1 ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Go
export GOPATH=~/go
export PATH=$PATH:$GOPATH/bin
alias gotidy='go mod tidy && go mod vendor'
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Neovim
# https://github.com/curbol/kickstart.nvim
alias vim='nvim'

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Mise - https://github.com/jdx/mise
# Examples:
# > mise use -g node@20.12
# > mise use -g python@3.11
eval "$(mise activate zsh)"
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Gladly stuff
export PATH=$PATH:/opt/pact/bin
export PACT_PROVIDER_VERSION=dev_laptop
export PACT_DISABLE_SSL_VERIFICATION=true
export PACT_BROKER_URL=https://pact-broker.tools.gladly.qa
export PACT_BROKER_USERNAME=basic_auth_user_read_only
export GOPRIVATE=github.com/sagansystems,github.com/gladly
export BUILD_HARNESS_PATH=$HOME/code/build-harness
export DOCKER_COMPOSE_PATH=$HOME/code/docker-compose
export APP_PLATFORM_INFRA=true # https://github.com/sagansystems/docker-compose
alias auth-local='saganadmin localhost:8001'
alias auth-master='saganadmin https://us-master.gladly.qa'
alias auth-staging='saganadmin https://us-staging.gladly.qa'
alias gladmin-local='docker run -it --rm --name gladmin-local-$(openssl rand -hex 4) -v /Users/curtis/Gladly:/host -e GLADLY_DN=host.docker.internal -e ORG=example.org -e GLADLY_JWT_TOKEN=$(saganadmin localhost:8001) sagan/gladmin'
alias gladmin-master='docker run -it --rm --name gladmin-master-$(openssl rand -hex 4) -v /Users/curtis/Gladly:/host -e GLADLY_DN=us-master.gladly.qa -e ORG=gladly.com -e GLADLY_JWT_TOKEN=$(saganadmin https://us-master.gladly.qa) sagan/gladmin'
alias gladmin-staging='docker run -it --rm --name gladmin-staging-$(openssl rand -hex 4) -v /Users/curtis/Gladly:/host -e GLADLY_DN=us-staging.gladly.qa -e ORG=gladly.com -e GLADLY_JWT_TOKEN=$(saganadmin https://us-staging.gladly.qa) sagan/gladmin'
alias appcfg-local="go run ~/code/supernova/tools/appcfg"
alias appcfg-local-beta="go run -tags=beta ~/code/supernova/tools/appcfg"
export GLADLY_APP_CFG_HOST="localhost"
export GLADLY_APP_CFG_USER="michelle.smith@example.org"
export GLADLY_APP_CFG_TOKEN="testtoken"
export GLADLY_APP_CFG_ROOT="/Users/curtis/Gladly"
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Below code configures zsh-vi-mode to use system clipboard for yank, paste, change, delete
# https://github.com/jeffreytse/zsh-vi-mode/issues/19
# pbcopy and pbpaste work on all OS because of the "belak/zsh-utils" plugin
cbyank() { pbcopy }
cbpaste() { pbpaste }

# Yank
my_zvm_vi_yank() {
  zvm_vi_yank
  echo -en "${CUTBUFFER}" | cbyank
}

# Put
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
my_zvm_vi_replace_selection() {
  CUTBUFFER=$(cbpaste)
  zvm_vi_replace_selection
  echo -en "${CUTBUFFER}" | cbyank
}

# Change
my_zvm_vi_change() {
  zvm_vi_change
  echo -en "${CUTBUFFER}" | cbyank
}
my_zvm_vi_change_eol() {
  zvm_vi_change_eol
  echo -en "${CUTBUFFER}" | cbyank
}

# Delete
my_zvm_vi_delete() {
  zvm_vi_delete
  echo -en "${CUTBUFFER}" | cbyank
}

# Substitute
my_zvm_vi_substitute() {
  zvm_vi_substitute
  echo -en "${CUTBUFFER}" | cbyank
}
my_zvm_vi_substitute_whole_line() {
  zvm_vi_substitute_whole_line
  echo -en "${CUTBUFFER}" | cbyank
}

zvm_after_lazy_keybindings() {
  # Yank
  zvm_define_widget my_zvm_vi_yank
  zvm_bindkey visual 'y' my_zvm_vi_yank

  # Put
  zvm_define_widget my_zvm_vi_put_after
  zvm_define_widget my_zvm_vi_put_before
  zvm_define_widget my_zvm_vi_replace_selection
  zvm_bindkey vicmd 'P' my_zvm_vi_put_before
  zvm_bindkey vicmd 'p' my_zvm_vi_put_after
  zvm_bindkey visual 'p' my_zvm_vi_replace_selection

  # Change
  zvm_define_widget my_zvm_vi_change
  zvm_define_widget my_zvm_vi_change_eol
  zvm_bindkey visual 'c' my_zvm_vi_change
  zvm_bindkey vicmd 'C' my_zvm_vi_change_eol

  # Delete
  zvm_define_widget my_zvm_vi_delete
  zvm_bindkey visual 'x' my_zvm_vi_delete
  zvm_bindkey visual 'd' my_zvm_vi_delete

  # Substitute
  zvm_define_widget my_zvm_vi_substitute
  zvm_define_widget my_zvm_vi_substitute_whole_line
  zvm_bindkey vicmd 'S' my_zvm_vi_substitute_whole_line
  zvm_bindkey visual 's' my_zvm_vi_substitute
}
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Antidote
# Clone antidote if necessary.
if [[ ! -d ${ZDOTDIR:-$HOME}/.antidote ]]; then
  git clone https://github.com/mattmc3/antidote ${ZDOTDIR:-$HOME}/.antidote
fi

# Source antidote and load.
source ${ZDOTDIR:-$HOME}/.antidote/antidote.zsh
antidote load
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Configure Antidote Plugins
ZSH_AUTOSUGGEST_ACCEPT_WIDGETS=(end-of-line vi-end-of-line vi-add-eol)
ZSH_AUTOSUGGEST_PARTIAL_ACCEPT_WIDGETS=(
  forward-char vi-forward-char forward-word vi-forward-word vi-forward-word-end
  vi-forward-blank-word vi-forward-blank-word-end vi-find-next-char vi-find-next-char-skip
)
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# ZSH options
setopt NO_BEEP
# ------------------------------------------------------------------------------

# zprof
