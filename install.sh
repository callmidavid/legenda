#!/usr/bin/env bash
# Glyph: ставит всё на чистый Arch и линкует конфиги из этого репо.
#   ./install.sh          пакеты + сервисы + симлинки
#   ./install.sh --links  только симлинки (на уже готовой системе)
set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dots-backup-$(date +%F_%H-%M-%S)"

PACMAN=(
    # база
    base-devel git curl jq python
    # сессия
    hyprland hypridle hyprsunset hyprpicker xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    sddm quickshell polkit-gnome gnome-keyring geoclue upower xdg-user-dirs
    # звук, сеть, bluetooth
    pipewire pipewire-pulse wireplumber networkmanager bluez bluez-utils power-profiles-daemon
    # утилиты, которые зовут бинды и шелл
    brightnessctl playerctl wl-clipboard cliphist grim slurp swappy imagemagick libvips libqalculate
    gpu-screen-recorder ydotool libnotify trash-cli
    # терминал и консоль
    kitty fish starship fastfetch btop cava eza zoxide direnv
    # приложения из variables.lua
    thunar pavucontrol
    # шрифты, иконки (Papirus-Dark — основа темы папок Rice)
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji papirus-icon-theme
)

AUR=(
    qtengine darkly-bin bibata-cursor-theme-bin
    zen-browser-bin clash-verge-rev-bin
)

G=config/quickshell/glyph
# репо-путь → путь в $HOME
LINKS=(
    "config/hypr                                .config/hypr"
    "$G                                         .config/quickshell/glyph"
    "config/quickshell/rice                     .config/quickshell/rice"
    "config/quickshell/rice/rice                .local/bin/rice"
    "config/kitty                               .config/kitty"
    "config/qtengine                            .config/qtengine"
    "$G/term/qtengine.colors                    .config/qtengine.colors"
    "$G/term/starship.toml                      .config/starship.toml"
    "$G/term/fastfetch                          .config/fastfetch"
    "$G/term/btop                               .config/btop"
    "$G/term/cava                               .config/cava"
    "$G/term/gtk-3.0/gtk.css                    .config/gtk-3.0/gtk.css"
    "$G/term/gtk-4.0/gtk.css                    .config/gtk-4.0/gtk.css"
    "config/fish/config.fish                    .config/fish/config.fish"
    "config/fish/functions/fish_greeting.fish   .config/fish/functions/fish_greeting.fish"
    "config/fonts                               .local/share/fonts/glyph"
)

say() { printf '\e[38;2;215;25;33m●\e[0m %s\n' "$*"; }

packages() {
    say "pacman"
    sudo pacman -Syu --needed --noconfirm "${PACMAN[@]}"

    if ! command -v yay >/dev/null; then
        say "yay"
        local tmp; tmp="$(mktemp -d)"
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi

    say "aur"
    yay -S --needed --noconfirm "${AUR[@]}"
}

services() {
    say "сервисы"
    sudo systemctl enable NetworkManager bluetooth power-profiles-daemon
    systemctl is-enabled -q display-manager.service 2>/dev/null || sudo systemctl enable sddm
    systemctl --user enable pipewire-pulse.socket wireplumber ydotool
    sudo usermod -aG input,video "$USER" # ydotool (uinput), brightnessctl
    xdg-user-dirs-update
}

links() {
    say "симлинки (старое → $BACKUP)"
    local src dst
    for l in "${LINKS[@]}"; do
        read -r src dst <<<"$l"
        src="$DOTS/$src" dst="$HOME/$dst"
        [ "$(readlink "$dst")" = "$src" ] && continue
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            mkdir -p "$BACKUP/$(dirname "${dst#"$HOME"/}")"
            mv "$dst" "$BACKUP/${dst#"$HOME"/}"
        fi
        mkdir -p "$(dirname "$dst")"
        ln -s "$src" "$dst"
        echo "  $dst"
    done
    # rules.json и kitty.conf шелл создаст сам; rice поднимет glyph и соберёт тему папок
    mkdir -p "$HOME/.config/demonshot" "${XDG_STATE_HOME:-$HOME/.local/state}/rice"
    echo glyph > "${XDG_STATE_HOME:-$HOME/.local/state}/rice/shell"
    mkdir -p "$HOME/Pictures/Wallpapers" # пикер обоев (Super+Shift+W) смотрит сюда
    fc-cache -f >/dev/null
}

[ "$EUID" -eq 0 ] && { echo "запускай от пользователя, sudo спросит сам"; exit 1; }

case "${1:-}" in
    --links) links ;; # на любом дистрибутиве (NixOS, Fedora…): пакеты тогда свои, список — в README
    "") command -v pacman >/dev/null || { echo "пакеты ставлю только на Arch; на другом дистрибутиве: $0 --links"; exit 1; }
        packages; services; links
        say "готово. перезагрузись и выбери Hyprland в sddm" ;;
    *) echo "usage: $0 [--links]"; exit 1 ;;
esac
