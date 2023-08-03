run: u-boot/u-boot.rom sda.dd
	#(sleep 1 ; echo "" ; echo "ide reset" ; echo "ext4load ide 0:1 $${kernel_addr_r} /boot/vmlinuz-6.5.0-rc3-00044-g0a8db05b571a") | qemu-system-x86_64 -bios u-boot/u-boot.rom -nographic -drive file=sda.dd,format=raw,if=ide
	(sleep 1 ; /bin/echo '-ide reset ; ext4load ide 0:1 $${kernel_addr_r} /boot/vmlinuz-6.5.0-rc3-00044-g0a8db05b571a ; setenv bootargs console=ttyS0 ;  zboot $${kernel_addr_r}') | qemu-system-x86_64 -bios u-boot/u-boot.rom -nographic -drive file=sda.dd,format=raw

run-gdb-linux-debug: linux/vmlinux linux/vmlinux-debug
	gdb -ex 'target remote :1234' -ex 'hbreak start_kernel'  -ex 'c' $<

run-cpio-debug-ac97: rootfs.cpio.gz  linux/vmlinux-debug
	qemu-system-x86_64 -s -S -nographic -enable-kvm -kernel linux/arch/x86_64/boot/bzImage -initrd $< -append 'nokaslr console=ttyS0 rdinit=/bin/sh' -device AC97

run-cpio-debug: rootfs.cpio.gz  linux/vmlinux-debug
	qemu-system-x86_64 -s -S -nographic -enable-kvm -kernel linux/arch/x86_64/boot/bzImage -initrd $< -append 'nokaslr console=ttyS0 rdinit=/bin/sh'

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
	make -C linux INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH=$${PWD}/$@ modules_install

rootfs.cpio.gz: rootfs
	(cd $<; find . | cpio -o -H newc | gzip) > $@

sda.dd: rootfs
	SIZE=$$(($$(du -s $</ | awk  '{print $$1}') + 3000)); \
	dd if=/dev/zero of=$@ bs=1024 count=$$SIZE
	/bin/echo -e "n\n\n\n\n\nw" | /sbin/fdisk $@
	/sbin/mkfs.ext4 $@ -E offset=$$(( 512 * 2048 )) -d $<

linux/vmlinux-debug: linux-debug-defconfig
	cp $< linux/.config
	make -C linux olddefconfig
	make -C linux -j$$(nproc)
	make -C linux  scripts_gdb
	touch linux/vmlinux-debug

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
