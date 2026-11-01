#!/usr/bin/env bash
# Builds the release files for Linux and Windows in one go (in build/) – from a clean git checkout whose
# project.godot carries the version given as argument:
#   tools/build_release.sh 0.5.0
# Outputs (upload everything but BUILDINFO.txt, all from the same run):
#   CrossingEurope.x86_64               Linux x86_64, single executable
#   CrossingEurope-linux-x86_64.tar.gz  the same packed with LIZENZEN.txt (executable bit preserved)
#   CrossingEurope.exe                  Windows x86_64, single executable
#   CrossingEurope-windows-x86_64.zip   the same packed with LIZENZEN.txt
#   LIZENZEN.txt                        licence notices (Godot Engine and its parts, fonts, map data)
#   SHA256SUMS                          checksums with bare file names (cd build && sha256sum -c SHA256SUMS)
#   BUILDINFO.txt                       version, git commit and Godot version of this build (own records)
# The archives are reproducible: same commit, same Godot and tools -> same bytes (file times = commit time).
# Needs Godot 4.7.2 with the Linux and Windows export templates, Python 3 with pefile, zip, tar, gzip, git.
# ALLOW_DIRTY=1 also builds from a modified checkout (test builds only; BUILDINFO.txt then says so).
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
PYTHON=${PYTHON:-python3}
VERSION=${1:-}
if [ -z "$VERSION" ]; then
	echo "Aufruf: tools/build_release.sh <Version>   (z. B. tools/build_release.sh 0.5.0)" >&2
	exit 2
fi
PROJECT_VERSION=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)
if [ "$VERSION" != "$PROJECT_VERSION" ]; then
	echo "==> project.godot hat config/version=\"$PROJECT_VERSION\", nicht $VERSION – erst die Version anpassen und committen" >&2
	exit 1
fi
DIRTY=$(git status --porcelain)
if [ -n "$DIRTY" ] && [ "${ALLOW_DIRTY:-0}" != 1 ]; then
	echo "==> Die Arbeitskopie hat nicht committete Änderungen – ein Release nur aus einem Commit bauen:" >&2
	echo "$DIRTY" >&2
	exit 1
fi
if ! "$PYTHON" -c "import pefile" 2>/dev/null; then
	echo "==> Python-Modul pefile fehlt (pip install pefile) – nötig für die Prüfung der .exe" >&2
	exit 1
fi
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)
export REQUIRE_PEFILE=1 EXPECT_VERSION="$VERSION"
mkdir -p build
# no file of an earlier run may slip into the archives or checksums
rm -f build/CrossingEurope.x86_64 build/CrossingEurope.exe build/CrossingEurope-linux-x86_64.tar.gz \
	build/CrossingEurope-windows-x86_64.zip build/LIZENZEN.txt build/SHA256SUMS build/BUILDINFO.txt
tools/build_linux.sh
if [ ! -s build/CrossingEurope.x86_64 ]; then
	echo "==> Linux-Export fehlgeschlagen: build/CrossingEurope.x86_64 fehlt" >&2
	exit 1
fi
tools/build_windows.sh   # also writes build/LIZENZEN.txt and the zip
if [ -z "$DIRTY" ] && [ -n "$(git status --porcelain)" ]; then
	echo "==> Der Build hat Projektdateien geändert (git status) – die Dateien gehören nicht zum Commit:" >&2
	git status --short >&2
	echo "    Änderungen prüfen, committen und neu bauen." >&2
	exit 1
fi
cd build
chmod 755 CrossingEurope.x86_64
chmod 644 LIZENZEN.txt
touch -d "@$SOURCE_DATE_EPOCH" CrossingEurope.x86_64 LIZENZEN.txt
tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner -cf - CrossingEurope.x86_64 LIZENZEN.txt \
	| gzip -n -9 > CrossingEurope-linux-x86_64.tar.gz
sha256sum CrossingEurope.x86_64 CrossingEurope-linux-x86_64.tar.gz CrossingEurope.exe \
	CrossingEurope-windows-x86_64.zip LIZENZEN.txt > SHA256SUMS
sha256sum -c SHA256SUMS
{
	echo "Version: $VERSION"
	echo "Commit: $(git rev-parse HEAD)${DIRTY:+ (mit nicht committeten Änderungen – kein Release)}"
	echo "Commit-Zeit: $(date -u -d "@$SOURCE_DATE_EPOCH" '+%Y-%m-%d %H:%M:%S UTC') (SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH)"
	echo "Godot: $("$GODOT" --version 2>/dev/null | tail -n 1)"
	echo
	cat SHA256SUMS
} > BUILDINFO.txt
cat BUILDINFO.txt
ls -la
