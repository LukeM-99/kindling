#!/bin/sh
# tests/tint2.sh: the rendered tint2rc loads in this tint2 with no invalid options, and a machine with no
# battery gets no "Plug in soon" warning. Needs Xvfb and tint2; skips without them.
cd "$(dirname "$0")/.." || exit 1
command -v Xvfb >/dev/null && command -v tint2 >/dev/null || { echo "tint2: skipped (no Xvfb/tint2)"; exit 0; }
[ -z "$(ls /sys/class/power_supply/BAT* 2>/dev/null)" ] || { echo "tint2: skipped (this machine has a battery)"; exit 0; }
t=$(mktemp -d); d=:$((90 + $$ % 9))
trap 'kill $xp 2>/dev/null; rm -rf "$t"' EXIT
mkdir -p "$t/stub" "$t/home"
printf '#!/bin/sh\necho "$@" >> "%s/notify.log"\n' "$t" > "$t/stub/notify-send"; chmod +x "$t/stub/notify-send"
sed -e 's/{{s \([0-9]*\)}}/\1/g' -e 's/{{[a-z0-9]*}}/#888888/g' templates/tint2rc > "$t/tint2rc"
Xvfb "$d" -screen 0 1280x800x24 >/dev/null 2>&1 & xp=$!; sleep 1
DISPLAY=$d HOME="$t/home" PATH="$t/stub:$PATH" timeout -k 1 5 tint2 -c "$t/tint2rc" > "$t/err" 2>&1
fail=0
grep -i 'invalid option' "$t/err" && fail=1
[ -s "$t/notify.log" ] && { echo "battery warning with no battery: $(cat "$t/notify.log")"; fail=1; }
[ $fail = 0 ] && echo "tint2: all good"
exit $fail
