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
  parted /dev/$disk
  #or cfdisk /dev/$disk
  # $disk1 is boot/ EFI system partition - at least 300 MiB 
  # $disk2 is swap - one quarter of RAM
  # $disk3 is root - remaining space of drive
  mkfs.fat -F 32 /dev/$disk1
  mkswap /dev/$disk2
  mkfs.ext4 /dev/$disk3

  mount /dev/$disk3 /mnt
  swapon /dev/$disk2
  mount --mkdir /dev/$disk1 /mnt/boot

  #https://www.freecodecamp.org/news/how-to-install-arch-linux/#how-to-connect-to-the-internet
  #iwctl
  #device list
  #station $wireless scan
  #station $wireless get-networks
  #station $wireless connect $wirelessnetwork

  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bk
  reflector --download-timeout 60 --country $country --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  pacstrap /mnt base linux linux-firmware $editor intel-ucode grub efibootmgr openssh
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

  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub

  grub-mkconfig -o /boot/grub/grub.cfg

  cat > /etc/systemd/network/20-wired.network << EOF
[Match]
Name=$wire

[Network]
DHCP=yes
EOF
  systemctl enable systemd-networkd
  systemctl enable systemd-resolved

  #Sets up a firewall which only allows LAN devices to SSH into host
  #using iptables. (requires further configuration to harden SSH server in
  #/etc/ssh/sshd_config, for example, disabling password authentication)
  #https://serverfault.com/questions/835010/how-to-allow-ssh-only-from-local-network-via-iptables
  iptables -A INPUT -p tcp --dport $sshport -s $LAN -j ACCEPT
  iptables -A INPUT -p tcp --dport $sshport -s 127.0.0.0/8 -j ACCEPT
  iptables -A INPUT -p tcp --dport $sshport -j DROP
  systemctl enable sshd

  echo "Password for root: "
  passwd
  useradd -m $user
  echo "Password for $user: "
  passwd $user

  #only use this if you plan on using a spice server like virt-viewer or virt-manager.
  #pacman -S spice-vdagent xf86-video-qxl

  #to ssh with X11 forwarding into this guest and run graphical programs on the host.
  pacman -S firefox xorg-xprop xorg-xauth pulseaudio pavucontrol paprefs
  #run paprefs as unpriviledged user and select
    #Network Server: Enable network access to local sound devices
  pacman -S htop neofetch

  #exit
  #reboot
}

"$@"
