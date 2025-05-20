#!/bin/sh

#### Configurable variables:
####

# find disk you wish to partition from
# fdisk -l
disk="mmcblk0"
disk1=$disk"p1"
disk2=$disk"p2"
disk3=$disk"p3"

wired="no"

# find from
# ip a
networkdevice="wlan0"

# find from
#https://www.freecodecamp.org/news/how-to-install-arch-linux/#how-to-connect-to-the-internet
# iwctl
# station $networkdevice scan
# station $networkdevice get-networks
networkwireless="<network>"
networkpasswd="<password>"

# find from
# ls /usr/share/zoneinfo
timezone="UTC"

country="US"

LAN="10.0.0.0/24"
sshport="22"

# anything
hostname="<hostname>"
user="<user>"

editor="vim"

####
####

pb () {
  #https://wiki.archlinux.org/title/Installation_guide
  loadkeys us
  timedatectl set-ntp true
  cfdisk /dev/$disk
  # $disk1 is boot/ EFI system partition - at least 300 MiB 
  # $disk2 is swap - one quarter of RAM
  # $disk3 is root - remaining space of drive
  mkfs.fat -F 32 /dev/$disk1
  mkswap /dev/$disk2

  #https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system
  cryptsetup -y -v luksFormat /dev/$disk3
  cryptsetup open /dev/$disk3 root
  mkfs.ext4 /dev/mapper/root

  swapon /dev/$disk2

  mount /dev/mapper/root /mnt
  mount --mkdir /dev/$disk1 /mnt/boot

  if [ "$wired" = "no" ]; then
    iwctl --passphrase $networkpasswd station $networkdevice connect $networkwireless
  fi


  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bk
  reflector --download-timeout 60 --country $country --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

  pacstrap /mnt base linux linux-firmware $editor intel-ucode grub efibootmgr openssh
  if [ "$wired" = "no" ]; then
    pacstrap /mnt iwd
  fi
  genfstab -U /mnt >> /mnt/etc/fstab

  cp -r . /mnt/root/
  arch-chroot /mnt
}

chroot () {
  pacman -Syu
  ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
  hwclock --systohc

  cat > /etc/locale.gen << EOF
en_US.UTF-8 UTF-8
EOF

  cat > /etc/locale.conf << EOF
LANG=en_US.UTF-8
EOF

  cat > /etc/default/locale << EOF
LC_CTYPE=en_US.UTF-8
LC_MESSAGES=en_US.UTF-8
LC_ALL=en_US.UTF-8
EOF

  locale-gen

  cat > /etc/hostname << EOF
$hostname
EOF

  cat > /etc/hosts << EOF
127.0.0.1  localhost
::1        localhost
127.0.1.1  $hostname
EOF

  cat > /etc/mkinitcpio.conf << EOF
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
EOF


  mkinitcpio -P

  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub

  #https://unix.stackexchange.com/questions/108250/print-the-string-between-two-parentheses
  UUID=$(blkid /dev/$disk3 | awk -F"[\"\"]" '{print $2}')
  
  cat > /etc/default/grub << EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash"
GRUB_CMDLINE_LINUX="cryptdevice=UUID=$UUID:root root=/dev/mapper/root"
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_ENABLE_CRYPTODISK=y
GRUB_TIMEOUT_STYLE=menu
GRUB_TERMINAL_INPUT=console
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_RECOVERY=true
GRUB_DISABLE_OS_PROBER=false
EOF
  grub-mkconfig -o /boot/grub/grub.cfg

  #https://stackoverflow.com/questions/2237080/how-to-compare-strings-in-bash
  #https://wiki.archlinux.org/title/Systemd-networkd
  if [ "$wired" = "no" ]; then
    iwctl --passphrase $networkpasswd station $networkdevice connect $networkwireless
    cat > /etc/systemd/network/25-wireless.network << EOF
  [Match]
  Name=$networkdevice

  [Network]
  DHCP=yes
  IgnoreCarrierLoss=3s
EOF
  systemctl enable iwd
  fi
  if [ "$wired" != "no" ]; then
    cat > /etc/systemd/network/20-wired.network << EOF
  [Match]
  Name=$networkdevice

  [Network]
  DHCP=yes
EOF
  fi

  systemctl enable systemd-networkd
  systemctl enable systemd-resolved

  echo "Password for root: "
  passwd
  useradd -m -U $user
  echo "Password for $user: "
  passwd $user

  pacman -S htop neofetch git rsync
  pacman -S xorg-server xorg-xinit xorg-xrandr pulseaudio pavucontrol bspwm alacritty sxhkd rofi polybar keepassxc firefox

}

"$@"
