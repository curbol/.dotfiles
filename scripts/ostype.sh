#!/bin/bash

# Exit early if the script has already been sourced
if [[ -n ${OSTYPE_LOADED+x} ]]; then
  return
fi

# Set the flag to indicate the script has been sourced
export OSTYPE_LOADED=1

# OS detection logic
is_windows=0
is_linux=0
is_mac_os=0
is_mac_arm=0
is_mac_intel=0

if [[ "$OSTYPE" == "darwin"* ]]; then
  is_mac_os=1
  # Check if the architecture is ARM (Apple Silicon) or x86_64 (Intel)
  arch=$(uname -m)
  if [[ "$arch" == "arm64" ]]; then
    is_mac_arm=1
  elif [[ "$arch" == "x86_64" ]]; then
    is_mac_intel=1
  fi
elif [[ "$OSTYPE" == "cygwin"* || "$OSTYPE" == "msys"* || "$OSTYPE" == "win32"* ]]; then
  is_windows=1
else
  is_linux=1
fi

export is_windows
export is_linux
export is_mac_os
export is_mac_arm
export is_mac_intel
