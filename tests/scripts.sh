#!/bin/sh
# tests/scripts.sh: kd-clip, kd-wallpaper and install.sh checks against stubs, so it runs without X.
# Run from the repo root: sh tests/scripts.sh
set -u
root=$(cd "$(dirname "$0")/.." && pwd)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/cache"
export XDG_CACHE_HOME="$t/cache" PATH="$t/bin:$root/bin:$PATH"
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: got '$2', want '$3'"; fail=1; fi; }
stub() { printf '#!/bin/sh\n%s\n' "$2" > "$t/bin/$1"; chmod +x "$t/bin/$1"; }

# kd-clip daemon: three polls of a clipboard holding a secret, then the stub sleep ends the loop
stub xclip 'echo "hunter2 the password"'
stub xprop 'exit 0'
stub rofi 'exit 1'
stub sleep "n=\$(cat $t/sleeps 2>/dev/null || echo 0); echo \$((n + 1)) > $t/sleeps; [ \$n -lt 3 ]"
kd-clip daemon
clips=$XDG_CACHE_HOME/kindling/clips
check "kd-clip saved one entry" "$(ls "$clips" | wc -l | tr -d ' ')" 1
check "kd-clip entry is private (600)" "$(stat -c %a "$clips"/* 2>/dev/null)" 600
check "kd-clip folder is private (700)" "$(stat -c %a "$clips")" 700
check "kd-clip leaves no temp files" "$(ls -A "$clips" | grep -c '^\.tmp')" 0

# a second daemon while one holds the lock exits at once instead of polling alongside it
rm -f "$t/sleeps"
( flock 9; "$root/bin/kd-clip" daemon; echo "rc=$?" > "$t/second" ) 9>"$clips/.lock" &
wait
check "second kd-clip daemon exits while one holds the lock" "$(cat "$t/second")" "rc=0"
check "second kd-clip daemon never polled" "$(cat "$t/sleeps" 2>/dev/null || echo 0)" 0

# kd-clip daemon exits once X is gone, instead of polling forever after logout
rm -f "$t/sleeps"; stub xprop 'exit 1'
kd-clip daemon
check "kd-clip daemon stops when X is gone" "$(cat "$t/sleeps" 2>/dev/null || echo 0)" 1

# kd-wallpaper: a missing folder exits quietly; a replaced wallpaper gets a new thumbnail
stub convert "echo \"\$1\" >> $t/converted; : > \"\$8\""
stub kd-theme 'exit 0'
stub notify-send "echo \"\$*\" >> $t/notified"
stub rofi 'exit 1'
KD_WALLDIR="$t/nowhere" kd-wallpaper 2>/dev/null; check "kd-wallpaper: missing folder converts nothing" "$(cat "$t/converted" 2>/dev/null | wc -l | tr -d ' ')" 0
check "kd-wallpaper: missing folder is shown as a notification" "$(grep -c "No wallpaper folder" "$t/notified" 2>/dev/null)" 1
mkdir -p "$t/walls/sub"; : > "$t/walls/a.jpg"; : > "$t/walls/README.txt"
KD_WALLDIR="$t/walls" kd-wallpaper; KD_WALLDIR="$t/walls" kd-wallpaper
check "kd-wallpaper: one thumbnail made once, folders and non-images skipped" "$(wc -l < "$t/converted" | tr -d ' ')" 1
touch -d '+1 minute' "$t/walls/a.jpg"
KD_WALLDIR="$t/walls" kd-wallpaper
check "kd-wallpaper: a replaced wallpaper is re-thumbnailed" "$(wc -l < "$t/converted" | tr -d ' ')" 2

# install.sh installs the X tools the scripts call (xprop/xwininfo, xrandr/xset, pactl)
for p in x11-utils x11-xserver-utils pulseaudio-utils; do
  check "install.sh installs $p" "$(grep -c "\b$p\b" "$root/install.sh")" 1
done

[ $fail = 0 ] && echo "all good"
exit $fail
