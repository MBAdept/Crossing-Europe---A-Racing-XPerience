#!/usr/bin/env bash
# FIX-WASSER-R: replace the five build files in deliver/FIX-WASSER/build by the new ones; the replaced files go to
# m1/FIX-WASSER-R/alt/ first (kept until the new ones passed). Then sha256sum -c --ignore-missing in the delivery.
set -uo pipefail
S=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/m1/FIX-WASSER-R
D=/tmp/claude-0/-home-user-crossing-europe---a-racing-xperience/3a945943-d653-5a54-8279-676b9bc6f9e5/scratchpad/v080/deliver/FIX-WASSER/build
FILES="CrossingEurope-ZS1-linux-x86_64.tar.gz CrossingEurope-ZS1-windows-x86_64.zip LIZENZEN.txt SHA256SUMS BUILDINFO.txt"
mkdir -p "$S/alt"
for f in $FILES; do
	if [ -e "$D/$f" ] && [ ! -e "$S/alt/$f" ]; then
		cp -p "$D/$f" "$S/alt/$f"
	fi
done
echo "== alt gesichert:"; ls -la "$S/alt"
for f in $FILES; do
	cp -p "$S/testbuild/$f" "$D/$f"
done
echo "== geliefert:"; ls -la "$D"
(cd "$D" && sha256sum -c --ignore-missing SHA256SUMS)
echo "sha256 exit $?"
cat "$D/BUILDINFO.txt"
