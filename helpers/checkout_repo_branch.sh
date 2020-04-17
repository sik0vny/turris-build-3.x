#!/bin/bash
set -o errexit -o nounset

helpers_dir="$(dirname "$(readlink -f "$0")")"
. "$helpers_dir/common.sh"

print_usage() {
	cat >&2 <<-EOF
		Usage: ${0##*/} [-h] BRANCH [BOARD]
	EOF
}

print_help() {
	print_usage
	cat >&2 <<-EOF
		  Use this script to checkout turris-build repository relative to branch on
		  repo.turris.cz. It not only checkouts exact commit in turris-build
		  repository, but it also modifies feeds.conf file so exactly same feeds are
		  used as they were used to build files on server.

		BRANCH argument is required and is target publish branch (Do not mix this
		  with git branch of same name).
		BOARD is optional argument used to specify different board. In default
		  'omnia' is used. This is available because sometimes versions for boards
		  are not in sync and can differ. It should be in most cases safe to use
		  default but if you encounter problems you can try setting appropriate
		  board.

		Options:
		  -h, --help  Print this help text
	EOF
}

target=""
board=""

declare -A long2short=( ["help"]="h" )
dashdash="n"
while [ "$OPTIND" -le "$#" ]; do
	argument="${!OPTIND}"
	if [ "$dashdash" = "n" ] && getopts ":h" opt; then
		if [ "${argument:0:2}" = "--" ]; then
			longopt="${argument:2}"
			if [ -v long2short["$longopt"] ]; then
				opt="${long2short[$longopt]}"
			else
				OPTARG="$argument"
			fi
		fi
		case "$opt" in
			h)
				print_help
				exit 0
				;;
			\?)
				echo "Illegal option: $OPTARG"
				exit 1
				;;
		esac
		continue
	elif [ "$argument" == "--" -a "$dashdash" = "n" ]; then
		dashdash="y"
		continue
	elif [ -z "$target" ]; then
		target="$argument"
	elif [ -z "$board" ]; then
		board="$argument"
	else
		echo "Unexpected argument: $argument"
		exit 1
	fi
	((OPTIND = OPTIND + 1))
done

[ -z "$target" ] && {
	print_usage
	exit 1
}
[ -z "$board" ] && board="omnia"

[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ] && \
	die "Current working directory is not in git repository"

toplevel="$(git rev-parse --show-toplevel)"

hashes="$(curl "https://repo.turris.cz/$target/$board/packages/git-hash" | \
	tail -n +2 | grep -v '^$' | sed 's/^ \* //;s/: /:/')"

get_hash() {
	awk -F: -vname="$1" '$1 == name { print $2 }' <<<"$hashes"
}

# Initaly checkout turris-build
git checkout "$(get_hash turris-build)"

# And secondly modify feeds so we are modifying appropriate version
while read -r tp name url vars; do
	[ "$tp" = "#" ] && fullname="$name" || fullname="feeds/$name"
	githash="$(get_hash "$fullname")"
	[ -n "$githash" ] && url="$(sed "s/[;^].*$//;s/$/\^$githash/" <<<"$url")"
	echo "$tp" "$name" "$url" "$vars"
done < "$toplevel/feeds.conf" >feeds.conf.new
mv feeds.conf.new feeds.conf
