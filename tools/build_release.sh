#!/usr/bin/env bash
# Builds the release files for Linux and Windows in one go (in build/):
#   CrossingEurope.x86_64               Linux x86_64, single executable
#   CrossingEurope-linux-x86_64.tar.gz  the same packed (executable bit preserved)
#   CrossingEurope.exe                  Windows x86_64, single executable
#   CrossingEurope-windows-x86_64.zip   the same packed
#   SHA256SUMS                          checksums with bare file names (cd build && sha256sum -c SHA256SUMS)
# Needs Godot 4.7.2 with the Linux and Windows export templates, Python 3, zip and tar.
set -euo pipefail
cd "$(dirname "$0")/.."
tools/build_linux.sh
tools/build_windows.sh
cd build
rm -f CrossingEurope-linux-x86_64.tar.gz SHA256SUMS
tar --owner=0 --group=0 --numeric-owner -czf CrossingEurope-linux-x86_64.tar.gz CrossingEurope.x86_64
sha256sum CrossingEurope.x86_64 CrossingEurope-linux-x86_64.tar.gz CrossingEurope.exe \
	CrossingEurope-windows-x86_64.zip > SHA256SUMS
sha256sum -c SHA256SUMS
cat SHA256SUMS
ls -la
