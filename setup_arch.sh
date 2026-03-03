#!/bin/bash
# ======================================================
# Fully Automated Arch Linux Installer + KDE + Dev + Gaming
# Passwordless version
# ======================================================
# WARNING: THIS WILL ERASE THE TARGET DRIVE! Change DISK if needed
# Tested on UEFI systems
# ======================================================

set -e

# ------------------------------------------------------
# Auto-detect main non-USB drive (avoid live USB)
# ------------------------------------------------------
DISK=$(lsblk -dn -o NAME,TYPE,SIZE | awk '$2=="disk"{print $1; exit}')
echo ">>> Detected target drive: /dev/$DISK"
echo ">>> All detected drives:"
lsblk -d -o NAME,SIZE,MODEL,TYPE

read -p ">>> Press ENTER to continue with /dev/$DISK or Ctrl+C to abort..."

# Determine partition names automatically
if [[ $DISK == nvme* ]]; then
  EFI_PART="/dev/${DISK}p1"
  ROOT_PART="/dev/${DISK}p2"
else
  EFI_PART="/dev/${DISK}1"
  ROOT_PART="/dev/${DISK}2"
fi

HOSTNAME="archbox"
USER="grant"

echo ">>> Updating system clock..."
timedatectl set-ntp true

echo ">>> Partitioning disk..."
sgdisk -Z /dev/$DISK
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" /dev/$DISK
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Root" /dev/$DISK

echo ">>> Formatting partitions..."
mkfs.fat -F32 $EFI_PART
mkfs.ext4 $ROOT_PART

echo ">>> Mounting root..."
mount $ROOT_PART /mnt
mkdir -p /mnt/boot
mount $EFI_PART /mnt/boot

echo ">>> Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware nano networkmanager git sudo

echo ">>> Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# ------------------------------------------------------
# Chroot & system configuration
# ------------------------------------------------------
arch-chroot /mnt /bin/bash <<EOF
set -e

USER="$USER"
HOSTNAME="$HOSTNAME"

echo ">>> Setting hostname and hosts..."
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

echo ">>> Configuring locale & timezone..."
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc
sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

echo ">>> Creating user without password..."
useradd -m -G wheel -s /bin/zsh $USER
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

echo ">>> Enabling networking..."
systemctl enable NetworkManager

echo ">>> Installing Xorg + KDE Plasma..."
pacman -S --noconfirm xorg plasma plasma-wayland-session kde-applications sddm
systemctl enable sddm

echo ">>> Installing fonts..."
pacman -S --noconfirm ttf-fira-code ttf-dejavu

# ------------------------------------------------------
# GPU drivers auto-detection
# ------------------------------------------------------
GPU=$(lspci | grep -E "VGA|3D" | awk '{print $5}')
if lspci | grep -i nvidia; then
  pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils
elif lspci | grep -i amd; then
  pacman -S --noconfirm mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader
else
  pacman -S --noconfirm mesa lib32-mesa
fi

echo ">>> Installing gaming tools..."
pacman -S --noconfirm steam vulkan-icd-loader lib32-vulkan-icd-loader gamemode
pacman -S --noconfirm lutris wine winetricks lib32-wine
pacman -S --noconfirm discord

# ------------------------------------------------------
# AUR helper: yay
# ------------------------------------------------------
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd /

# Install AUR apps
sudo -u $USER yay -S --noconfirm runelite minecraft-launcher

echo ">>> Installing development tools..."
pacman -S --noconfirm zsh python python-pip nodejs npm docker docker-compose ripgrep fd fzf tmux neovim
systemctl enable --now docker
usermod -aG docker $USER

# ------------------------------------------------------
# Oh My Zsh
# ------------------------------------------------------
sudo -u $USER sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# ------------------------------------------------------
# Utilities
# ------------------------------------------------------
pacman -S --noconfirm htop ranger bat lf neofetch timeshift bleachbit

# ------------------------------------------------------
# Neovim setup
# ------------------------------------------------------
sudo -u $USER mkdir -p /home/$USER/.config/nvim
cat <<NVIM > /home/$USER/.config/nvim/init.lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

vim.opt.termguicolors = true
vim.cmd('colorscheme gruvbox')

require("lazy").setup({
  'morhetz/gruvbox',
  'nvim-telescope/telescope.nvim',
  'kyazdani42/nvim-tree.lua',
  'neovim/nvim-lspconfig',
  'hrsh7th/nvim-cmp',
  'lewis6991/gitsigns.nvim',
  'nvim-lualine/lualine.nvim',
})
NVIM
chown -R $USER:$USER /home/$USER/.config/nvim

# ------------------------------------------------------
# Gruvbox Plasma color scheme + minimal panel tweaks
# ------------------------------------------------------
sudo -u $USER mkdir -p /home/$USER/.local/share/color-schemes
sudo -u $USER curl -fsSL https://raw.githubusercontent.com/GrantWesson/ArchLinux/main/gruvbox-dark.colors -o /home/$USER/.local/share/color-schemes/gruvbox-dark.colors
sudo -u $USER kwriteconfig5 --file /home/$USER/.config/kdeglobals --group "Colors:Window" --key ColorScheme "gruvbox-dark"
sudo -u $USER kwriteconfig5 --file /home/$USER/.config/plasmashellrc --group "Panel 1" --key visibility "auto"
sudo -u $USER kwriteconfig5 --file /home/$USER/.config/plasmashellrc --group "Panel 2" --key visibility "auto"

sudo -u $USER fc-cache -fv

EOF

echo ">>> Installation complete! Rebooting..."
umount -R /mnt
reboot
