linux-2.6.29.4.tar.bz2:
	wget http://www.kernel.org/pub/linux/kernel/v2.6/linux-2.6.29.4.tar.bz2

liab-linux-2.6.29.4: linux-2.6.29.4.tar.bz2
	tar xvf linux-2.6.29.4.tar.bz2
	cd linux-2.6.29.4; patch -p1 < ../liabkernel.patch
	mv linux-2.6.29.4 liab-linux-2.6.29.4

liab-linux-2.6.29.4/.config:
	cd liab-linux-2.6.29.4; cp liabsg-2.6.29.4.config .config

all: liab-linux-2.6.29.4 liab-linux-2.6.29.4/.config
	$(MAKE) -C liab-linux-2.6.29.4 oldconfig
	$(MAKE) -C liab-linux-2.6.29.4 dep vmlinux

clean:
	$(MAKE) -C liab-linux-2.6.29.4 clean

distclean:
	-rm -fr liab-linux-2.6.29.4
