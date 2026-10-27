#!/bin/sh
# tests/check.sh: checks that need no X session or installed packages. Run from anywhere; prints "check: all good".
cd "$(dirname "$0")/.." || exit 1
fail=0
bad() { echo "FAIL: $*"; fail=1; }

# every script parses as POSIX sh
for f in bin/* install.sh; do sh -n "$f" || bad "sh -n $f"; done

# each keybind the README names exists in templates/rc.xml
for k in $(grep -o '`\(Super\|Ctrl\)+[^`]*`' README.md | tr -d '`' | sort -u); do
  x=$(echo "$k" | sed 's/Super+/W-/g; s/Shift+/S-/g; s/Ctrl+/C-/g; s/Alt+/A-/g; s|-/$|-slash|; s/-=$/-equal/; s/--$/-minus/; s/-Space$/-space/')
  x=$(echo "$x" | sed 's/-\([A-Z]\)$/-\L\1/')   # single-letter keys are lower case keysyms (Ctrl+Alt+W -> C-A-w); \L is GNU sed
  grep -q "key=\"$x\"" templates/rc.xml || bad "README keybind $k ($x) not in templates/rc.xml"
done

# the README's uninstall removes every script install.sh links
grep -q 'for f in bin/\*' README.md || bad "README uninstall does not cover bin/"

# no private strings: one per line in a file kept out of the repo (it would leak them itself)
priv=${KD_PRIVATE:-$HOME/.config/kindling/private-strings}
[ -f "$priv" ] && grep -rnI -i -F -f "$priv" --exclude-dir=.git . && bad "private string in the tree"

# kd-theme: a remembered wallpaper that was deleted falls back to the wallpaper folder (stubbed X tools)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/stub" "$t/cache/kindling" "$t/walls" "$t/home"
for c in feh xrdb pkill openbox pgrep ps; do printf '#!/bin/sh\n[ "$(basename "$0")" = feh ] && echo "$@" > "%s/feh.args"\nexit 0\n' "$t" > "$t/stub/$c"; chmod +x "$t/stub/$c"; done
printf '#!/bin/sh\necho "      9: ( 20, 30, 40) #141E28 srgb(20,30,40)"\n' > "$t/stub/convert"; chmod +x "$t/stub/convert"
: > "$t/walls/a.jpg"; : > "$t/walls/README.txt"; mkdir "$t/walls/0-folder"; echo "$t/gone.jpg" > "$t/cache/kindling/wallpaper"
PATH="$t/stub:$PATH" HOME="$t/home" XDG_CACHE_HOME="$t/cache" KD_WALLDIR="$t/walls" sh bin/kd-theme >/dev/null 2>&1 || bad "kd-theme exits when the remembered wallpaper is gone"
grep -q "$t/walls/a.jpg" "$t/feh.args" 2>/dev/null || bad "kd-theme did not fall back to the folder's first image"
[ "$(cat "$t/cache/kindling/wallpaper")" = "$t/walls/a.jpg" ] || bad "kd-theme did not remember the fallback (kd-display reads the cache)"

# the other test scripts
for f in tests/*.sh; do case $f in tests/check.sh | tests/xsession.sh) continue ;; esac   # xsession: slow, run it on its own
   sh "$f" >/dev/null || bad "$f"; done

[ $fail = 0 ] && echo "check: all good"
exit $fail
