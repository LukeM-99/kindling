#!/bin/sh
# install.sh: apt deps, then symlink configs and scripts into place (old ones go to ~/.dotfiles_backup).
set -e
cd "$(dirname "$(readlink -f "$0")")"

# realtime priority for the audio group (jackd2's install question, answered yes)
echo "jackd2 jackd/tweak_rt_limits boolean true" | sudo debconf-set-selections
sudo apt install -y openbox tint2 rofi dunst picom feh imagemagick maim xclip xdotool \
  xsecurelock xss-lock brightnessctl pamixer jq playerctl rxvt-unicode libnotify-bin \
  pcmanfm arandr libfuse2 libx11-protocol-perl librsvg2-bin xsettingsd adwaita-icon-theme fonts-noto-core fonts-hack jackd2 pulseaudio-module-jack libasound2-plugins
for g in video audio; do id -nG | grep -qw $g || sudo adduser "$USER" $g; done  # brightnessctl, jackd realtime

backup=~/.dotfiles_backup/$(date +%F_%H%M%S)
link() {
  if [ -e "$2" ] && [ ! -L "$2" ]; then mkdir -p "$backup"; mv "$2" "$backup/"; fi
  mkdir -p "$(dirname "$2")"
  ln -sfn "$1" "$2"
}
# openbox and rofi used to be whole-directory links; their rc.xml/config.rasi are now rendered by kd-theme
for d in openbox rofi; do [ -L ~/.config/$d ] && rm ~/.config/$d; done
for f in autostart environment menu.xml; do link "$PWD/config/openbox/$f" ~/.config/openbox/$f; done
link "$PWD/config/picom" ~/.config/picom
for f in bin/*; do link "$PWD/$f" ~/.local/bin/"${f#bin/}"; done
link ~/.cache/kindling/dunstrc ~/.config/dunst/dunstrc
link ~/.cache/kindling/rc.xml ~/.config/openbox/rc.xml
link ~/.cache/kindling/rofi.rasi ~/.config/rofi/config.rasi
link "$PWD/config/asoundrc" ~/.asoundrc
sudo ln -sfn "$PWD/bin/kindling-session" /usr/local/bin/kindling-session
sudo cp session/kindling.desktop /usr/share/xsessions/

[ -d ~/Pictures/Pape ] || echo "Put some wallpapers in ~/Pictures/Pape (or set KD_WALLDIR)."
echo "Done. Log out and pick the 'kindling' session."
