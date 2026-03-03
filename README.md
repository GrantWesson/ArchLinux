# Arch Ultimate Setup - KDE + Dev + Gaming + Gruvbox

This repository contains a **fully automated Arch Linux installer** with KDE Plasma, Gruvbox theme, developer tools, and gaming setup.

## Features

- Fully automated install (UEFI, root partition)
- KDE Plasma with **Gruvbox Dark** theme and minimal auto-hide panels
- FiraCode NerdFont system-wide
- Steam + Proton, Lutris, Wine + Vulkan/DXVK
- RuneLite, Discord, Minecraft Java Edition
- Developer tools: Zsh + Oh My Zsh, Docker, Node.js, Python, Neovim (JDC-style)
- Utilities: htop, ranger, bat, lf, neofetch, timeshift, bleachbit
- Passwordless login + sudo without password

## Files in Repo

- `setup_arch.sh` → Fully automated installer
- `gruvbox-dark.colors` → Plasma color scheme
- `README.md` → Documentation

## Usage

1. Flash **Arch Linux ISO** to a USB and boot into the live environment.
2. Connect to the internet.
3. Run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/GrantWesson/ArchLinux/main/setup_arch.sh | bash
