# kindling

A lightweight desktop for old machines, inspired by [minflair](https://github.com/t4lentles5/minflair): Openbox + tint2 + rofi + dunst, themed from your wallpaper. No Qt, no Python, no systemd (built on Devuan; works on Debian too).

```
./install.sh        # then log out and pick "kindling"
```

Wallpapers live in `~/Pictures/Pape` (override with `KD_WALLDIR`). `Ctrl+Alt+W` picks one and recolours everything; `Super+/` lists all keybinds; `Super+G` turns the compositor off for the leanest mode. `Super+Shift+Space` launches AppImages from `~/Applications` (override with `KD_APPDIR`).

## Scaling

`Super+=` / `Super+-` / `Super+0` step the UI scale (100–200%) for the current screen layout and reset it; each layout remembers its own (`~/.config/kindling/scale`). The laptop panel alone defaults to 150%, anything with an external screen to 100%. It sets `Xft.dpi` and XSETTINGS (via `xsettingsd`, so GTK apps like Firefox rescale live; others on restart) and re-renders kindling's own sizes: templates mark them `{{s N}}`. X11 has one DPI for all screens, so mixed layouts use one scale.

## Audio

The `♪` in the bar: click for a volume slider (click a level, or type a number up to 150 and press Enter), right-click for devices and apps, middle-click to mute, scroll to step 5%. The right-click menu switches output or input device (playing streams move with it), mutes the output or the mic, and sets each app's own volume; it also opens `pavucontrol` if you've installed it. The same menu is "Audio" in the desktop menu. The bar's number updates as soon as the volume changes, from `pactl subscribe`.

## JACK

`Super+A` (or clicking `○ jack` in the bar) starts jackd on an ALSA card you pick and bridges PulseAudio into it, so desktop audio keeps working; again stops it and hands the card back to Pulse. `Super+Shift+A` is a rofi patchbay. ALSA apps can skip Pulse with the `jack` device (`aplay -D jack`). Defaults: 48 kHz, 256-frame periods; override with `KD_JACK_RATE`, `KD_JACK_PERIOD`, `KD_JACK_DEV=hw:PCH`.

## How theming works

`bin/kd-theme` shrinks the wallpaper to 8 colours, picks background/foreground/accent roles, fills the `{{placeholders}}` in `templates/`, and reloads Openbox, tint2, dunst and open urxvt windows. Generated files go to `~/.cache/kindling/`.
