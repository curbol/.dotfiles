#!/bin/bash

# Exit early if the script has already been sourced
if [[ -n ${OSTYPE_LOADED+x} ]]; then
	return
fi

# Set the flag to indicate the script has been sourced
export OSTYPE_LOADED=1

# OS detection logic
is_mac_os=0
is_windows=0
is_linux=0

if [[ "$OSTYPE" == "darwin"* ]]; then
	is_mac_os=1
elif [[ "$OSTYPE" == "cygwin"* || "$OSTYPE" == "msys"* || "$OSTYPE" == "win32"* ]]; then
	is_windows=1
else
	is_linux=1
fi
