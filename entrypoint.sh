#!/bin/sh

if [ $# -eq 0 ]; then
	cat <<- EOH
	Additional commands are provided by the Docker container entry point:
	        certdb <dst> : copy database migration scripts locally in ./<dst>
	        json         : cfssljson executable
	        mkbundle     : mkbundle executable
	        multirootca  : multirootca executable

	cfssl generic help:
	`cfssl -h 2>&1`
	EOH
else
	case "$1" in
		"certdb")
			shift
			if [ $# -eq 0 ]; then
				echo "missing destination argument" 1>&2
				exit 1
			fi
			cp -R /usr/share/misc/cfssl ./"$1"
			;;
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
