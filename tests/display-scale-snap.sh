#!/bin/sh
# tests/display-scale-snap.sh: kd-scale and kd-snap against stub X tools, so it runs without a display.
# Run from the repo root: sh tests/display-scale-snap.sh
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/home/.config/openbox"
export HOME="$t/home" XDG_CONFIG_HOME="$t/home/.config" XDG_CACHE_HOME="$t/home/.cache" XDG_RUNTIME_DIR="$t/run"
export PATH="$t/bin:$root/bin:$PATH"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }

# stubs: the xrandr output comes from $t/xrandr; xdotool records what it was asked to do
cat > "$t/bin/xrandr" <<EOF
#!/bin/sh
cat "$t/xrandr"
EOF
cat > "$t/bin/xdotool" <<EOF
#!/bin/sh
[ "\$1" = getactivewindow ] && { echo 4242; exit; }
echo "\$*" > "$t/xdotool.log"
EOF
cat > "$t/bin/xprop" <<'EOF'
#!/bin/sh
echo "_NET_FRAME_EXTENTS(CARDINAL) = 2, 2, 20, 2"
EOF
cat > "$t/bin/xwininfo" <<EOF
#!/bin/sh
cat "$t/xwininfo"
EOF
for s in kd-theme notify-send; do printf '#!/bin/sh\n' > "$t/bin/$s"; done
chmod +x "$t/bin/"*
printf '<margins><top>10</top><bottom>10</bottom><left>10</left><right>10</right></margins>\n' > "$HOME/.config/openbox/rc.xml"
geom() { printf '  Absolute upper-left X:  %s\n  Absolute upper-left Y:  %s\n  Width: %s\n  Height: %s\n' "$@" > "$t/xwininfo"; }

# kd-scale: the default follows the panel type, DSI included
echo "eDP-1 connected primary 1920x1080+0+0 (normal) 344mm x 194mm" > "$t/xrandr"
kd-scale; check "eDP panel alone defaults to 150" "$(cat "$XDG_CACHE_HOME/kindling/scale")" 150
echo "DSI-1 connected primary 1200x1920+0+0 (normal) 135mm x 216mm" > "$t/xrandr"
rm -f "$XDG_CACHE_HOME/kindling/scale"; kd-scale
check "DSI panel alone defaults to 150" "$(cat "$XDG_CACHE_HOME/kindling/scale")" 150
echo "HDMI-1 connected primary 2560x1440+0+0 (normal) 600mm x 340mm" > "$t/xrandr"
kd-scale up; check "external: 100 up is 125" "$(cat "$XDG_CACHE_HOME/kindling/scale")" 125
check "remembered per layout" "$(cat "$XDG_CONFIG_HOME/kindling/scale")" "HDMI-1 125"
: > "$t/xrandr"
kd-scale up; check "no lit screen: nothing remembered" "$(grep -c '^ ' "$XDG_CONFIG_HOME/kindling/scale")" 0

# kd-snap on one 1920x1080 monitor with 10px margins: frame extents l2 r2 t20 b2
echo "HDMI-1 connected primary 1920x1080+0+0 (normal) 600mm x 340mm" > "$t/xrandr"
geom 302 220 800 600   # client at 302,220 so the frame is at 300,200
kd-snap left; check "left half" "$(cat "$t/xdotool.log")" "windowsize 4242 941 1038 windowmove 4242 10 10"
geom 302 220 800 600
kd-snap max; check "max fills the monitor less the margins" "$(cat "$t/xdotool.log")" "windowsize 4242 1896 1038 windowmove 4242 10 10"
geom 12 30 1896 1038  # now maximised: the frame sits at the target corner
kd-snap max; check "max again restores the size before" "$(cat "$t/xdotool.log")" "windowsize 4242 800 600 windowmove 4242 300 200"
rm -rf "$XDG_RUNTIME_DIR/kd-snap"
geom 12 30 1896 1038  # maximised, but with no size saved (e.g. it opened that way)
kd-snap max; check "max with nothing saved restores to the centre, 2/3 size" "$(cat "$t/xdotool.log")" "windowsize 4242 1262 684 windowmove 4242 327 187"
rm -rf "$XDG_RUNTIME_DIR/kd-snap"
geom 12 30 937 1016   # left-snapped: at the max corner too, but half width
kd-snap max; check "max on a left-snapped window maximises" "$(cat "$t/xdotool.log")" "windowsize 4242 1896 1038 windowmove 4242 10 10"
geom 302 220 800 600
kd-snap center; check "center: 2/3 of the monitor, centred" "$(cat "$t/xdotool.log")" "windowsize 4242 1262 684 windowmove 4242 327 187"

rm -f "$t/xdotool.log"
kd-snap middle 2>"$t/err"; rc=$?
check "unknown action: exit 2" "$rc" 2
check "unknown action: usage on stderr" "$(head -c 14 "$t/err")" "usage: kd-snap"
check "unknown action: window untouched" "$([ -e "$t/xdotool.log" ] && echo moved || echo untouched)" untouched

[ $fail = 0 ] && echo "all good"
exit $fail
