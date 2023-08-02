run: u-boot/u-boot.rom sda.dd
	#(sleep 1 ; echo "" ; echo "ide reset" ; echo "ext4load ide 0:1 $${kernel_addr_r} /boot/vmlinuz-6.5.0-rc3-00044-g0a8db05b571a") | qemu-system-x86_64 -bios u-boot/u-boot.rom -nographic -drive file=sda.dd,format=raw,if=ide
	(sleep 1 ; /bin/echo '-ide reset ; ext4load ide 0:1 $${kernel_addr_r} /boot/vmlinuz-6.5.0-rc3-00044-g0a8db05b571a ; setenv bootargs console=ttyS0 ;  zboot $${kernel_addr_r}') | qemu-system-x86_64 -bios u-boot/u-boot.rom -nographic -drive file=sda.dd,format=raw

run-cpio: rootfs.cpio.gz
	qemu-system-x86_64 -nographic -enable-kvm -kernel linux/arch/x86_64/boot/bzImage -initrd $< -append 'console=ttyS0 rdinit=/bin/sh'

run-sda-dd: sda.dd
	qemu-system-x86_64 -nographic -enable-kvm -kernel linux/arch/x86_64/boot/bzImage -drive file=$<,format=raw,if=ide -append 'console=ttyS0 init=/bin/sh root=/dev/sda1'

u-boot/u-boot.rom:
	make -C u-boot qemu-x86_64_defconfig
	make -C u-boot -j$$(nproc)

rootfs: busybox/_install/bin/sh linux/vmlinux
	mkdir -p $@/dev $@/tmp $@/proc
	cp -a busybox/_install/* $@/
	FILES=$$(ldd busybox/_install/bin/busybox | sed -e 's@^[^/]*\([^ ]*\) .*@\1@g' | grep .); \
	for file in $$FILES ; do \
	  mkdir -p $@/$$(dirname $$file); \
	  cp $$file $@/$$(dirname $$file)/; \
	done
	make -C linux INSTALL_MOD_STRIP=--strip-all INSTALL_MOD_PATH=$${PWD}/$@ modules_install

rootfs.cpio.gz: rootfs
	(cd $<; find . | cpio -o -H newc | gzip) > $@

sda.dd: rootfs
	SIZE=$$(($$(du -s $</ | awk  '{print $$1}') + 5000)); \
	dd if=/dev/zero of=$@ bs=1024 count=$$SIZE
	( echo "n" ; echo "" ;  echo "" ;  echo "" ;  echo "" ;  echo "w" ) | /sbin/fdisk $@
	/sbin/mkfs.ext4 $@ -E offset=$$(( 512 * 2048 )) -d $<

linux/vmlinux:
	make -C linux x86_64_defconfig
	make -C linux -j$$(nproc)

busybox/_install/bin/sh:
	make -C busybox defconfig
	make -C busybox -j$$(nproc)
	make -C busybox install

clean:
	git -C u-boot clean -xdf
	git -C busybox clean -xdf
	git -C linux clean -xdf
	git clean -xdf
	rm -Rf rootfs sda.dd rootfs.cpio.gz
