# How to run a Zephyr application on Xilinx ZCU102 Cortex R5 

## Downloads

 - ZYNQMP common image (xilinx-zynqmp-common-v2022.1_04191534.tar.gz)
 - ZCU 102 BSP (xilinx-zcu102-v2022.1-04191534.bsp)

https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/embedded-design-tools.html

## Petalinux ZCU102 binaries

### Root file system

Unpack xilinx-zcu102-v2022.1-04191534.bsp (this is a gzipped tar archive) and xilinx-zynqmp-common-v2022.1_04191534.tar.gz

Flash **xilinx-zcu102-2022.1/pre-built/linux/images/petalinux-sdimage.wic** 
to an SD card.

### Kernel image

The kernel image is **xilinx-zynqmp-common-v2022.1/Image**.

### Device tree binary

The device tree file oa.dts is derived from **xilinx-zcu102-2022.1/pre-built/linux/images/openamp.dtb** with all uart1 entries removed.

```
dtc -I oa.dts -O dtb oa.dts > oa.dtb
```

## Zephyr application

The zephyr kernel image is based on the hello_world sample with a device tree overlay which enables UART1 for Zephyr output.

Build **hello_r5** in your Zephyr environment and copy the resulting zephyr.elf file to your target's root file system.

```
west build -p -b qemu_cortex_r5 zephyr/samples/hello_r5
```

**Zephyr source tree tree information**

    commit 7dfdd5dcd5c9a2315001ca412cc848772a687e1a (origin/main, origin/HEAD)
    Author: Martí Bolívar <marti.bolivar@nordicsemi.no>
    Date:   Fri Apr 8 09:25:49 2022 -0700



## ZCU102 boot sequence & Zephyr application deployment 

```
setenv serverip 128.224.125.159
setenv bootargs "earlycon clk_ignore_unused root=/dev/mmcblk0p2 ro rootwait earlyprintk debug uio_pdrv_genirq.of_id=generic-uio";
dhcp 200000 hvlws/zcu102_2022.1/Image
dhcp 100000 hvlws/zcu102_2022.1/oa.dtb
booti 200000 - 100000;
```

### Start zephyr on R5 CPU core 0 in the Petalinux environment

```
cp /home/petalinux/zephyr/zephyr_hello_u1_shell.elf /lib/firmware/
echo zephyr_hello_u1_shell.elf >/sys/class/remoteproc/remoteproc0/firmware
echo start >/sys/class/remoteproc/remoteproc0/state
```

The Zephyr application console will be available on ZCU102 UART1.

**Note:**
> Reproducing this in a different Zephyr environment would most likely only require the updated device tree file (oa.dts) used when booting Petalinux and the Zephyr device tree overlay to enable UART1.








