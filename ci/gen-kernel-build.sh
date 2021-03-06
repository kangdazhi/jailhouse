#!/bin/bash
#
# Jailhouse, a Linux-based partitioning hypervisor
#
# Copyright (c) Siemens AG, 2014-2016
#
# Authors:
#  Jan Kiszka <jan.kiszka@siemens.com>
#
# This work is licensed under the terms of the GNU GPL, version 2.  See
# the COPYING file in the top-level directory.
#

BASEDIR=`cd \`dirname $0\`; pwd`

if test -z $KERNEL; then
	KERNEL=https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.4.tar.xz
fi
if test -z $PARALLEL_BUILD; then
	PARALLEL_BUILD=-j16
fi
if test -z $OUTDIR; then
	OUTDIR=$BASEDIR/out
fi

prepare_out()
{
	rm -rf $OUTDIR
	mkdir -p $OUTDIR
	cd $OUTDIR
}

prepare_kernel()
{
	ARCHIVE_FILE=`basename $KERNEL`
	if ! test -f $BASEDIR/$ARCHIVE_FILE; then
		wget $KERNEL -O $BASEDIR/$ARCHIVE_FILE
	fi
	tar xJf $BASEDIR/$ARCHIVE_FILE
	ln -s linux-* linux
	cd linux
	patch -p1 << EOF
diff --git a/arch/arm/kernel/armksyms.c b/arch/arm/kernel/armksyms.c
index f89811f..44458c8 100644
--- a/arch/arm/kernel/armksyms.c
+++ b/arch/arm/kernel/armksyms.c
@@ -19,6 +19,7 @@
 
 #include <asm/checksum.h>
 #include <asm/ftrace.h>
+#include <asm/virt.h>
 
 /*
  * libgcc functions - functions that are used internally by the
@@ -175,3 +176,7 @@ EXPORT_SYMBOL(__gnu_mcount_nc);
 EXPORT_SYMBOL(__pv_phys_pfn_offset);
 EXPORT_SYMBOL(__pv_offset);
 #endif
+
+#ifdef CONFIG_ARM_VIRT_EXT
+EXPORT_SYMBOL_GPL(__boot_cpu_mode);
+#endif
EOF
}

build_kernel()
{
	mkdir build-$1
	cp $BASEDIR/kernel-config-$1 build-$1/.config
	make O=build-$1 vmlinux $PARALLEL_BUILD ARCH=$2 CROSS_COMPILE=$3
	# clean up some unneeded build output
	find build-$1 \( -name "*.o" -o -name "*.cmd" -o -name ".tmp_*" \) -exec rm -rf {} \;
}

package_out()
{
	cd $OUTDIR
	tar cJf kernel-build.tar.xz linux-* linux
}

prepare_out
prepare_kernel
build_kernel x86 x86_64
build_kernel banana-pi arm arm-linux-gnueabihf-
build_kernel vexpress arm arm-linux-gnueabihf-
build_kernel amd-seattle arm64 aarch64-linux-gnu-
package_out
