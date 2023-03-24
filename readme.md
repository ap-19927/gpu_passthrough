The above are scripts for various arch installs, the most involved one is run
for the purpose of creating a system which is able to passthrough a PCI device
to a virtual machine via OVMF using libvirt. The `virsh` directory contains
`virt-install` commands, the most involved one directions for installing a UEFI
secure booted, TPM emulated Windows 11 install with CPU pinning, GPU
passthrough, evdev controlled mouse and keyboard and pulseaudio enabled sound.

# References
https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF
https://github.com/manbearpig3130/MBP-VT-d-gaming-machine
https://www.smoothnet.org/qemu-tpm/
https://www.reddit.com/r/kvm/comments/dnyx5i/virtinstall_gpu_passthrough_command/
https://github.com/NVIDIA/deepops/tree/master/virtual#bootloader-changes
https://github.com/virt-manager/virt-manager/issues/216
https://www.heiko-sieger.info/running-windows-10-on-linux-using-kvm-with-vga-passthrough/
