#!/bin/bash

#set -x

XLNX_COMMON_PACKAGE=${XLNX_COMMON_PACKAGE:-/home/dan/workspaces/hvl_dl/xilinx-zynqmp-common-v2020.2.tar.gz}
XLNX_ZCU102_BSP=${XLNX_ZCU102_BSP:-/home/dan/workspaces/hvl_dl/xilinx-zcu102-v2020.2-final.bsp}

function check_status { if [ $1 != 0 ]; then echo "Error ${1} @ [${MY_NAME}:${2}]. EXIT" ; exit ${1};fi }
MY_NAME="$(basename $0)"
__SRCDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

HVL_WORKSPACE=${HVL_WORKSPACE:-hvlws}
mkdir -p $HVL_WORKSPACE
cd $HVL_WORKSPACE
check_status $? $LINENO
export HVL_WORKSPACE_PATH=$(realpath .)

echo "Using workspace $HVL_WORKSPACE"

mkdir -p $HVL_WORKSPACE_PATH/tftp
mkdir -p $HVL_WORKSPACE_PATH/sysroot
mkdir -p $HVL_WORKSPACE_PATH/target/hvl

if [ ! -f $XLNX_COMMON_PACKAGE ]; then
	echo "Download ZYNQMP common image v2020.2 from https://www.xilinx.com/member/forms/download/xef.html?filename=xilinx-zynqmp-common-v2020.2.tar.gz and update XLNX_COMMON_PACKAGE in $__SRCDIR/$MY_NAME"
	exit 1
fi

if [ ! -f $XLNX_ZCU102_BSP ]; then
	echo "Download ZCU102 BSP v2020.2 from https://www.xilinx.com/member/forms/download/xef.html?filename=xilinx-zcu102-v2020.2-final.bsp and update XLNX_ZCU102_BSP in $__SRCDIR/$MY_NAME"
	exit 1
fi

tar xzf $XLNX_COMMON_PACKAGE
check_status $? $LINENO

cp $XLNX_ZCU102_BSP $(basename $XLNX_ZCU102_BSP).tar.gz
tar xzf $(basename $XLNX_ZCU102_BSP).tar.gz
check_status $? $LINENO

rm $(basename $XLNX_ZCU102_BSP).tar.gz

cd $HVL_WORKSPACE_PATH/xilinx-zynqmp-common-v2020.2
(echo $HVL_WORKSPACE_PATH/petalinux/2020.2; echo Y) | ./sdk.sh

#qemu xilinx
cd $HVL_WORKSPACE
git clone https://github.com/Xilinx/qemu.git -b xilinx-v2021.1
check_status $? $LINENO

#workaround for sphinx-build version mismatch between zephyr and qemu zilinx
if [ -f $HOME/.local/bin/sphinx-build ]; then
	mv $HOME/.local/bin/sphinx-build $HOME/.local/bin/sphinx-build_tmp_bk
fi

rm -rf qemu_build
mkdir qemu_build
cd qemu_build
../qemu/configure --target-list="aarch64-softmmu,microblazeel-softmmu,arm-softmmu" \
--enable-debug --enable-fdt --disable-kvm \
--disable-vnc \
--prefix=$HVL_WORKSPACE_PATH/qemu_inst

check_status $? $LINENO

#make -j$(nproc)
make install -j$(nproc)
check_status $? $LINENO

#workaround for sphinx-build version mismatch between zephyr and qemu zilinx
if [ ! -f $HOME/.local/bin/sphinx-build ]; then
	if [ -f $HOME/.local/bin/sphinx-build_tmp_bk ]; then
		mv $HOME/.local/bin/sphinx-build_tmp_bk $HOME/.local/bin/sphinx-build
	fi
fi

cd $HVL_WORKSPACE
source $HVL_WORKSPACE_PATH/petalinux/2020.2/environment-setup-aarch64-xilinx-linux
which aarch64-xilinx-linux-gcc


#kernel xlnx
git clone https://github.com/Xilinx/linux-xlnx.git -b xilinx-v2020.2
cd linux-xlnx
check_status $? $LINENO

cp $__SRCDIR/util/config_hvl .config
CROSS_COMPILE=aarch64-xilinx-linux- ARCH=arm64 make olddefconfig
check_status $? $LINENO

sed -i 's%YYLTYPE yylloc%extern YYLTYPE yylloc%' scripts/dtc/dtc-lexer.l

CROSS_COMPILE=aarch64-xilinx-linux- ARCH=arm64 make -j$(nproc)
check_status $? $LINENO

CROSS_COMPILE=aarch64-xilinx-linux- ARCH=arm64 make modules_install INSTALL_MOD_PATH=$HVL_WORKSPACE_PATH/mod_install/ -j$(nproc)
check_status $? $LINENO

cp $HVL_WORKSPACE_PATH/linux-xlnx/arch/arm64/boot/Image $HVL_WORKSPACE/tftp/

source $HVL_WORKSPACE_PATH/petalinux/2020.2/environment-setup-aarch64-xilinx-linux
cd $HVL_WORKSPACE_PATH

#ZCU102 DTB
#system-user.dtsi
cp $__SRCDIR/util/system-user.dtsi $HVL_WORKSPACE_PATH/xilinx-zcu102-2020.2/components/plnx_workspace/device-tree/device-tree/
check_status $? $LINENO

cd $HVL_WORKSPACE_PATH/xilinx-zcu102-2020.2/components/plnx_workspace/device-tree/device-tree/
check_status $? $LINENO
gcc -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp system-top.dts -o dts.dts
dtc -I dts -O dtb dts.dts -o dtb.dtb
cp dtb.dtb $HVL_WORKSPACE_PATH/tftp

cd $HVL_WORKSPACE_PATH

#kvmtool
git clone https://github.com/dgibson/dtc.git
cd dtc
CROSS_COMPILE=aarch64-xilinx-linux- ARCH=arm64 make WARNINGS=-Wno-error NO_PYTHON=1 install PREFIX=$HVL_WORKSPACE_PATH/sysroot
check_status $? $LINENO

cd $HVL_WORKSPACE_PATH

git clone https://github.com/OpenAMP/kvmtool.git -b hvl-integration
check_status $? $LINENO
cd kvmtool
CROSS_COMPILE=aarch64-xilinx-linux- ARCH=arm64 HVL_WORKSPACE=$HVL_WORKSPACE_PATH make -j8
check_status $? $LINENO

cd user-mbox-rsld
make KDIR=$HVL_WORKSPACE_PATH/linux-xlnx
check_status $? $LINENO

cp $__SRCDIR/util/chr_setup.sh $HVL_WORKSPACE_PATH/target
check_status $? $LINENO

cp $HVL_WORKSPACE_PATH/kvmtool/lkvm $HVL_WORKSPACE_PATH/target/hvl/
check_status $? $LINENO

cp $HVL_WORKSPACE_PATH/kvmtool/user-mbox-rsld/user-mbox.ko $HVL_WORKSPACE_PATH/target/hvl/
check_status $? $LINENO

cp -a $HVL_WORKSPACE_PATH/sysroot/lib/ $HVL_WORKSPACE_PATH/target/
check_status $? $LINENO

cp -a $HVL_WORKSPACE_PATH/mod_install/lib $HVL_WORKSPACE_PATH/target/

#zephyr

cd $HVL_WORKSPACE_PATH
wget --no-check-certificate -c https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v0.13.2/zephyr-sdk-0.13.2-linux-x86_64-setup.run


cd $HVL_WORKSPACE_PATH
chmod +x zephyr-sdk-0.13.2-linux-x86_64-setup.run
./zephyr-sdk-0.13.2-linux-x86_64-setup.run -- -y -d $HVL_WORKSPACE_PATH/zephyr-sdk-0.13.2

export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR=$HVL_WORKSPACE_PATH/zephyr-sdk-0.13.2


west init -m https://github.com/OpenAMP/openamp-zephyr-staging.git --mr virtio-exp zephyrproject
cd zephyrproject
west update
west zephyr-export
pip3 install --user -r zephyr/scripts/requirements.txt

cd $HVL_WORKSPACE_PATH/zephyrproject

#filter petalinux host tools from PATH 
export PATH=$(echo $PATH | tr ':' '\n'|grep -v 'petalinux/2020'|tr '\n' ':')

west build -p auto -b qemu_cortex_r5 zephyr/samples/virtio/hvl_net_rng/

cp $HVL_WORKSPACE_PATH/zephyrproject/build/zephyr/zephyr.elf $HVL_WORKSPACE_PATH/target/hvl/
#S4


cd $HVL_WORKSPACE_PATH
mkdir -p $HVL_WORKSPACE_PATH/mnt

#sdcard
cp $HVL_WORKSPACE_PATH/xilinx-zcu102-2020.2/pre-built/linux/images/petalinux-sdimage.wic $HVL_WORKSPACE_PATH/linux-sd.wic
$HVL_WORKSPACE_PATH/qemu_inst/bin/qemu-img resize $HVL_WORKSPACE_PATH/linux-sd.wic 8G

#parted resizepart 2 100% $HVL_WORKSPACE_PATH/linux-sd.wic
#export SDLOOPDEV=$(basename $('"losetup |grep $HVL_WORKSPACE_PATH/linux-sd.wic|cut -d ' ' -f 1"' ))
#e2fsck -f /dev/mapper/${SDLOOPDEV}p2
#resize2fs /dev/mapper/${SDLOOPDEV}p2


#set +x


echo
echo "Complete file system setup"
echo "--------------------------"
echo "sudo kpartx -av $HVL_WORKSPACE_PATH/linux-sd.wic"
echo 'export SDLOOPDEV=$(basename $('"losetup |grep $HVL_WORKSPACE_PATH/linux-sd.wic|cut -d ' ' -f 1"' ))'
echo "sudo mount /dev/mapper/\${SDLOOPDEV}p2 $HVL_WORKSPACE_PATH/mnt"
echo "sudo cp -a $HVL_WORKSPACE_PATH/target/* $HVL_WORKSPACE_PATH/mnt/"
#echo "sudo cp -a $__SRCDIR/util/chr_setup.sh $HVL_WORKSPACE_PATH/mnt/"
echo "sudo chmod +x $HVL_WORKSPACE_PATH/mnt/chr_setup.sh"
echo "sudo chroot $HVL_WORKSPACE_PATH/mnt/ bash -c /chr_setup.sh"
echo "sudo umount $HVL_WORKSPACE_PATH/mnt"
echo "sudo kpartx -dv $HVL_WORKSPACE_PATH/linux-sd.wic"

echo 
echo "QEMU PMU"
echo "--------"
echo 'rm /tmp/qemu-memory-_*'
echo
echo "$HVL_WORKSPACE_PATH/qemu_inst/bin/qemu-system-microblazeel -M microblaze-fdt -nographic \
-dtb $HVL_WORKSPACE_PATH/xilinx-zcu102-2020.2/pre-built/linux/images/zynqmp-qemu-multiarch-pmu.dtb \
-kernel $HVL_WORKSPACE_PATH/xilinx-zcu102-2020.2/pre-built/linux/images/pmu_rom_qemu_sha3.elf \
-device loader,file=$HVL_WORKSPACE_PATH/xilinx-zcu102-2020.2/pre-built/linux/images/pmufw.elf -machine-path /tmp
"

#2
echo "PETALINUX (A53)"
echo "---------------"
echo "
$HVL_WORKSPACE_PATH/qemu_inst/bin/qemu-system-aarch64 -M arm-generic-fdt \
-dtb $HVL_WORKSPACE_PATH/xilinx-zcu102-2020.2/pre-built/linux/images/zynqmp-qemu-multiarch-arm.dtb \
-device loader,file=$HVL_WORKSPACE_PATH/xilinx-zcu102-2020.2/pre-built/linux/images/bl31.elf,cpu-num=0 \
-global xlnx,zynqmp-boot.cpu-num=0 -global xlnx,zynqmp-boot.use-pmufw=true -machine-path /tmp -net nic -net nic -net nic -net nic \
-net user,tftp=$HVL_WORKSPACE_PATH/tftp,hostfwd=tcp::30022-:22 \
-serial mon:stdio -m 4G --nographic -serial telnet:localhost:4321,server,wait=off -echr 2 \
-drive file=$HVL_WORKSPACE_PATH/linux-sd.wic,if=sd,format=raw,index=1 \
-device loader,file=$HVL_WORKSPACE_PATH/xilinx-zcu102-2020.2/pre-built/linux/images/u-boot.elf
"

echo "U-Boot configuration: "
echo '
setenv bootargs "earlycon clk_ignore_unused root=/dev/mmcblk0p2 ro rootwait earlyprintk debug uio_pdrv_genirq.of_id=generic-uio";
dhcp 200000 Image; dhcp 100000 dtb.dtb;
setenv initrd_high 78000000; booti 200000 - 100000;
'

echo '
After booting, Linux on A53 can also be accessed as:
ssh root@localhost -p 30022
'

#/home/dan/projects/cto/appstar/src/zynq_ipi/hvl/binaries/u-boot_d1.elf

echo "Zephyr (R5)"
echo "-----------"
echo 'telnet localhost 4321'

exit 0


