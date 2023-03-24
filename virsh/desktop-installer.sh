#/!bin/sh
virt-install  \
  --name=desktop \
  --osinfo detect=on,require=on,name=debian11 \
  --memory 8192 \
  --vcpu=4 \
  --cdrom=$HOME/iso/debian.iso \
  --disk size=20,path=$HOME/images/desktop.qcow2 \
  --boot loader=/usr/share/OVMF/x64/OVMF_CODE.secboot.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/x64/OVMF_VARS.fd \
  --network bridge=br0
