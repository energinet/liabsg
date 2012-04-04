DEBUG = n
ifeq ($(DEBUG),y)
  EXTRA_CFLAGS += -DMODULE_DEBUG
endif


obj-m := modem.o
#modem-objs := modem.o
PWD		:= $(shell pwd)
KDIR	:= ../../linux
EXTRA_CFLAGS += 

ifeq ($(DEBUG),y)
LIAB=root@jcg2
endif

default:
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) V=0 modules
ifdef LIAB
	rcp liabdin.ko $(LIAB):.
endif

clean:
	rm -fr *.o *~ .tmp_versions .*.cmd .*.d *.mod.c
distclean: clean
	rm -fr *.ko