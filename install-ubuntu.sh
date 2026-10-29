#!/usr/bin/env bash
# Legenda (Glyph rice) — установка на Ubuntu 24.04+.
#
#   ./install-ubuntu.sh
#
# Что делает:
#   1. Hyprland 0.56 (Lua-конфиг) и утилиты — из PPA cppiber/hyprland
#   2. Quickshell 0.3.2 — из Nix: в 24.04 его нет, а системный Qt 6.4 слишком стар
#   3. JetBrainsMono Nerd Font — иконки шелла рисуются глифами этого шрифта
#   4. Симлинки конфигов через ./install.sh --links
#
# Переменные окружения:
#   LEGENDA_NIX_SUBSTITUTERS="https://mirror.example/nix-channels/store" — свой бинарный кэш,
#       если cache.nixos.org недоступен (Китай: mirror.sjtu.edu.cn/nix-channels/store)
#   LEGENDA_SKIP_NIX=1 — не ставить Nix (qs уже есть в PATH)

set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
say() { printf '\e[38;2;215;25;33m●\e[0m %s\n' "$*"; }
die() { printf '\e[38;2;215;25;33m✕\e[0m %s\n' "$*" >&2; exit 1; }

[ "$EUID" -eq 0 ] && die "запускай от пользователя, sudo спросит сам"

. /etc/os-release
case "${ID:-}:${VERSION_ID:-}" in
    ubuntu:2[4-9]*) ;;
    ubuntu:*) say "предупреждение: скрипт написан под Ubuntu 24.04+, продолжаю" ;;
    *) say "предупреждение: это не Ubuntu (${ID:-?}), продолжаю" ;;
esac

sudo -v || die "нужен sudo"

say "apt: Hyprland + утилиты (PPA cppiber/hyprland)"
sudo apt-get update -qq
sudo apt-get install -y -qq software-properties-common curl unzip >/dev/null
if ! apt-cache policy hyprland 2>/dev/null | grep -q 'ppa.launchpadcontent.net/cppiber'; then
    sudo add-apt-repository -y ppa:cppiber/hyprland >/dev/null
    sudo apt-get update -qq
fi

# всё, что зовут бинды, шелл и конфиги; qt6-gtk-platformtheme — тема Qt-приложений
sudo apt-get install -y --no-install-recommends \
    hyprland hyprland-data hypridle hyprsunset hyprpicker \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprpolkitagent \
    kitty fish btop cava eza zoxide direnv thunar pavucontrol \
    papirus-icon-theme bibata-cursor-theme fonts-jetbrains-mono \
    fonts-noto-color-emoji cliphist wl-clipboard grim slurp imagemagick \
    libvips-tools qalc brightnessctl playerctl trash-cli ydotool \
    gnome-keyring geoclue-2.0 upower power-profiles-daemon network-manager \
    bluez policykit-1-gnome xdg-user-dirs libnotify-bin \
    jq python3 qt6-gtk-platformtheme

# Brightness: /sys/class/backlight/*/brightness is root:video 0664. Ubuntu does not
# put the user in video, so brightnessctl (and the XF86MonBrightness* keys) fail
# with "Permission denied" while the OSD still moves.
if ! id -nG "$(id -un)" | tr ' ' '\n' | grep -qx video; then
    sudo usermod -aG video "$(id -un)"
    NEED_RELOGIN=1
fi

say "Quickshell 0.3.2 + Mesa"
if [ "${LEGENDA_SKIP_NIX:-0}" != 1 ] && [ ! -x "$HOME/.nix-profile/bin/quickshell" ]; then
    if [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
        say "ставлю Nix (единоразово, ~500 МБ)"
        sh <(curl -L https://nixos.org/nix/install) --daemon --yes
    fi
    # shellcheck disable=SC1091
    . /etc/profile.d/nix.sh

    # флаги flakes и, при необходимости, зеркало кэша
    if ! grep -q '^experimental-features' /etc/nix/nix.conf 2>/dev/null; then
        echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf >/dev/null
    fi
    if [ -n "${LEGENDA_NIX_SUBSTITUTERS:-}" ]; then
        if ! grep -q "^substituters" /etc/nix/nix.conf; then
            echo "substituters = ${LEGENDA_NIX_SUBSTITUTERS}" | sudo tee -a /etc/nix/nix.conf >/dev/null
        fi
    fi
    sudo systemctl restart nix-daemon 2>/dev/null || true

    nix profile add nixpkgs#quickshell nixpkgs#mesa
fi

# Quickshell links Nix's linux-pam, whose pam_unix looks for the NixOS setuid helper
# /run/wrappers/bin/unix_chkpwd. Ubuntu ships the same helper as /usr/sbin/unix_chkpwd,
# so link it there: otherwise the lock screen rejects the correct password with
# PAM_AUTHINFO_UNAVAIL ("Authentication service cannot retrieve authentication info").
if [ -x "$HOME/.nix-profile/bin/quickshell" ]; then
    sudo install -d -m 0755 /run/wrappers/bin
    sudo ln -sfn /usr/sbin/unix_chkpwd /run/wrappers/bin/unix_chkpwd
    printf '%s\n' \
        'd /run/wrappers/bin 0755 root root -' \
        'L /run/wrappers/bin/unix_chkpwd - - - - /usr/sbin/unix_chkpwd' \
        | sudo tee /etc/tmpfiles.d/glyph-pam.conf >/dev/null
    sudo systemd-tmpfiles --create /etc/tmpfiles.d/glyph-pam.conf || true
fi

# ~/.local/bin/qs — обёртка, которая подсовывает EGL Mesa из nix-профиля
install -Dm755 "$DOTS/ubuntu/qs" "$HOME/.local/bin/qs"
if [ ! -x "$HOME/.nix-profile/bin/quickshell" ]; then
    say "предупреждение: quickshell не найден в ~/.nix-profile, qs не запустится"
fi

say "JetBrainsMono Nerd Font"
if ! fc-list 2>/dev/null | grep -q 'JetBrainsMono Nerd Font'; then
    tmp="$(mktemp -d)"
    curl -fL --retry 3 -o "$tmp/font.zip" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNF"
    unzip -oq "$tmp/font.zip" -d "$HOME/.local/share/fonts/JetBrainsMonoNF"
    rm -rf "$tmp"
    fc-cache -f >/dev/null
fi

say "симлинки конфигов"
"$DOTS/install.sh" --links

if [ "${NEED_RELOGIN:-0}" = 1 ]; then
    say "яркость: пользователь добавлен в группу video — заработает после повторного входа."
fi

say "готово. Выйди из сессии и выбери Hyprland на экране входа (шестерёнка)."
say "Обои: положи картинки в ~/Pictures/Wallpapers (Super+Shift+W)."
