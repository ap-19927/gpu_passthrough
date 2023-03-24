#!/bin/sh
exit
####
#
# Importantly, this guide assumes we have two GPUs to work with. One to
# passthrough, and one for the tty of the host.
#
####
# This is meant as a guideline for others who wish to install an Arch Linux
# host with GPU passthrough.
# It is not recommended to run this script without modification on your own
# system.
# For example, this assumes you have a wired network connection to create a
# bridge.
# Also, we passthrough a NVIDIA card with the nouveau driver.
# Moreover, there is no configuration set up for the host to use bspwm,
# alacritty, rofi, and polybar together and with x11.
# In general, a display manager is not needed to spin up a virtual machine with
# its own GPU. for example, it can be run with
# virsh start windows
# if windows is the name of the VM.
# And a window manager/desktop is not needed to run virt-viewer with spice.
# Instead,
# startx /usr/bin/virt-viewer --connect qemu:///session --wait desktop
# for example, if desktop is the name of the VM.
#
# This guide also assumes an intel processor with VT-d enabled in the BIOS.

#this is a sequence of commands which installs an Arch Linux host
#(qemu/kvm) with boot, swap and root paritions.
#Boot partition uses grub2.
#Linux kernel.
#base package
#The root partition is encrypted with LUKS.
#It also sets up a GPU passthrough of a VGA device of your choice via OVMF:
#https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF
#Sets up a network bridge br0 with networkd
#libvirt/virsh as a frontend for managing the virtual machines.
#Passthrough audio with pulseaudio
#Sets root password
#Defines a user and their password.
#Also installs some display stuff using xorg, bspwm, sxhkd, rofi, and polybar.
#Other than virtualization, this OS runs a password manager, keepassxc.
#(requires further configuration to set up the window manager and accessories)

#### Configurable variables:
####
# find disk you wish to partition from
# fdisk -l
disk="nvme0n1"
disk1=$disk"p1"
disk2=$disk"p2"
disk3=$disk"p3"

cpuvendor="intel"

# first column of
# lspci -nnk | grep "NVIDIA"
# of the devices you wish to pass through
VGAcontroller="06:00.0"
# example:
# 06:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP108 [GeForce GT 1030] [10de:1d01] (rev a1)
gpudriver="nouveau"

# find from
# ip a
wire="enp4s0"
wireless="wlan0"
wirelessnetwork="<wireless>"

# find from
# ls /usr/share/zoneinfo
timezone="UTC"
# find from
# cat /etc/locale.gen | less
locale="en_US.UTF-8"
localegen=$locale" UTF-8"

country="US"

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
  # $disk"1" is boot/ EFI system partition - at least 300 MiB 
  # $disk"2" is swap - one quarter of RAM
  # $disk"3" is root - remaining space of drive
  mkfs.fat -F 32 /dev/$disk1
  mkswap /dev/$disk2

  #https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system
  cryptsetup -y -v luksFormat /dev/$disk3
  cryptsetup open /dev/$disk3 root
  mkfs.ext4 /dev/mapper/root

  #mount /dev/mapper/root /mnt
  #umount /mnt
  #cryptsetup close root
  #cryptsetup open /dev/$disk"3" root
  swapon /dev/$disk2

  mount /dev/mapper/root /mnt
  mount --mkdir /dev/$disk1 /mnt/boot

  #https://www.freecodecamp.org/news/how-to-install-arch-linux/#how-to-connect-to-the-internet
  #iwctl
  #device list
  #station $wireless scan
  #station $wireless get-networks
  #station $wireless connect $wirelessnetwork
  ucode="intel-ucode"
  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bk
  reflector --download-timeout 60 --country $country --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
  pacstrap /mnt base linux linux-firmware $editor $ucode grub efibootmgr usbutils dosfstools pulseaudio pavucontrol openssh os-prober
  genfstab -U /mnt >> /mnt/etc/fstab

  cp -r . /mnt/root/
  arch-chroot /mnt
}

chroot () {
  pacman -Syu
  ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
  hwclock --systohc

  cat > /etc/locale.gen << EOF
$localegen
EOF

  cat > /etc/locale.conf << EOF
LANG=$locale
EOF

  cat > /etc/default/locale << EOF
LC_CTYPE=$locale
LC_MESSAGES=$locale
LC_ALL=$locale
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

  cat > /etc/modprobe.d/$gpudriver.conf << EOF
softdep $gpudriver pre: vfio-pci
EOF

  cati > /etc/modules-load.d/vfio-pci.conf << EOF
vfio-pci
EOF

  cat > /etc/modules << EOF
pci_stub
vfio
vfio_iommu_type1
vfio_pci
kvm
kvm_intel
EOF

  cat > /etc/mkinitcpio.conf << EOF
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect modconf keyboard keymap consolefont block encrypt filesystems fsck)
EOF


  mkinitcpio -P

  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=grub
  os-prober

  #https://unix.stackexchange.com/questions/108250/print-the-string-between-two-parentheses
  UUID=$(blkid /dev/$disk3 | awk -F"[\"\"]" '{print $2}')

  VGAcontroller="0000:"$VGAcontroller
  VGAvendor=$(cat /sys/bus/pci/devices/$VGAcontroller/vendor)
  VGAvendor=${VGAvendor:2}
  VGAdevice=$(cat /sys/bus/pci/devices/$VGAcontroller/device)
  VGAdevice=${VGAdevice:2}
  cpuvendor=$cpuvendor"_iommu"
  
  cat > /etc/default/grub << EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet splash $cpuvendor=on iommu=pt vfio_iommu_type1.allow_unsafe_interrupts=1 vfio-pci.ids=$VGAvendor:$VGAdevice"
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

  cat > /etc/systemd/network/20-wired.network << EOF
[Match]
Name=$wire
EOF
  cat > /etc/systemd/network/10-bind.network << EOF
[Match]
Name=$wire

[Network]
Bridge=br0
EOF
  cat > /etc/systemd/network/30-br0.netdev << EOF
[NetDev]
Name=br0
Kind=bridge
EOF
  cat > /etc/systemd/network/30-br0.network << EOF
[Match]
Name=br0

[Network]
DHCP=yes
EOF
  systemctl enable systemd-networkd
  systemctl enable systemd-resolved

  echo "Password for root: "
  passwd
  useradd -m $user
  echo "Password for $user: "
  passwd $user

  pacman -S qemu-base virt-install virt-viewer swtpm qemu-audio-pa
  echo "allow br0" > /etc/qemu/bridge.conf

  echo "user = \"$user\"" > /etc/libvirt/qemu.conf

  echo "EDITOR=$editor" >> /etc/environment
  usermod -a -G libvirt $user
  systemctl enable libvirtd

  pacman -S xorg-server xorg-xinit xorg-xrandr bspwm alacritty sxhkd rofi polybar htop neofetch keepassxc

  #exit
  #reboot
}

"$@"
