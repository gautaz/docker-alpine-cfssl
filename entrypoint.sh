#!/bin/sh

if [ $# -eq 0 ]; then
	cat <<- EOH
	Additional commands are provided by the Docker container entry point:
	        json        : cfssljson executable
	        mkbundle    : mkbundle executable
	        multirootca : multirootca executable

	cfssl generic help:
	`cfssl -h 2>&1`
	EOH
else
	case "$1" in
		"json")
			shift
			cfssljson "$@"
			;;
		"mkbundle"|"multirootca")
			command="$1"
			shift
			"${command}" "$@"
			;;
		*)
			cfssl "$@"
			;;
	esac
fi
