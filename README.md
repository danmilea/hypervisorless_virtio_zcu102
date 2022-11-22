# Hypervisorless Virtio / ZCU102
*Hypervisorless virtio build environment for Xilinx ZCU102 with Petalinux and Zephyr as auxiliary runtime*

This repository includes the infrastructure required to build and deploy a hypervisorless virtio environment on Xilinx ZCU102 (QEMU) with PetaLinux running on Cortex A53 and Zephyr running on Cortex R5.

The physical machine monitor (PMM) which includes the virtio back-ends runs on PetaLinux and communicates with the Zephyr auxiliary runtime over shared memory.

Notes:
- A complete build will require at least 34 GB of free disk space.
- These build instructions have been validated on Ubuntu 20.04.

More information on Hypervisorless virtio is available here: https://www.openampproject.org/news/hypervisorless-virtio-blog/

# Prerequisites

### Host tools:

```
sudo apt install python3-sphinx qemu-user qemu-user-static kpartx libpixman-1-dev libssl-dev ca-certificates apt-transport-https build-essential
```

### Zephyr prerequisites (reference: https://docs.zephyrproject.org/latest/getting_started/index.html)
```
wget https://apt.kitware.com/kitware-archive.sh
sudo bash kitware-archive.sh
sudo apt install --no-install-recommends git cmake ninja-build gperf \
  ccache dfu-util device-tree-compiler wget \
  python3-dev python3-pip python3-setuptools python3-tk python3-wheel xz-utils file \
  make gcc gcc-multilib g++-multilib libsdl2-dev
pip3 install --user -U west
echo 'export PATH=~/.local/bin:"$PATH"' >> ~/.bashrc
source ~/.bashrc
```
### Others:

Download ZYNQMP common image v2020.2 from https://www.xilinx.com/member/forms/download/xef.html?filename=xilinx-zynqmp-common-v2020.2.tar.gz

Download ZCU102 BSP v2020.2 from https://www.xilinx.com/member/forms/download/xef.html?filename=xilinx-zcu102-v2020.2-final.bsp

Update the XLNX_COMMON_PACKAGE and XLNX_ZCU102_BSP paths in build.sh

# Building hypervisorless virtio artifacts for ZCU102

```
env HVL_WORKSPACE=/home/dan/workspaces/hvlws bash build.sh
```

The build.sh build script clones the following source repositories:


- https://github.com/Xilinx/qemu.git - branch xilinx-v2021.1

- https://github.com/Xilinx/linux-xlnx.git - branch xilinx-v2020.2

- https://github.com/dgibson/dtc.git

- https://github.com/OpenAMP/kvmtool.git - branch hvl-integration

- https://github.com/OpenAMP/openamp-zephyr-staging.git - branch virtio-exp

## Build artifacts 

- QEMU Xilinx is installed in **$HVL_WORKSPACE/qemu_inst/** and is used to set up the ZCU102 emulation infrastructure.
- A Linux kernel image is based the configuration from util/config_hvl is built and copied to **$HVL_WORKSPACE/tftp/**
- An updated device tree machine model which includes util/system-user.dtsi is compiled and copied to **$HVL_WORKSPACE/tftp/**
- An SD card file system image based on xilinx-zcu102-2020.2/pre-built/linux/images/petalinux-sdimage.wic is copied as **$HVL_WORKSPACE/linux-sd.wic**
- Binaries to be copied in the file system image are placed **$HVL_WORKSPACE/target**: Linux kernel modules, ZCU102 mailbox driver module, a Zephyr application named zephyr.elf based on the rng_net hypervisorless virtio sample and the Physical Machine Monitor based on kvmtool and its dependencies.

> The files in **$HVL_WORKSPACE/tftp/** are used during the boot phase.
## Finalizing the setup

At the end of its execution the build.sh script prints the remaining set of commands to complete the file system setup.

E.g.

    sudo kpartx -av /home/dan/workspaces/hvlws/linux-sd.wic
    export SDLOOPDEV=`basename $(losetup |grep /home/dan/workspaces/hvlws/linux-sd.wic|awk '{print $1}')`
    sudo mount /dev/mapper/${SDLOOPDEV}p2 /home/dan/workspaces/hvlws/mnt
    sudo cp -a /home/dan/workspaces/hvlws/target/* /home/dan/workspaces/hvlws/mnt/
    sudo chmod +x /home/dan/workspaces/hvlws/mnt/chr_setup.sh
    sudo chroot /home/dan/workspaces/hvlws/mnt/ bash -c /chr_setup.sh
    sudo umount /home/dan/workspaces/hvlws/mnt
    sudo kpartx -dv /home/dan/workspaces/hvlws/linux-sd.wic

Please inspect the commands and, if satisfied they will not cause your system to melt down, run them.

## Runtime

The build script prints a set of commands which can be used to run the QEMU emulator for ZCU102:

E.g.
```
QEMU PMU
--------
rm /tmp/qemu-memory-_*

/home/dan/workspaces/hvlws/qemu_inst/bin/qemu-system-microblazeel -M microblaze-fdt -nographic -dtb /home/dan/workspaces/hvlws/xilinx-zcu102-2020.2/pre-built/linux/images/zynqmp-qemu-multiarch-pmu.dtb -kernel /home/dan/workspaces/hvlws/xilinx-zcu102-2020.2/pre-built/linux/images/pmu_rom_qemu_sha3.elf -device loader,file=/home/dan/workspaces/hvlws/xilinx-zcu102-2020.2/pre-built/linux/images/pmufw.elf -machine-path /tmp

PETALINUX (A53)
---------------

/home/dan/workspaces/hvlws/qemu_inst/bin/qemu-system-aarch64 -M arm-generic-fdt -dtb /home/dan/workspaces/hvlws/xilinx-zcu102-2020.2/pre-built/linux/images/zynqmp-qemu-multiarch-arm.dtb -device loader,file=/home/dan/workspaces/hvlws/xilinx-zcu102-2020.2/pre-built/linux/images/bl31.elf,cpu-num=0 -global xlnx,zynqmp-boot.cpu-num=0 -global xlnx,zynqmp-boot.use-pmufw=true -machine-path /tmp -net nic -net nic -net nic -net nic -net user,tftp=/home/dan/workspaces/hvlws/tftp,hostfwd=tcp::30022-:22 -serial mon:stdio -m 4G --nographic -serial telnet:localhost:4321,server,wait=off -echr 2 -drive file=/home/dan/workspaces/hvlws/linux-sd.wic,if=sd,format=raw,index=1 -device loader,file=/home/dan/workspaces/hvlws/xilinx-zcu102-2020.2/pre-built/linux/images/u-boot.elf

U-Boot configuration: 

setenv bootargs "earlycon clk_ignore_unused root=/dev/mmcblk0p2 ro rootwait earlyprintk debug uio_pdrv_genirq.of_id=generic-uio";
dhcp 200000 Image; dhcp 100000 dtb.dtb;
setenv initrd_high 78000000; booti 200000 - 100000;


After booting, Linux on A53 can also be accessed as:
telnet localhost 4321

Zephyr (R5)
-----------
telnet localhost 4321
```

> The paths are specific to your hypervisor-less virtio workspace.

You will need 4 terminals (referered to as T1 to T4) in the following instructions. The commands in each terminal section need to be run in the corresponding terminal.

**T1: QEMU PMU**
- Run the commands in the QEMU PMU section

**T2: PetaLinux**
- Run the command in the PETALINUX (A53) section

Once the U-Boot autoboot prompt is displayed, press Enter to stop the boot sequence.
```
Hit any key to stop autoboot: 0
```

- Run the commands in the U-Boot configuration section  U-Boot commands to boot PetaLinux


- Once the login prompt ```xilinx-zcu102-2020_2 login:``` is displayed, login using root / root.

These remaining commands setup the inter-CPU cluster infrastructure, prepare the start auxiliary runtime (i.e. Zephyr) and start the physical memory manager (PMM).

```
ip tuntap del mode tap tap0;ip tuntap add mode tap user $USER tap0;ifconfig tap0 192.168.200.254 up
cd /hvl/
insmod user-mbox.ko
cp /hvl/zephyr.elf /lib/firmware/
echo zephyr.elf >/sys/class/remoteproc/remoteproc0/firmware

/hvl/lkvm run --debug --vxworks --rsld --pmm --debug-nohostfs --transport mmio --shmem-addr 0x37000000 --shmem-size 0x1000000 --cpus 1 --mem 128 --no-dtb --debug --rng --network mode=tap,tapif=tap0,trans=mmio --vproxy
```

> If the lkvm run command fails with an error message similar to "Fatal: Guest init image not compiled in", please rerun it. The cause of this issue is under investigation.

**T3: Zephyr serial console**
```
telnet localhost 4321
```

**T4: PetaLinux SSH session**

```
ssh -oHostKeyAlgorithms=+ssh-rsa root@127.0.0.1 -p 30022
``` 
```
echo start >/sys/class/remoteproc/remoteproc0/state
```


In terminal T3 the Zephyr boot log should be visible:

```
device virtio1 @0x110e0
iobase 77000200
VIRTIO 4d564b4c:00000001
device virtio0 @0x110f8
iobase 77000000
VIRTIO 4d564b4c:00000004
virtio_rng_init()
*** Booting Zephyr OS build v2.7.99-776-gc69f841ea165  ***
Board: qemu_cortex_r5
random device is 0x11110, name is virt-rng
  0xaf
  0xd5
  0xcf
  0xba
  0xea
  0xfb
  0x89
  0x65
  0xc4
main:104 - get_entropy test passed
```

You can now interact with the Zephyr system using shell commands.

E.g. Show the network interface configuration on Zephyr and ping the back-end (PetaLinux) runtime.
```
uart:~$ device list
devices:
- sys_clock (READY)
- UART_1 (READY)
- rpu_0_ipi (READY)
- virtio1 (READY)
- virtio0 (READY)
- virt-rng (READY)
  requires: virtio0
- virt-net (READY)
  requires: virtio1
uart:~$ net iface

Interface 0x78109a70 (Ethernet) [1]
===================================
Link addr : 00:00:00:00:00:00
MTU       : 1500
Flags     : AUTO_START,IPv4
Ethernet capabilities supported:
IPv4 unicast addresses (max 1):
        192.168.200.2 manual preferred infinite
IPv4 multicast addresses (max 1):
        <none>
IPv4 gateway : 0.0.0.0
IPv4 netmask : 255.255.255.0
DHCPv4 lease time : 0
DHCPv4 renew time : 0
DHCPv4 server     : 0.0.0.0
DHCPv4 requested  : 0.0.0.0
DHCPv4 state      : disabled
DHCPv4 attempts   : 0

uart:~$ net ping -c 10 192.168.200.254
PING 192.168.200.254
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=0 ttl=64 time=1920 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=1 ttl=64 time=486 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=2 ttl=64 time=530 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=3 ttl=64 time=525 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=4 ttl=64 time=420 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=5 ttl=64 time=670 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=6 ttl=64 time=502 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=7 ttl=64 time=545 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=8 ttl=64 time=499 ms
28 bytes from 192.168.200.254 to 192.168.200.2: icmp_seq=9 ttl=64 time=454 ms
```

## Hypervisorless virtio binary demo (openamp/demo-lite)

A binary-only version of the hypervisorless virtio setup can be used in a containerized deployment based on the openamp/demo-lite image from Docker Hub.

```
you@your-machine:~$ docker run -it openamp/demo-lite
dev@openamp-demo:~$ qemu-zcu102 ./demo4
```

Let U-boot autoboot, don’t stop it. U-boot will tftp load uEnv.txt which will tftp load the kernel, dtb, and cpio.

Use root as user to login to the A53 terminal and then run the demo setup script.

```
root@generic-arm64:~# /hvl/setup.sh
```

The Physical Machine Monitor will start.

```
/hvl/lkvm run --debug --vxworks --rsld --pmm --debug-nohostfs --transport mmio --shmem-addr 0x37000000 --shmem-size 0x1000000 --cpus 1 --mem 128 --no-dtb --debug --rng --network mode=tap,tapif=tap0,trans=mmio --vproxy
  Info: (virtio/mmio.c) virtio_mmio_init:620: virtio-mmio.devices=0x200@0x37000000 [0x4d564b4c:0x4]
[   48.008155] IPv6: ADDRCONF(NETDEV_CHANGE): tap0: link becomes ready
  Info: (virtio/mmio.c) virtio_mmio_init:620: virtio-mmio.devices=0x200@0x37000200 [0x4d564b4c:0x1]
```

In the shell pane ssh into the QEMU machine and start the Zephyr instance on Cortex R5.
```
dev@openamp$ ssh qemu-zcu102
root@generic-arm64:~# echo start >/sys/class/remoteproc/remoteproc0/state
```

The Zephyr command shell will be available in the 2nd UART, R5_0. You can interact with the Zephyr system using the shell commands described in the previous section to validate virtio networking between the R5 and A53 runtimes.

You can terminate the PMM by issuing the following key sequence: **Ctrl+b Ctrl+b x**.
When you are ready to stop QEMU, from the QEMU pane input **Ctrl-A x** and the QEMU instance will terminate.
