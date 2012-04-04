DISTDIR		= liab6I-ARM
LIABVERSION	= $(DISTDIR)_build-$(shell svnversion . | tr : -)
KERNELVERSION	= 2.6.29.4
PATCH		=
KERNELCONFIG 	= liabsg-$(KERNELVERSION).config
DISKSRC 	= disksrc
MODULESDIR 	= $(DISKSRC)/liabarmdist_base/lib/modules/$(KERNELVERSION)
LIAB		= liab

BOOTDIR=$(DISTDIR)/software/liabboot
DISKDIR=$(DISTDIR)/software/liabdisc
KERNDIR=$(DISTDIR)/software/liabkernel
INSTDIR=$(DISTDIR)/software/liabinstall

VERSIONFILE=liab_version

SHELL = /bin/sh
export LIABVERSION SHELL
# Use crosscompiler included in distribution:
export PATH := $(PWD)/$(DISTDIR)/software/crosscompiler/opt/crosstool/gcc-4.0.2-glibc-2.3.6/arm-unknown-linux-gnu/bin:$(PATH)

# Ensure same lang as this will affect disc making
export LANG=C
# Sudo compat
SUDO = sudo env LANG=C PATH=$(PATH)

default:
	@echo ""
	@echo "LIAB Linux software distribution"
	@echo "Type 'make all' unless you know what you are doing"
	@echo "(Requires sudo(8) to work)"
	@echo ""
	@echo "make kernel	- Create liabboot/uuencoded_vmlinux"
	@echo "make modules	- Create linux and liab kernel-modules"
	@echo "make progs	- Compile liabprogs and copy to liabdisk"
	@echo "make disk	- Create liabboot/uuencoded_diskimage"
	@echo "make jffs2	- Create liabdisk/jffs2.tgz"
	@echo "make firmware	- Create liabinstall/firmware.img"
	@echo ""
	@echo "make all      	- All of the above"
	@echo ""
	@echo "make distclean	- Remove all generated files"
	@echo ""
	@echo " - (C) 2012 LIAB ApS"
	@echo ""

kernel:
	@echo PATH=$(PATH)
#	Make vmlinux
	$(MAKE) -C $(KERNDIR) all
	cd $(BOOTDIR) ; ./mkkernel
	mv $(BOOTDIR)/v $(BOOTDIR)/uuencoded_vmlinux
	mkdir -p $(INSTDIR)/images/
	mv $(BOOTDIR)/vmlinux.bin.gz $(INSTDIR)/images/

modules:
#	Make kernel modules
	-rm -rf $(MODULESDIR)
	mkdir -p $(MODULESDIR)
	-rm -rf $(KERNDIR)/kernelmodules/lib
	$(MAKE) -C $(KERNDIR)/linux modules modules_install INSTALL_MOD_PATH=$(PWD)/$(KERNDIR)/kernelmodules/lib

#	Make additional liab kernel modules
	$(MAKE) -C $(KERNDIR)/liab-modules

#	Copy modules to installation
	find $(KERNDIR)/kernelmodules/ -name \*.ko -exec cp \{\} $(MODULESDIR)/ \;
	find $(KERNDIR)/liab-modules/ -name \*.ko -exec cp \{\} $(MODULESDIR)/ \;

# module dependencies
	cd	$(DISKSRC)/liabarmdist_base ; $(SUDO) depmod -b . $(KERNELVERSION)
	$(SUDO)	$(DISKSRC)/deppath.sh	$(MODULESDIR)/modules.dep $(KERNELVERSION) > $(MODULESDIR)/modules.dep.tmp
	$(SUDO) mv $(MODULESDIR)/modules.dep.tmp $(MODULESDIR)/modules.dep

disk:
# Generate distribution from deb-packages
	$(SUDO) rm -fr $(DISKDIR)/libc6
	$(SUDO) $(MAKE) -C $(DISKSRC)
	$(SUDO) mv $(DISKSRC)/libc6 $(DISKDIR)/libc6
	$(SUDO) cp $(INSTDIR)/usb_update.sh $(DISKDIR)/libc6/usr/sbin
	$(SUDO) cp $(INSTDIR)/update_firmware.sh $(DISKDIR)/libc6/usr/sbin
	$(SUDO) echo "$(LIABVERSION)" > /tmp/$(VERSIONFILE)
	$(SUDO) cp /tmp/$(VERSIONFILE) $(DISKDIR)/libc6/etc/
# Make disk image
	cd $(DISKDIR) ; $(SUDO) ./mkfpromimage
	cd $(BOOTDIR) ; ./mkdisc
	mv $(BOOTDIR)/d $(BOOTDIR)/uuencoded_discimage
	$(SUDO) mv $(DISKDIR)/initrd.gz $(INSTDIR)/images/

jffs2:
# Make jffs2 image
	cd $(DISKDIR) ; $(SUDO) ./mkflashtarball
	cp $(DISKDIR)/flash.tar.gz $(INSTDIR)/images/

firmware:
#	Make full firmware image
	cd $(BOOTDIR) ; ./mkkernel.sg
	cd $(INSTDIR) ; ./mkflashimage ; ./mkinstallimage 
	ls -l $(INSTDIR)/firmware*.img

all: kernel modules disk jffs2 firmware

# jffs2 firmware
clean:
	$(MAKE) -C $(PROGDIR) 				clean
	$(MAKE) -C $(KERNDIR)/liab-modules		clean
	$(MAKE) -C $(KERNDIR)/linux 			clean
	$(SUDO) $(MAKE) -C $(DISKSRC)			clean

distclean:
#	software/liabkernel
	$(MAKE) -C $(KERNDIR)/liab-modules		distclean
	$(MAKE) -C $(KERNDIR)			distclean
	rm -rf $(KERNDIR)/kernelmodules
	rm -fr $(MODULESDIR)
	rm -f liab6I-ARM/software/liabkernel/linux-2.6.29.4.tar.bz2
#	software/liabboot
	rm -f $(BOOTDIR)/uuencoded_bootloader $(BOOTDIR)/uuencoded_discimage 
	rm -f $(BOOTDIR)/uuencoded_vmlinux $(BOOTDIR)/uuencoded_jffs2image
#	software/liabdisk
	$(SUDO) $(MAKE) -C $(DISKSRC)			distclean
#	software/liabdisk, jffs2
	rm -f $(DISKDIR)/jffs2.img
	rm -f $(DISKDIR)/flash.tar.gz
	$(SUDO) rm -fr $(DISKDIR)/libc6
#	software/liabinstall
	rm -f $(INSTDIR)/firmware*.img 
	rm -f $(INSTDIR)/ARM_FLASH_Image
	rm -f $(INSTDIR)/images/*
	-rm -f $(DISKSRC)/packages-deb-arm/*
