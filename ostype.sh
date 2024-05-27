#!/bin/bash

is_mac_os=0
is_windows=0
is_linux=0
if [[ "$OSTYPE" = "darwin"* ]]; then
	is_mac_os=1
elif [[ "$OSTYPE" == "cygwin"* || "$OSTYPE" == "msys"* || "$OSTYPE" == "win32"* ]]; then
	is_windows=1
else
	is_linux=1
fi
