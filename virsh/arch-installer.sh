#/!bin/sh

virt-install  \
  --name=min \
  --osinfo detect=on,require=on,name=archlinux \
  --memory 1024 \
  --vcpu=1 \
  --cdrom=$HOME/iso/arch.iso \
  --disk size=5,path=$HOME/images/min.qcow2 \
  --boot loader=/usr/share/OVMF/x64/OVMF_CODE.secboot.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/x64/OVMF_VARS.fd \
  --network bridge=br0
