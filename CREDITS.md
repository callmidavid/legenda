# Credits

**Legenda** is the [Glyph rice](https://github.com/Nebelung-cloud/glyph-rice) adapted for Ubuntu.

## Original work

- **Glyph rice** — created and maintained by **Nebelung** ([@Nebelung-cloud](https://github.com/Nebelung-cloud)).
  Upstream: <https://github.com/Nebelung-cloud/glyph-rice>
- Sibling project: [Demon's Shot rice](https://github.com/Nebelung-cloud/demons-shot-rice).
- The Hyprland (Lua) configuration, the Quickshell shell `glyph`, the `rice` shell switcher,
  the theme, the bundled fonts and the screenshots are the original author's work.
- Licensed under **GPL-3.0** (see [LICENSE](LICENSE)), same as upstream. This fork keeps that license.
- Bundled fonts are under the **SIL Open Font License** (see [config/fonts/OFL.txt](config/fonts/OFL.txt)).
- cava shaders keep their MIT headers.

## What this fork changes

Ubuntu packaging only — no design work:

- `install-ubuntu.sh`: Hyprland from `ppa:cppiber/hyprland`, Quickshell via Nix,
  Nerd Font, then the original `install.sh --links`.
- `ubuntu/qs`: wrapper that gives the Nix Quickshell its Mesa EGL vendor
  (the Nix build ships libglvnd without Mesa, so OpenGL fails otherwise).
- Ubuntu paths in `config/hypr/hyprland/execs.lua` (`hyprpolkitagent`, geoclue),
  `QT_QPA_PLATFORMTHEME=gtk3` in `env.lua`, `firefox` as browser.
- `config/quickshell/rice/rice`: every start/lock goes through the `~/.local/bin/qs`
  wrapper by absolute path. GDM sessions on Ubuntu get their `PATH` from
  `/etc/environment`, which has no `~/.local/bin`; without this the shell picks a bare
  `qs` without the EGL setup and the session stays black.
- Lock screen PAM (`config/quickshell/glyph/pam/lock`): Nix's `pam_unix` looks for the
  NixOS helper `/run/wrappers/bin/unix_chkpwd`, so the installer links Ubuntu's setuid
  `/usr/sbin/unix_chkpwd` there. The stock `pam_faillock` lines were dropped: as a
  normal user they cannot write `/var/run/faillock` and reject every password.
- Wallpaper picker (`wall/Walls.qml`): Ubuntu ships ImageMagick 6, whose binary is
  `convert`; the scan used `magick` (ImageMagick 7) and silently produced no images.
- Ubuntu notes in the README.

If you redistribute or modify this, keep the credit above and the GPL-3.0 license.
