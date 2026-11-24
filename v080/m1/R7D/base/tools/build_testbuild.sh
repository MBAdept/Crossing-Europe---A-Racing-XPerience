#!/usr/bin/env bash
# Test build for a user review gate (v0.8.0, docs/dev/v080_contract.md §7, docs/qa-v080.md): Linux x86_64 (also for
# the Steam Deck) and Windows x86_64 from the current commit, made so that it never touches a normal installation:
#   - its own version string (shown on the title screen, in leistungstest.json and in savegames),
#   - its own user folder (application/config/use_custom_user_dir): records, settings, saves, logs and the
#     Leistungstest file live apart from the released game – Linux/Steam Deck ~/.local/share/<user dir>/,
#     Windows %APPDATA%\<user dir>\,
#   - its own executable and archive names.
# These three are build-only changes: project.godot and export_presets.cfg are patched for the export and restored
# afterwards (also on failure) – nothing of it is committed.
#
#   tools/build_testbuild.sh <version> <name> [user dir]
#   tools/build_testbuild.sh 0.8.0-zs1 ZS1 crossing-europe-zwischenstand
#
# Output in build/testbuild/<name>/ (OUT=<dir> for another folder):
#   CrossingEurope-<name>-linux-x86_64.tar.gz   CrossingEurope-<name>.x86_64 + LIZENZEN.txt (executable bit kept)
#   CrossingEurope-<name>-windows-x86_64.zip    CrossingEurope-<name>.exe + LIZENZEN.txt
#   LIZENZEN.txt, SHA256SUMS (archives, executables, licence file; bare names), BUILDINFO.txt (own records)
# The bare executables stay in the folder too (they are larger than an upload allows; the archives are the delivery).
# The Windows version resource needs four numbers: WINVER (default: the numbers of <version> plus the number at the
# end of its suffix, 0.8.0-zs1 → 0.8.0.1). The archives are reproducible (file times = commit time) and each must
# stay below MAX_MIB (default 400 MiB, the delivery limit) – besides the size gate of tools/pck_report.py.
# Uses tools/build_linux.sh and tools/build_windows.sh unchanged; needs what they need (Godot 4.7.2 with the export
# templates, Python 3 with pefile, zip, tar, gzip). A modified working copy is refused unless ALLOW_DIRTY=1.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=${1:-}
NAME=${2:-}
USERDIR=${3:-crossing-europe-zwischenstand}
if [ -z "$VERSION" ] || [ -z "$NAME" ]; then
	sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
fi
case "$NAME$USERDIR" in
*/* | *" "*)
	echo "==> Name und Nutzerordner ohne / und Leerzeichen angeben" >&2
	exit 2
	;;
esac
if [ -z "${WINVER:-}" ]; then
	base=$(echo "$VERSION" | grep -oE '^[0-9]+(\.[0-9]+){0,2}')
	n=$(echo "${VERSION#"$base"}" | grep -oE '[0-9]+$' || echo 0)
	WINVER=$(echo "$base.0.0" | cut -d. -f1-3).${n:-0}
fi
if ! echo "$WINVER" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
	echo "==> WINVER=$WINVER ist keine Windows-Versionsnummer aus vier Zahlen" >&2
	exit 2
fi
MAX_MIB=${MAX_MIB:-400}
DIRTY=$(git status --porcelain)
if [ -n "$DIRTY" ] && [ "${ALLOW_DIRTY:-0}" != 1 ]; then
	echo "==> Die Arbeitskopie hat nicht committete Änderungen – ein Testbuild entsteht aus einem Commit:" >&2
	echo "$DIRTY" >&2
	exit 1
fi
OUT=${OUT:-build/testbuild/$NAME}
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
BASE="CrossingEurope-$NAME"
rm -f "$OUT/$BASE.x86_64" "$OUT/$BASE.exe" "$OUT/$BASE-linux-x86_64.tar.gz" "$OUT/$BASE-windows-x86_64.zip" \
	"$OUT/LIZENZEN.txt" "$OUT/SHA256SUMS" "$OUT/BUILDINFO.txt"

# build-only changes, restored on every exit
SAVE=$(mktemp -d "${TMPDIR:-/tmp}/ce_testbuild.XXXXXX")
cp project.godot "$SAVE/project.godot"
cp export_presets.cfg "$SAVE/export_presets.cfg"
restore() {
	cp "$SAVE/project.godot" project.godot
	cp "$SAVE/export_presets.cfg" export_presets.cfg
	rm -rf "$SAVE"
}
trap restore EXIT
python3 - "$VERSION" "$USERDIR" "$WINVER" <<'EOF'
import re, sys
version, userdir, winver = sys.argv[1:4]
p = open("project.godot", encoding="utf-8").read()
p, n = re.subn(r'^config/version=".*"$', 'config/version="%s"' % version, p, count=1, flags=re.M)
assert n == 1, "config/version fehlt in project.godot"
p = re.sub(r'^config/(use_custom_user_dir|custom_user_dir_name)=.*\n', "", p, flags=re.M)
p = p.replace('config/version="%s"\n' % version,
              'config/version="%s"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="%s"\n' % (version, userdir), 1)
open("project.godot", "w", encoding="utf-8").write(p)
e = open("export_presets.cfg", encoding="utf-8").read()
for key in ("file_version", "product_version"):
    e, n = re.subn(r'^application/%s=".*"$' % key, 'application/%s="%s"' % (key, winver), e, flags=re.M)
    assert n == 1, "application/%s fehlt in export_presets.cfg" % key
open("export_presets.cfg", "w", encoding="utf-8").write(e)
EOF
echo "==> Testbuild $VERSION ($NAME): Nutzerordner \"$USERDIR\", Windows-Version $WINVER"
grep -E '^config/(version|use_custom_user_dir|custom_user_dir_name)=' project.godot | sed 's/^/    /'
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)
export REQUIRE_PEFILE=1 EXPECT_VERSION="$WINVER"
rm -f build/CrossingEurope.x86_64 build/CrossingEurope.exe build/CrossingEurope-windows-x86_64.zip build/LIZENZEN.txt
tools/build_linux.sh
[ -s build/CrossingEurope.x86_64 ] || { echo "==> Linux-Export fehlgeschlagen" >&2; exit 1; }
tools/build_windows.sh
[ -s build/CrossingEurope.exe ] && [ -s build/LIZENZEN.txt ] || { echo "==> Windows-Export fehlgeschlagen" >&2; exit 1; }
restore
trap - EXIT
# the import cache may hold the patched settings: import once more with the restored project file
godot_bin=${GODOT:-godot}
"$godot_bin" --headless --path . --import >/dev/null 2>&1 || true

mv build/CrossingEurope.x86_64 "$OUT/$BASE.x86_64"
mv build/CrossingEurope.exe "$OUT/$BASE.exe"
cp build/LIZENZEN.txt "$OUT/LIZENZEN.txt"
rm -f build/CrossingEurope-windows-x86_64.zip build/LIZENZEN.txt
cd "$OUT"
chmod 755 "$BASE.x86_64"
chmod 644 "$BASE.exe" LIZENZEN.txt
touch -d "@$SOURCE_DATE_EPOCH" "$BASE.x86_64" "$BASE.exe" LIZENZEN.txt
tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner -cf - "$BASE.x86_64" LIZENZEN.txt \
	| gzip -n -9 > "$BASE-linux-x86_64.tar.gz"
TZ=UTC zip -q -9 -X "$BASE-windows-x86_64.zip" "$BASE.exe" LIZENZEN.txt
python3 "$OLDPWD/tools/pck_report.py" --gate-only --archive "$BASE-linux-x86_64.tar.gz"
python3 "$OLDPWD/tools/pck_report.py" --gate-only --archive "$BASE-windows-x86_64.zip"
for a in "$BASE-linux-x86_64.tar.gz" "$BASE-windows-x86_64.zip"; do
	mib=$(( ($(stat -c %s "$a") + 1048575) / 1048576 ))
	if [ "$mib" -gt "$MAX_MIB" ]; then
		echo "==> $a hat $mib MiB – mehr als $MAX_MIB MiB" >&2
		exit 1
	fi
done
sha256sum "$BASE-linux-x86_64.tar.gz" "$BASE-windows-x86_64.zip" "$BASE.x86_64" "$BASE.exe" LIZENZEN.txt > SHA256SUMS
sha256sum -c SHA256SUMS
{
	echo "Testbuild: $VERSION ($NAME), Windows-Version $WINVER"
	echo "Nutzerordner: $USERDIR (Linux/Steam Deck ~/.local/share/$USERDIR/, Windows %APPDATA%\\$USERDIR\\)"
	echo "Commit: $(git -C "$OLDPWD" rev-parse HEAD)${DIRTY:+ (mit nicht committeten Änderungen)}"
	echo "Commit-Zeit: $(date -u -d "@$SOURCE_DATE_EPOCH" '+%Y-%m-%d %H:%M:%S UTC') (SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH)"
	echo "Godot: $("$godot_bin" --version 2>/dev/null | tail -n 1)"
	echo "Archive: Linux $(( ($(stat -c %s "$BASE-linux-x86_64.tar.gz") + 524288) / 1048576 )) MiB, Windows $(( ($(stat -c %s "$BASE-windows-x86_64.zip") + 524288) / 1048576 )) MiB (Grenze $MAX_MIB MiB)"
	echo
	cat SHA256SUMS
} > BUILDINFO.txt
cat BUILDINFO.txt
ls -la
