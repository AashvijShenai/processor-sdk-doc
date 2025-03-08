
#To reload module: remove it and load it
#WARNING: Seems as though imx219 does not load properly due to dependencies so just reboot properly
modprobe -r j721e-csi2rx
modprobe j721e-csi2rx

#When making changes to driver: Build Image and dtbs once and then only build modules and scp
#Ensure cross-compile path is exported in PATH, ip address and linux versions are correct
make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- Image dtbs modules -j16

scp -oHostKeyAlgorithms=+ssh-rsa drivers/media/platform/ti/j721e-csi2rx/j721e-csi2rx.ko root@172.24.147.100:/lib/modules/5.10.158-gd0ecf0bb93/kernel/drivers/media/platform/ti/j721e-csi2rx/

sudo make ARCH=arm64 CROSS_COMPILE=aarch64-none-linux-gnu- INSTALL_MOD_PATH=/media/aashvij/rootfs1/ modules_install


####################################################
#MTD
root@am62xx-evm:~ cat /proc/mtd
[2023-02-13 14:34:29.704] dev:    size   erasesize  name
[2023-02-13 14:34:29.704] mtd0: 00080000 00040000 "ospi.tiboot3"
[2023-02-13 14:34:29.704] mtd1: 00200000 00040000 "ospi.tispl"
[2023-02-13 14:34:29.704] mtd2: 00400000 00040000 "ospi.u-boot"
[2023-02-13 14:34:29.704] mtd3: 00040000 00040000 "ospi.env"
[2023-02-13 14:34:29.720] mtd4: 00040000 00040000 "ospi.env.backup"
[2023-02-13 14:34:29.720] mtd5: 037c0000 00040000 "ospi.rootfs"
[2023-02-13 14:34:29.720] mtd6: 00040000 00040000 "ospi.phypattern"

# https://software-dl.ti.com/jacinto7/esd/processor-sdk-linux-jacinto7/latest/exports/docs/linux/Foundational_Components/Kernel/Kernel_Drivers/QSPI.html - UBIFS



################
To build def config in ti-linux-kernel -> this builds whatever is saved as defconfig

ti-linux-kernel$ ./ti_config_fragments/defconfig_builder.sh

####################
To load other dtbs:
You can change it in uboot/include/configs/am62x_evm.h
OR
write "name_fdt=k3-am625-skeleton.dtb" in uEnv.txt

##############
https://software-dl.ti.com/processor-sdk-linux/esd/AM62X/latest/exports/docs/linux/Foundational_Components/U-Boot/UG-QSPI.html

# For NOR
sf probe
fatload mmc 1 $loadaddr tiboot3.bin
sf update $loadaddr 0x0 $filesize
fatload mmc 1 $loadaddr tispl.bin
sf update $loadaddr 0x80000 $filesize

fatload mmc 1 $loadaddr u-boot.img
sf update $loadaddr 0x280000 $filesize
fatload mmc 1 $loadaddr ospi_phy_pattern
sf update $loadaddr 0x3fc0000 $filesize

tftp $loadaddr stage1.image
sf update $loadaddr 0x0 $filesize
tftp $loadaddr stage2.image
sf update $loadaddr 0x80000 $filesize

fatload mmc 1 $loadaddr fast_xspi_pattern_166M.bin
sf update $loadaddr 0x3fc0000 $filesize

tftp $loadaddr mcan.image
sf update $loadaddr 0x800000 $filesize
tftp $loadaddr hsm.image
sf update $loadaddr 0x240000 $filesize
tftp $loadaddr ipc.image
sf update $loadaddr 0xC0000 $filesize
tftp $loadaddr c7x.image
sf update $loadaddr 0xA00000 $filesize

tftp $loadaddr am62x/linux.appimage
sf update $loadaddr 0xC00000 $filesize  # AM62

tftp $loadaddr linux.appimage
sf update $loadaddr 0x1200000 $filesize # AM62A, 62P

mw.w 0x43000030 0xfff3  //NOR
mw.w 0x43000030 0xff6b  //Fast XSPI
mw.w 0x43000030 0x0243  //SD
mw.w 0x43000030 0x003B //UART
reset

tftp $loadaddr am62x/ipc_r5.image
sf update $loadaddr 0xA00000 $filesize
tftp $loadaddr am62x/ipc_m4.image
sf update $loadaddr 0x100000 $filesize
tftp $loadaddr am62x/hsm.appimage
sf update $loadaddr 0x800000 $filesize

setenv x "sf probe;tftp $loadaddr stage1.image;sf update $loadaddr 0x0 \${filesize};tftp $loadaddr stage2.image;sf update $loadaddr 0x80000 \${filesize};tftp $loadaddr mcan.image;sf update $loadaddr 0x800000 \${filesize};tftp $loadaddr hsm.image;sf update $loadaddr 0x240000 \${filesize};tftp $loadaddr ipc.image;sf update $loadaddr 0xC0000 \${filesize};tftp $loadaddr c7x.image;sf update $loadaddr 0xA00000 \${filesize};tftp $loadaddr linux.appimage;sf update $loadaddr 0x1200000 \${filesize};tftp $loadaddr stage1.image;sf update $loadaddr 0x0 \${filesize};mw.w 0x43000030 0xff6b;reset"

# For NAND
# Partitions ospi.tiboot3 do not work
mtd erase.dontskip spi-nand0
fatload mmc 1 $loadaddr tiboot3_falcon.bin
tftp ${loadaddr} stage1.image
mtd write spi-nand0 ${loadaddr} 0 ${filesize}
fatload mmc 1 $loadaddr tispl_falcon.bin
mtd write spi-nand0 $loadaddr 0x80000 $filesize
fatload mmc 1 $loadaddr linux.appimage.hs
mtd write spi-nand0 $loadaddr 0x1200000 $filesize

mtd write spi-nand0 $loadaddr 0x0 $filesize
mtd write spi-nand0 $loadaddr 0x80000 $filesize

mtd dump spi-nand0 0x80000 0x10

fatload mmc 1 $loadaddr u-boot_prebuilt.img
sf update $loadaddr 0x280000 $filesize
mtd write spi-nand0 $loadaddr 0x280000 $filesize


# Comparing nor flash contents
sf probe
fatload mmc 1 $loadaddr tiboot3.bin    #355601 bytes read in 19 ms (17.8 MiB/s)
sf update $loadaddr 0x0 $filesize

sf read 0x90000000 0x0 $filesize
cmp.b $loadaddr 0x90000000 $filesize

md.b 0x82000000 0x200
md.b 0x90000000 0x200

####BUILD OPTEE
make -j14 CROSS_COMPILE64=aarch64-none-linux-gnu- PLATFORM=k3-am62x CFG_ARM64_core=y CFG_TEE_CORE_LOG_LEVEL=1 CFG_TEE_CORE_DEBUG=y CFG_WITH_SOFTWARE_PRNG=y CROSS_COMPILE=arm-none-linux-gnueabihf-

## U-boot part uuid
part uuid mmc 0:1
5b874f4c-01
part uuid mmc 0:2
5b874f4c-02
part uuid mmc 1:2


[2023-04-13 10:56:11.886] /dev/mmcblk0p1: UUID="06ff0fb5-d265-4783-b9f4-99ac15ccd0e0" BLOCK_SIZE="4096" TYPE="ext2" PARTUUID="3565a360-01"
[2023-04-13 10:56:11.902] /dev/mmcblk1p1: SEC_TYPE="msdos" LABEL_FATBOOT="boot" LABEL="boot" UUID="E419-6E8B" BLOCK_SIZE="512" TYPE="vfat" PARTUUID="0d52f5b8-01"
[2023-04-13 10:56:11.902] /dev/mmcblk1p2: LABEL="root" UUID="63049289-e977-45d8-be26-8905f077298f" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="0d52f5b8-02"


# Check certificate of binary
openssl asn1parse -inform DER -in sbl_ospi_linux_stage1.debug.tiimage


# To Unlock JTAG on HSSE
./dbgauth -c ~/.ti/ccs1220/0/0/BrdDat/ccBoard0.dat \
        -x xds110 \
        -s cs_dap_0 \
        -o unlock \
        -m 3 \
        -f ~/workspace/mcusdk/unlock_jtag.cert

./dbgauth -c ~/.ti/ccs1220/0/0/BrdDat/ccBoard0.dat \
        -x xds110 \
        -s cs_dap_0 \
        -o getuid \
        -m 3



# Mount full filesystem after initramfs
1. under init:
#!/bin/sh

mount -t proc none /proc
mount -t sysfs none /sys

sleep 5

mount -t devtmpfs  dev  /dev

ls /dev/ >> /tmp/log 2>&1
echo "ls dev" $? >> /dev/ttyS2

ls /dev/mmcblk1p2 >> /tmp/log 2>&1

# If /dev/mmcblk is not enumerated
# 179 and 96 is major and minor number obtained from ls -al /dev/block
# mknod /dev/mmcblk1 b 179 96 
# mknod /dev/mmcblk1p1 b 179 97
# mknod /dev/mmcblk1p2 b 179 98

# Mount might not have the right permissions since it would require sudo but in smaller filesystems might not exist
# chown root:root /usr/bin/mount.util-linux
mount /dev/mmcblk1p2 /mnt/
echo "Mount FS:" $? >> /dev/ttyS2

umount /proc
umount /sys

exec switch_root /mnt/ /sbin/init

# exec /sbin/init $*

2. mksquashfs
3. change ospi partition for rootfs
3. mount /dev/mtdblock5 /mnt/
4. switch root



##### Drop cache in linux
echo 1 > /proc/sys/vm/drop_caches

dd if=/mnt/data of=/dev/null bs=40M count=1
dd if=/dev/mtd1 of=/tmp/test bs=4M


root@am62xx-evm:/# dd if=/dev/mtd1 of=/tmp/test bs=4M
38535168 bytes (39 MB, 37 MiB) copied, 0.27403 s, 141 MB/s
root@am62xx-evm:/# mount -t squashfs /tmp/test /mnt/ -o loop


#Static compile modetest
 - Boot into debian by adding nfsroot in uEnv.txt
        (Original)    args_mmc=run finduuid;setenv bootargs console=${console} ${optargs} root=PARTUUID=${uuid} rw rootfstype=${mmcrootfstype}

        (Modify) setenv args_mmc 'setenv bootargs console=ttyS2,115200n8 root=/dev/nfs rw nfsroot=172.24.238.35:/datalocal/Sekhar/filesystem/debian-arm64,nfsvers=3 ip=dhcp'
 - git clone the drm repo (https://gitlab.freedesktop.org/mesa/drm)
 - cc  -o tests/modetest/modetest tests/modetest/modetest.p/buffers.c.o tests/modetest/modetest.p/cursor.c.o tests/modetest/modetest.p/modetest.c.o -Wl,--as-needed -Wl,--no-undefined '-Wl,-rpath,$ORIGIN/../..' -Wl,-rpath-link,/root/drm/drm/builddir/ -Wl,--start-group libdrm.so.2.4.0 tests/util/libutil.a -Wl,--end-group -pthread


 cc -Itests/modetest/modetest.p -Itests/modetest -I../tests/modetest -I. -I.. -Itests -I../tests -I../include/drm -fdiagnostics-color=always -D_FILE_OFFSET_BITS=64 -Wall -Winvalid-pch -std=c11 -O2 -g -include config.h -pthread -Wsign-compare -Werror=undef -Werror=implicit-function-declaration -Wpointer-arith -Wwrite-strings -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wnested-externs -Wpacked -Wswitch-enum -Wmissing-format-attribute -Wstrict-aliasing=2 -Winit-self -Winline -Wshadow -Wdeclaration-after-statement -Wold-style-definition -Wno-unused-parameter -Wno-attributes -Wno-long-long -Wno-missing-field-initializers -Wno-pointer-arith -static -MD -MQ tests/modetest/modetest.p/modetest.c.o -MF tests/modetest/modetest.p/modetest.c.o.d -o tests/modetest/modetest.p/modetest.c.o -c ../tests/modetest/modetest.c


cc  -o tests/modetest/modetest tests/modetest/modetest.p/buffers.c.o tests/modetest/modetest.p/cursor.c.o tests/modetest/modetest.p/modetest.c.o -Wl,--as-needed -Wl,--no-undefined '-Wl,-rpath,$ORIGIN/../..' -Wl,-rpath-link,/root/drm/drm/builddir/ -Wl,--start-group libdrm.so.2.4.0 tests/util/libutil.a -Wl,--end-group -pthread

cc  -o tests/modetest/modetest tests/modetest/modetest.p/buffers.c.o tests/modetest/modetest.p/cursor.c.o tests/modetest/modetest.p/modetest.c.o -Wl,--as-needed -Wl,--no-undefined '-Wl,-rpath,$ORIGIN/../..' -Wl,-rpath-link,/root/drm/drm/builddir/ /usr/lib/aarch64-linux-gnu/libdrm.a tests/util/libutil.a -pthread -static



# Mount squashfs

dd if=/zkw.img of=/dev/mtd1

dd if=/dev/mtd1 of=/tmp/data bs=40M count=1
mount -t squashfs /tmp/data /mnt/ -o loop

find /mnt/ -type f | xargs cat > /dev/null


#UBI
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs  dev  /dev

#modetest -M tidss -s 39@37:1920x1200 &
#modetest -M tidss -s 40@38:1920x1200 &

echo "ubistart" >> /dev/ttyS2
ubiattach -p /dev/mtd1 >> /tmp/log 2>&1

mount -o no_chk_data_crc,bulk_read -t ubifs ubi0:flash_fs /mnt/ >> /tmp/log 2>&1
echo "ubimount" >> /dev/ttyS2

dd if=/mnt/data of=/dev/null bs=40M
echo "dd" >> /dev/ttyS2


# Run linux image without transferring to SD card via TFTP
setenv x "setenv ipaddr 192.168.0.110;setenv bootargs 'console=ttyS2,115200n8 fsck.mode=skip sysrq_always_enabled loglevel=10'; tftp 0x82000000 10.24.68.154:am62px/Image;tftp 0x88000000 10.24.68.154:am62px/dtb; fdt address 0x88000000; booti 0x82000000 - 0x88000000"

setenv x "setenv ipaddr 192.168.0.110;setenv bootargs 'console=ttyS2,115200n8 fsck.mode=skip sysrq_always_enabled loglevel=10 root=/dev/mmcblk1p2 rootwait init=/sbin/init'; tftp 0x82000000 10.24.68.154:am62px/Image;tftp 0x88000000 10.24.68.154:am62px/dtb; fdt address 0x88000000; booti 0x82000000 - 0x88000000"

setenv x "dhcp;setenv bootargs 'console=ttyS2,115200n8 init=/init'; tftp ${loadaddr} 10.24.68.154:am62px/Image;tftp ${fdt_addr_r} 10.24.68.154:am62px/dtb; fdt address ${fdt_addr_r}; booti ${loadaddr} - ${fdt_addr_r}"

setenv x "setenv ipaddr 192.168.0.110;setenv bootargs 'console=ttyS2,115200n8 fsck.mode=skip sysrq_always_enabled quiet'; tftp 0x82000000 10.24.68.154:am62px/Image;tftp 0x88000000 10.24.68.154:am62px/dtb;tftp 0x90000000 10.24.68.154:am62px/tinfy_8.6.cpio; fdt address 0x88000000;booti 0x82000000 0x90000000:0x101da00 0x88000000;"

setenv x "setenv ipaddr 192.168.0.110;setenv bootargs 'console=ttyS2,115200n8 fsck.mode=skip sysrq_always_enabled quiet'; tftp 0x82000000 10.24.68.154:am62px/Image;tftp 0x88000000 10.24.68.154:am62px/dtb; fdt address 0x88000000;booti 0x82000000 - 0x88000000;"

setenv x "setenv ipaddr 192.168.0.110;setenv bootargs 'console=ttyS2,115200n8 fsck.mode=skip sysrq_always_enabled loglevel=10'; tftp 0x82000000 10.24.68.154:am62px/Image;tftp 0x88000000 10.24.68.154:am62px/dtb; fdt address 0x88000000;booti 0x82000000 - 0x88000000;"

run x

booti 0x82000000 0x90000000:${filesize} 0x88000000

# FS Trials
_ cp /home/aashvij/workspace/SDK/tisdk/build/deploy-ti/images/am62xx-evm/tisdk-tiny-initramfs-am62xx-evm.cpio /home/aashvij/workspace/tftp/am62px/sdk_fs

setenv x "setenv ipaddr 192.168.0.110;setenv bootargs 'console=ttyS2,115200n8 fsck.mode=skip sysrq_always_enabled quiet'; tftp 0x82000000 10.24.68.154:am62px/Image_noRamfs;tftp 0x88000000 10.24.68.154:am62px/dtb;tftp 0x90000000 10.24.68.154:am62px/sdk_fs; fdt address 0x88000000;";
run x;
booti 0x82000000 0x90000000:${filesize} 0x88000000


## Create cpio archive
# Have to go inside the directory
_ find . | sort | cpio --reproducible -o -H newc -R root:root > ~/workspace/tftp/am62px/sdk_fs


# Building Yocto Filesystem
https://software-dl.ti.com/processor-sdk-linux-rt/esd/AM62PX/latest/exports/docs/linux/Overview_Building_the_SDK.html

MACHINE=am62pxx-evm bitbake -k core-image-minimal

# Change dmesg buffer length
setenv args_all $args_all log_buf_len=5M


# Modify busybox config

bitbake -c menuconfig busybmw.w 0x43000030 0x0243ox (edit config)
    
bitbake -c diffconfig busybox (this generates a config fragment, note the fragment file location)

recipetool appendsrcfile -w [path to layer] busybox [path to fragment generated in step #2] or just copy?

# Edit recipes-core/busybox/busybox_%.bbappend to include fragment



# Authen boot
#!/bin/sh

sleep 5 #For mmcblk1 to populate
chown root:root /bin/mount.util-linux

/bin/mount -t devtmpfs none /dev
/bin/mount -t proc none /proc
/bin/mount -t sysfs none /sys

/sbin/cryptsetup luksOpen --key-file=/home/keyfile /dev/mmcblk1p4 crypt_root >/dev/ttyS2 >/dev/ttyS2

sleep 5
/sbin/veritysetup open /dev/mapper/crypt_root verity_root /dev/mmcblk1p3 314bacbbd635174ef6bd35fa2f7a839853967aab110064be52431b2aaf4e36f4 >/dev/ttyS2 2>/dev/ttyS2
sleep 10

mount -o ro /dev/mapper/verity_root /mnt >/dev/ttyS2 2>/dev/ttyS2
exec /sbin/init $*
# exec switch_root /mnt/ /sbin/init

# chown root:root /usr/bin/mount.util-linux
# mount /dev/mmcblk1p2 /mnt

# umount /proc
# umount /sys

# exec switch_root /mnt/ /sbin/init

