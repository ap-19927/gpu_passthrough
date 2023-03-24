#!/bin/sh

#### Configurable variables:
####
# find disk you wish to partition from
# fdisk -l
disk="vda"
disk1=$disk"1"
disk2=$disk"2"
disk3=$disk"3"

# find from
# ip a
wire="enp1s0"
wireless="wlan0"
wirelessnetwork="<wireless>"

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
  #or fdisk /dev/$disk
  # $disk1 is boot/ EFI system partition - at least 300 MiB 
  # $disk2 is swap - one quarter of RAM
  # $disk3 is root - remaining space of drive
  mkfs.fat -F 32 /dev/$disk1
  mkswap /dev/$disk2

  #https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system
  cryptsetup -y -v luksFormat /dev/$disk3
  cryptsetup open /dev/$disk3 root
  mkfs.ext4 /dev/mapper/root

  #mount /dev/mapper/root /mnt
  #umount /mnt
  #cryptsetup close root
  #cryptsetup open /dev/$disk3 root
  swapon /dev/$disk2

  mount /dev/mapper/root /mnt
  mount --mkdir /dev/$disk1 /mnt/boot

  #https://www.freecodecamp.org/news/how-to-install-arch-linux/#how-to-connect-to-the-internet
  #iwctl
  #device list
  #station $wireless scan
  #station $wireless get-networks
  #station $wireless connect $wirelessnetwork

  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bk
  reflector --download-timeout 60 --country $country --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  pacstrap /mnt base base-devel linux linux-firmware sudo $editor intel-ucode grub efibootmgr openssh
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
EOF
  grub-mkconfig -o /boot/grub/grub.cfg

  cat > /etc/systemd/network/20-wired.network << EOF
[Match]
Name=$wire

[Network]
DHCP=yes
EOF
  systemctl enable systemd-networkd
  systemctl enable systemd-resolved

  #https://serverfault.com/questions/835010/how-to-allow-ssh-only-from-local-network-via-iptables
  iptables -A INPUT -p tcp --dport $sshport -s $LAN -j ACCEPT
  iptables -A INPUT -p tcp --dport $sshport -s 127.0.0.0/8 -j ACCEPT
  iptables -A INPUT -p tcp --dport $sshport -j DROP
  systemctl enable sshd

  echo "Password for root: "
  passwd
  useradd -m -G wheel $user
  echo "Password for $user: "
  passwd $user
  echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

  #pacman -S spice-vdagent xf86-video-qxl
  pacman -S htop neofetch git

  #exit
  #reboot
}

"$@"
