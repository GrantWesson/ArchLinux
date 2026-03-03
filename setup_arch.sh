#!/bin/bash
# ======================================================
# Fully Automated Arch Linux Installer + KDE + Dev + Gaming
# Passwordless version
# ======================================================
# WARNING: THIS WILL ERASE /dev/nvme0n1! Change DISK variable if needed
# Tested on UEFI systems
# ======================================================

set -e

DISK="/dev/nvme0n1"
HOSTNAME="archbox"
USER="grant"
EFI_PART="${DISK}p1"
ROOT_PART="${DISK}p2"

echo ">>> Updating system clock..."
timedatectl set-ntp true

echo ">>> Partitioning disk..."
sgdisk -Z $DISK
sgdisk -n 1:0:+512M -t 1:ef00 -c 1:"EFI" $DISK
sgdisk -n 2:0:0 -t 2:8300 -c 2:"Root" $DISK

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

echo ">>> Chrooting and configuring system..."
arch-chroot /mnt /bin/bash <<'EOF'
set -e

USER="grant"
HOSTNAME="archbox"

# Hostname
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Timezone & locale
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc
sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

# Create user without password
useradd -m -G wheel -s /bin/zsh $USER

# Sudo without password
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

# Enable networking
systemctl enable NetworkManager

# Install KDE Plasma
pacman -S --noconfirm xorg plasma plasma-wayland-session kde-applications sddm
systemctl enable sddm

# Fonts
pacman -S --noconfirm ttf-fira-code ttf-dejavu

# GPU drivers
if lspci | grep -i nvidia; then
    pacman -S --noconfirm nvidia nvidia-utils lib32-nvidia-utils
elif lspci | grep -i amd; then
    pacman -S --noconfirm mesa lib32-mesa vulkan-icd-loader lib32-vulkan-icd-loader
fi

# Steam + Proton + Vulkan
pacman -S --noconfirm steam vulkan-icd-loader lib32-vulkan-icd-loader gamemode

# Lutris + Wine
pacman -S --noconfirm lutris wine winetricks lib32-wine

# Apps
pacman -S --noconfirm discord
pacman -S --noconfirm --needed yay
yay -S --noconfirm runelite minecraft-launcher

# Dev tools
pacman -S --noconfirm zsh python python-pip nodejs npm docker docker-compose ripgrep fd fzf tmux neovim
systemctl enable --now docker
usermod -aG docker $USER

# Oh My Zsh
runuser -l $USER -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'

# Utilities
pacman -S --noconfirm htop ranger bat lf neofetch timeshift bleachbit

# Neovim minimal JDC-style setup
runuser -l $USER -c 'mkdir -p ~/.config/nvim'
cat <<NVIM > /home/$USER/.config/nvim/init.lua
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

# Gruvbox Plasma color scheme + minimal panel tweaks
runuser -l $USER -c 'mkdir -p ~/.local/share/color-schemes'
runuser -l $USER -c 'curl -fsSL https://raw.githubusercontent.com/GrantWesson/ArchLinux/main/gruvbox-dark.colors -o ~/.local/share/color-schemes/gruvbox-dark.colors'
runuser -l $USER -c 'kwriteconfig5 --file ~/.config/kdeglobals --group "Colors:Window" --key ColorScheme "gruvbox-dark"'
runuser -l $USER -c 'kwriteconfig5 --file ~/.config/plasmashellrc --group "Panel 1" --key visibility "auto"'
runuser -l $USER -c 'kwriteconfig5 --file ~/.config/plasmashellrc --group "Panel 2" --key visibility "auto"'

# Refresh fonts
runuser -l $USER -c 'fc-cache -fv'

EOF

echo ">>> Installation complete! Rebooting..."
umount -R /mnt
reboot
