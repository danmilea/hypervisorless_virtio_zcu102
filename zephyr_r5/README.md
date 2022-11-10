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
dtc -I dts -O dtb oa.dts > oa.dtb
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
cp /home/petalinux/zephyr/zephyr.elf /lib/firmware/
echo zephyr.elf >/sys/class/remoteproc/remoteproc0/firmware
echo start >/sys/class/remoteproc/remoteproc0/state
```

The Zephyr application console will be available on ZCU102 UART1.

**Note:**
> Reproducing this in a different Zephyr environment would most likely only require the updated device tree file (oa.dts) used when booting Petalinux and the Zephyr device tree overlay to enable UART1.

## Binary size issue for recent Zephyr sources

You may encounter an issue when trying to start the hello app built in recent Zephyr environments (HEAD newer than 7ef05751a3f34030eb06dace23e357d10b33f460).

```
xilinx-zcu102-20221:/home/petalinux# echo start >/sys/class/remoteproc/remoteproc0/state
[  111.353903] remoteproc remoteproc0: powering up ff9a0000.rf5ss:r5f_0
[  111.361936] remoteproc remoteproc0: Booting fw image zephyr.elf, size 2073644
[  111.375897] remoteproc remoteproc0: no resource table found.
[  111.381645] remoteproc remoteproc0: bad phdr da 0xcf80 mem 0x196e8
[  111.387836] remoteproc remoteproc0: Failed to load program segments: -22
[  111.394844] remoteproc remoteproc0: Boot failed: -22
sh: echo: write error: Invalid argument
```

In this case apply the **zephyr_zcu102_r5.patch** patch on your Zephyr source tree and edit **hello_r5/prj_qemu_cortex_r5.conf** to enable the 3 configuration items which are disabled in the default configuration.
```
CONFIG_HAVE_CUSTOM_LINKER_SCRIPT=y
CONFIG_CUSTOM_LINKER_SCRIPT="linker_r5_hvl.ld"
CONFIG_SHELL_BACKEND_SERIAL_INTERRUPT_DRIVEN=n
```

This updated configuration will relocate the text section to memory area located at 0x38000000 and reserved in oa.dts.





