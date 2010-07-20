#!/bin/sh
# build spec or src.rpm with hasher

hsh_build()
{
	nice time hsh $HSHARGS \
		--apt-conf="${APTCONF:=/etc/apt/apt.conf}" \
		--mountpoints=/proc \
		"${WORKDIR:=$HOME/hasher/tmpfs}" \
		"$@" \
	&& echo "rpm --resign $@ && rsync -Pav $@ git.alt: && ssh git.alt task new && ssh git.alt task add srpm `basename $@` && echo -n 'fire: ' && read && ssh git.alt task run"
	# "task new" before rsync might be slightly better
	# if hanging tasks after rsync failures are deleted
}

rpmbs()
{
	nice rpm -bs --nodeps "$1" \
	| sed -ns 's/^.*: \(.*\.src\.rpm\)$/\1/p'
}

fatal()
{
	echo "$0: error: $*" >&2
	exit 1
}

while [ $# -gt 0 ]; do
	case "$1" in
		*.spec) hsh_build `rpmbs "$1"`; shift;;
		*.src.rpm) hsh_build "$1"; shift;;
		*) fatal "$1 is neither src.rpm nor spec file";;
	esac
done

#find "$WORKDIR/repo" -name '*.rpm'
