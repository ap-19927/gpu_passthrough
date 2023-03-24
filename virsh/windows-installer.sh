#/!bin/sh

#number of CPUs on host
CPUhost=16
#number of CPUs wished to pin
CPUguest=12
cpupin=""
for i in $(seq 0 $((CPUguest-1)));
do
  cpupin=$cpupin"vcpupin$i.vcpu=$i,vcpupin$i.cpuset=$((i+CPUhost-CPUguest)),"
done
cpupin=${cpupin::-1}

#CPU topology found through lscpu
#these three numbers should multiply to $CPUguest
sockets=1
threads=2
cores=7
topology="topology.sockets=$sockets,topology.cores=$((CPUguest/threads)),topology.threads=$threads" 

#mouse and keyboard found through lsusb
mouse="/dev/input/by-id/usb-1bcf_08a0-event-mouse"
keyboard="/dev/input/by-id/usb-SEMICO_USB_Gaming_Keyboard-event-kbd"

audiopath="xpath1.set=./@serverName=/run/user/1000/pulse/native"

#GPU and other devices in its IOMMU group found through lspci
#IOMMU groups found through find /sys/kernel/iommu_groups/ -type l
GPUfunctionid="06:00.0"
audiofunctionid="06:00.1"

virt-install \
  --name=windows \
  --connect qemu:///system \
  --osinfo detect=on,require=on,name=win11 \
  --memory 12288 \
  --vcpu=$CPUguest \
  --cputune $cpupin \
  --cpu host-passthrough,$topology \
  --cdrom=$HOME/iso/windows.iso \
  --disk size=150,path=$HOME/images/windows.img,format=raw \
  --network bridge=br0 \
  --host-device $GPUfunctionid,address.type=pci,address.multifunction=on \
  --host-device $audiofunctionid,address.type=pci  \
  --input \
    type=evdev,source.dev=$mouse \
  --input \
    type=evdev,source.dev=$keyboard,source.grab=all,source.repeat=on,source.grabToggle=ctrl-ctrl \
  --graphics none \
  --sound model=ich9,codec.type=micro,audio.id=1 \
  --audio id=1,type=pulseaudio,$audiopath \
  --features kvm_hidden=on,smm=on \
  --boot loader=/usr/share/OVMF/x64/OVMF_CODE.secboot.fd,loader.readonly=yes,loader.type=pflash,nvram.template=/usr/share/OVMF/x64/OVMF_VARS.fd,loader_secure=yes \
  --tpm backend.type=emulator,backend.version=2.0,model=tpm-tis
