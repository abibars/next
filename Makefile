#
# Makefile
#
# Copyright (C) 2021 Studio.Link Sebastian Reimers
# Variables:
#   V			Verbose mode (example: make V=1)
#   CORES		Override CPU Core detection
#

VER_MAJOR := 22
VER_MINOR := 1
VER_PATCH := 0
VER_PRE   := alpha

OPENSSL_VERSION := 3.0.0
OPENSSL_MIRROR  := https://www.openssl.org/source
OPUS_VERSION    := 1.3.1
OPUS_MIRROR     := https://archive.mozilla.org/pub/opus
LIBRE_VERSION   := master
LIBREM_VERSION  := master
BARESIP_VERSION := master

BARESIP_MODULES := account opus vp8 portaudio

ifeq ($(OS),darwin)
CORES := $(shell sysctl -n hw.ncpu)
else
CORES := $(shell nproc)
endif

MAKE += -j$(CORES)

ifeq ($(V),)
HIDE=@
MAKE += --no-print-directory
endif

##############################################################################
#
# Main
#

default: third_party studiolink.a

.PHONY: studiolink.a
studiolink.a: libre librem libbaresip
	$(MAKE) -C src SYSROOT_ALT=../third_party $@

.PHONY: info
info:
	$(MAKE) -C src SYSROOT_ALT=../third_party $@

##############################################################################
#
# Third Party section
#

.PHONY: openssl
openssl: third_party/openssl

.PHONY: opus
opus: third_party/opus

.PHONY: libre
libre: third_party/re openssl
	@rm -f third_party/re/libre.*
	$(MAKE) -C third_party/re SYSROOT_ALT=../. libre.a
	cp -a third_party/re/libre.a third_party/lib/
	$(HIDE) install -m 0644 \
		$(shell find third_party/re/include -name "*.h") \
		third_party/include/re

.PHONY: librem
librem: third_party/rem libre
	@rm -f third_party/rem/librem.*
	$(MAKE) -C third_party/rem SYSROOT_ALT=../. librem.a
	cp -a third_party/rem/librem.a third_party/lib/
	$(HIDE) install -m 0644 \
		$(shell find third_party/rem/include -name "*.h") \
		third_party/include/rem

.PHONY: libbaresip
libbaresip: third_party/baresip opus libre librem
	@rm -f third_party/baresip/libbaresip.* \
		third_party/baresip/src/static.c
	$(MAKE) -C third_party/baresip SYSROOT_ALT=../. STATIC=1 \
		MODULES="$(BARESIP_MODULES)" \
		libbaresip.a
	cp -a third_party/baresip/libbaresip.a third_party/lib/
	cp -a third_party/baresip/include/baresip.h third_party/include/

.PHONY: third_party_dir
third_party_dir:
	mkdir -p third_party/include
	mkdir -p third_party/lib

.PHONY: third_party
third_party: third_party_dir openssl opus libre librem libbaresip

third_party/openssl:
	@cd third_party && wget ${OPENSSL_MIRROR}/openssl-${OPENSSL_VERSION}.tar.gz
	@cd third_party && tar -xzf openssl-${OPENSSL_VERSION}.tar.gz
	@cd third_party && mv openssl-${OPENSSL_VERSION} openssl
	@rm -f third_party/openssl-${OPENSSL_VERSION}.tar.gz
	$(HIDE)cd third_party/openssl && \
		./config no-shared && \
		$(MAKE) build_libs && \
		cp *.a ../lib && \
		cp -a include/openssl ../include/

third_party/opus:
	cd third_party && wget ${OPUS_MIRROR}/opus-${OPUS_VERSION}.tar.gz && \
		tar -xzf opus-${OPUS_VERSION}.tar.gz && \
		mv opus-${OPUS_VERSION} opus && \
		cd opus && \
		./configure --with-pic && \
		$(MAKE) && \
		cp .libs/libopus.a ../lib/ && \
		mkdir -p ../include/opus && \
		cp include/*.h ../include/opus/

third_party/re:
	mkdir -p third_party/include/re
	$(shell [ ! -d third_party/re ] && \
		git -C third_party clone https://github.com/baresip/re.git)
	git -C third_party/re checkout $(LIBRE_VERSION)

third_party/rem:
	mkdir -p third_party/include/rem
	$(shell [ ! -d third_party/rem ] && \
		git -C third_party clone https://github.com/baresip/rem.git)
	git -C third_party/rem checkout $(LIBREM_VERSION)

third_party/baresip:
	$(shell [ ! -d third_party/baresip ] && \
		git -C third_party clone \
		https://github.com/baresip/baresip.git)
	git -C third_party/baresip checkout $(BARESIP_VERSION)

.PHONY: bareinfo
bareinfo:
	$(MAKE) -C third_party/baresip SYSROOT_ALT=../. \
		STATIC=1 MODULES="$(BARESIP_MODULES)" \
		bareinfo

##############################################################################
#
# Tools & Cleanup
#

.PHONY: clean
clean:
	$(HIDE)$(MAKE) -C third_party/baresip clean
	$(HIDE)$(MAKE) -C third_party/rem clean
	$(HIDE)$(MAKE) -C third_party/re clean
	$(HIDE)$(MAKE) -C src clean

.PHONY: distclean
distclean:
	rm -Rf third_party

.PHONY: ccheck
ccheck:
	tests/ccheck.py src Makefile

.PHONY: tree
tree:
	tree -L 4 -I "third_party|node_modules" -d .
