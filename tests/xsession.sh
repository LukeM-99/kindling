#!/bin/sh
# tests/xsession.sh: Kindling in a real but headless X session (Xvfb), with a throwaway HOME.
# Needs: xvfb openbox tint2 rofi dunst xdotool feh imagemagick xclip x11-utils (xmessage).
# Run from the repo root: sh tests/xsession.sh [shots-dir]   (screenshots go there; default: a temp dir)
# Two outputs can't be faked in Xvfb (one virtual screen), so the multi-monitor checks put a stub
# xrandr in PATH that splits the 1920x1080 screen into two 960x1080 outputs; windows still really move.
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
for c in Xvfb openbox xdotool xwininfo xmessage import convert; do
  command -v $c >/dev/null || { echo "xsession: skipped, $c not installed"; exit 0; }
done
t=$(mktemp -d); shots=${1:-$t/shots}; mkdir -p "$shots"
n=90; while [ -e /tmp/.X11-unix/X$n ] || [ -e /tmp/.X$n-lock ]; do n=$((n + 1)); done
export DISPLAY=:$n HOME="$t/home" XDG_CONFIG_HOME="$t/home/.config" XDG_CACHE_HOME="$t/home/.cache" \
  XDG_RUNTIME_DIR="$t/run" KD_WALLDIR="$t/home/Pictures/Pape" PATH="$t/home/.local/bin:$PATH"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$KD_WALLDIR" && chmod 700 "$XDG_RUNTIME_DIR"
pids=
cleanup() {  # the session's children (tint2, dunst, kd-clip, kd-display watch...) go with the X server's clients
  for p in $pids; do kill "$p" 2>/dev/null; done
  for p in $(pgrep -u "$(id -u)" -f "$t/home" 2>/dev/null); do kill "$p" 2>/dev/null; done
  rm -rf "$t/home" "$t/run"
}
trap cleanup EXIT INT TERM
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
frame() {  # "x y w h" of a window's frame (client plus Openbox decorations)
  set -- $(xprop -id "$1" _NET_FRAME_EXTENTS | cut -sd= -f2 | tr -d ,) 0 0 0 0
  xwininfo -id "$w" | awk -v l="$1" -v r="$2" -v t="$3" -v b="$4" '/Absolute upper-left X/ { x = $NF } /Absolute upper-left Y/ { y = $NF }
    /Width/ { w = $NF } /Height/ { h = $NF } END { print x - l, y - t, w + l + r, h + t + b }'
}
settle() { sleep "${1:-0.6}"; }

Xvfb "$DISPLAY" -screen 0 1920x1080x24 -nolisten tcp >"$t/xvfb.log" 2>&1 & pids="$pids $!"
i=0; until xdpyinfo >/dev/null 2>&1; do i=$((i + 1)); [ $i -gt 50 ] && { echo "FAIL Xvfb did not start"; exit 1; }; sleep .1; done

# the parts of install.sh that link into ~ (no apt, no sudo, no session file)
mkdir -p "$HOME/.local/bin" "$XDG_CONFIG_HOME/openbox" "$XDG_CONFIG_HOME/dunst" "$XDG_CONFIG_HOME/rofi"
for f in "$root"/bin/*; do ln -s "$f" "$HOME/.local/bin/"; done
for f in autostart environment menu.xml; do ln -s "$root/config/openbox/$f" "$XDG_CONFIG_HOME/openbox/$f"; done
ln -s "$XDG_CACHE_HOME/kindling/rc.xml" "$XDG_CONFIG_HOME/openbox/rc.xml"
ln -s "$XDG_CACHE_HOME/kindling/dunstrc" "$XDG_CONFIG_HOME/dunst/dunstrc"
ln -s "$XDG_CACHE_HOME/kindling/rofi.rasi" "$XDG_CONFIG_HOME/rofi/config.rasi"

# two generated wallpapers: a warm one and a cool one
convert -size 1920x1080 gradient:'#7a3b1f-#e8b04a' "$KD_WALLDIR/warm.png"
convert -size 1920x1080 gradient:'#10243a-#5fa3c8' "$KD_WALLDIR/cool.png"

# a first login: the real session script, its autostart (kd-display, kd-theme, tint2, dunst, kd-clip...)
# and the rc.xml that kd-theme renders. Tools pantheon lacks (picom, xss-lock, applets) just fail there.
mkdir -p "$XDG_CACHE_HOME/kindling"; echo "$KD_WALLDIR/cool.png" > "$XDG_CACHE_HOME/kindling/wallpaper"
kindling-session >"$t/session.log" 2>&1 & pids="$pids $!"
i=0; until [ -s "$XDG_CACHE_HOME/kindling/rc.xml" ] && pgrep -u "$(id -u)" -x tint2 >/dev/null; do i=$((i + 1)); [ $i -gt 100 ] && break; sleep .1; done
check "session: kd-theme rendered rc.xml" "$([ -s "$XDG_CACHE_HOME/kindling/rc.xml" ] && echo yes)" yes
check "session: openbox is the window manager" "$(xprop -root _NET_SUPPORTING_WM_CHECK | grep -c window)" 1
settle 1.5
check "session: the wallpaper is drawn (root not black)" "$(import -window root -crop 1x1+960+600 txt:- | grep -c '#000000')" 0
check "session: tint2 bar at the top, in the 52px margin" "$(import -window root -crop 1x1+960+10 txt:- | grep -c '#000000')" 0
settle 1; import -window root "$shots/01-desktop-cool.png"

# a real window to snap
xmessage -geometry 400x300+300+200 "kindling test window" & pids="$pids $!"   # takes focus, unlike xclock
i=0; until w=$(xdotool search --sync --class Xmessage 2>/dev/null | head -1) && [ -n "$w" ]; do i=$((i + 1)); [ $i -gt 30 ] && break; sleep .1; done
xdotool windowactivate --sync "$w" 2>/dev/null; settle
mt=$(sed -n 's:.*<margins><top>\([0-9]*\)</top>.*:\1:p' "$XDG_CONFIG_HOME/openbox/rc.xml")
ml=$(sed -n 's:.*<left>\([0-9]*\)</left>.*:\1:p' "$XDG_CONFIG_HOME/openbox/rc.xml")

kd-snap left "$w"; settle
set -- $(frame "$w"); check "left snap: frame at the top-left margins" "$1 $2" "$ml $mt"
check "left snap: half the width" "$([ "$3" -lt 960 ] && [ "$3" -gt 900 ] && echo half)" half
import -window root "$shots/02-snap-left.png"
kd-snap max "$w"; settle
set -- $(frame "$w"); check "max after a left snap maximises (laptop's regression)" "$([ "$3" -gt 1800 ] && echo max)" max
kd-snap max "$w"; settle
set -- $(frame "$w"); check "max again restores the left snap" "$([ "$3" -lt 960 ] && echo half)" half
xdotool key super+c; settle   # through the X server, so Openbox's keybind sees it
set -- $(frame "$w"); cx=$(($1 + $3 / 2))
check "Super+C (rc.xml keybind) centres at two thirds" "$([ $cx -ge 957 ] && [ $cx -le 963 ] && [ "$3" -gt 1200 ] && [ "$3" -lt 1300 ] && echo centred)" centred
import -window root "$shots/03-centre.png"
kd-snap middle "$w" 2>/dev/null; check "kd-snap bad action exits 2" "$?" 2

# theme switch: colours change and openbox reloads its theme
before=$(md5sum < "$XDG_CACHE_HOME/kindling/colors")
kd-theme "$KD_WALLDIR/warm.png" >>"$t/theme.log" 2>&1; settle 1
check "kd-theme on a new wallpaper re-renders" "$([ "$(md5sum < "$XDG_CACHE_HOME/kindling/colors")" != "$before" ] && echo changed)" changed
import -window root "$shots/04-desktop-warm.png"
rm "$KD_WALLDIR/warm.png"
kd-theme >>"$t/theme.log" 2>&1; check "deleted wallpaper falls back to the folder" "$(cat "$XDG_CACHE_HOME/kindling/wallpaper")" "$KD_WALLDIR/cool.png"

# clipboard: autostart's daemon is running, a second one exits, and the history is private
kd-clip daemon & d2=$!; settle .5
check "a second kd-clip daemon exits (autostart's holds the lock)" "$(kill -0 $d2 2>/dev/null && echo running || echo exited)" exited
printf 'hunter2' | xclip -sel clip; settle 1.6
check "kd-clip saved the copy, private" "$(stat -c %a "$XDG_CACHE_HOME"/kindling/clips/* 2>/dev/null | sort -u)" 600

# two monitors (stub xrandr over the real screen): left snap fits the left output, next moves right
mkdir -p "$t/multi"; cat > "$t/multi/xrandr" <<'EOF'
#!/bin/sh
printf '%s\n' "HDMI-1 connected primary 960x1080+0+0 (normal) 0mm x 0mm" "HDMI-2 connected 960x1080+960+0 (normal) 0mm x 0mm"
EOF
chmod +x "$t/multi/xrandr"
PATH="$t/multi:$PATH" kd-snap left "$w"; settle
set -- $(frame "$w"); check "two outputs: left snap stays inside the left output" "$([ $(($1 + $3)) -le 960 ] && echo inside)" inside
PATH="$t/multi:$PATH" kd-snap next "$w"; settle
set -- $(frame "$w"); check "two outputs: next maximises on the right output" "$([ "$1" -ge 960 ] && [ "$3" -gt 900 ] && echo right)" right
import -window root "$shots/05-two-outputs-next.png"

cp "$t/session.log" "$shots/session.log" 2>/dev/null
echo "screenshots and session.log: $shots"
[ $fail = 0 ] && echo "xsession: all good"
exit $fail
