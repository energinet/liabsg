#!/bin/bash

RSH_AVAILABLE="yes"
SSH_CLIENT_AVAILABLE="no"
SSH_SERVER_AVAILABLE="no"
DHCP_AVAILABLE="yes"
WIRELESS_AVAILABLE="yes"
WGET_AVAILABLE="no"
PPP_AVAILABLE="yes"
NTP_AVAILABLE="yes"

CHECK_BIN=" basename env sort tr uniq expr uname"

# Added by MSA for the LIABARM distro
UTILS_BIN="cron crontab killall diff md5sum expr uname run-parts watchdog logrotate"
UTILS_PCK="cron psmisc debianutils dpkg watchdog logrotate libpopt0"
UTILS_CFG=""

#CPLUS_PCK=" libstdc++5"
#CPLUS_LIB=" libstdc++.so"

if [ $DHCP_AVAILABLE == "yes" ]; then
    DHCP_CLIENT_BIN="udhcpc udhcpd dumpleases"
    DHCP_CLIENT_PCK="udhcpc udhcpd"
    DHCP_CLIENT_CFG="udhcpc /var/lib/misc/udhcpd.leases"
fi
if [ $NTP_AVAILABLE == "yes" ]; then
    NTP_BIN=" anacron gawk ntpd ntptime tickadj ntpdate"
    NTP_PCK=" anacron gawk libssl0.9.8 ntp ntpdate"
    NTP_LIB=" libssl.so libcrypto"
    NTP_CFG=" "
fi
if [ $RSH_AVAILABLE == "yes" ]; then
    XINETD_PCK="rsh-client rsh-server telnetd xinetd"
    XINETD_BIN="rcp rsh in.rexecd in.rlogind in.rshd in.telnetd xinetd vsftpd"
fi
if [ $SSH_SERVER_AVAILABLE == "yes" ]; then
    SSH_PCK="openssh-server zlib1g libkrb53 libssl0.9.8"
    SSH_BIN="sshd scp"
    SSH_LIB="zlib1g libcrypto"
fi
if [ $SSH_CLIENT_AVAILABLE == "yes" ]; then
    SSH_PCK="$SSH_PCK ""openssh-client zlib1g libssl0.9.8"
    SSH_BIN="$SSH_BIN ""ssh ssh-agent ssh-add scp"
    SSH_LIB="$SSH_LIB ""zlib1g libcrypto"
fi
if [ $WIRELESS_AVAILABLE == "yes" ]; then
    WIRELESS_BIN="iwconfig iwlist wpa_supplicant wpa_action wpa_cli wpa_passphrase hotplug sed"
    WIRELESS_PCK="wireless-tools libiw28 wpasupplicant libdbus-1-3 libncurses5 libreadline5 libssl0.9.8 zlib1g hotplug sed"
    WIRELESS_CFG=" "
fi
if [ $WGET_AVAILABLE == "yes" ]; then
    WGET_BIN="wget"
    WGET_PCK="wget"
fi
if [ $PPP_AVAILABLE == "yes" ]; then
    PPP_BIN="pptp pppd chat pppdump pppstats ip pon poff plog pidof killall5 gawk wc"
    PPP_CFG="/etc/ppp/ip-down /etc/ppp/ip-up"
    PPP_PCK="pptp-linux ppp libpcap0.8 iproute sysvinit-utils gawk"
fi

ADDITIONAL_PCK=" $CHECK_PCK $XINETD_PCK $UTILS_PCK $DHCP_CLIENT_PCK $WIRELESS_PCK $SSH_PCK $WGET_PCK $PPP_PCK $NTP_PCK"
ADDITIONAL_LIB=" $SSH_LIB $PPP_LIB libgcrypt1 libnss_dns $NTP_LIB"
ADDITIONAL_BIN=" $CHECK_BIN $XINETD_BIN $UTILS_BIN $DHCP_CLIENT_BIN $WIRELESS_BIN $SSH_BIN $WGET_BIN $PPP_BIN $NTP_BIN"
ADDITIONAL_CFG=" $UTILS_CFG $DHCP_CLIENT_CFG $WIRELESS_CFG $NTP_CFG $PPP_CFG"


ARCH="arm"
#ARCH="i386"
PACKAGES=packages-deb-${ARCH}
SERVER=http://archive.debian.org/debian
DISTRIBUTION="dists/Debian-4.0"
LIABBASE=liabarmdist_base
DISTNAME=libc6
INCDIR=incexport
NFSHOST=192.168.1.230
NFSSHARE=nfs
KERNEL=../liab6I-ARM/software/liabkernel/linux

binaries="
 bash
 cat
 chmod
 cmp
 cp
 cu
 cut
 date
 dd
 depmod
 df
 domainname
 getty
 grep
 gzip
 hostname
 hwclock
 ifconfig
 init
 insmod
 kill
 klogd
 ln
 login
 logger
 ls
 lsmod
 mkdir
 mke2fs
 mknod
 modprobe
 modinfo
 more
 mount
 mv
 nice
 passwd
 ping
 portmap
 ps
 pwd
 reboot
 rm
 rmmod
 route
 sh
 sleep
 stty
 syslogd
 tail
 tar
 tcpd
 tftp
 umount
 update-modules
 vi
""$ADDITIONAL_BIN"

config="
""$ADDITIONAL_CFG"

libraries="
 libnss_dns
 libnss_files
 libdevmapper1.02
 libselinux1
 libsepol1
 pam_rhosts_auth
 pam_nologin
""$ADDITIONAL_LIB"

packages="
 acl
 attr
 bash
 bsdutils
 coreutils
 cu
 diff 
 e2fslibs
 e2fsprogs
 grep
 gzip
 hostname
 ifupdown
 iputils-ping
 klogd
 libc6
 libacl1
 libattr1
 libblkid1
 libcap1
 libcomerr2
 libexpat1
 libgcc1
 libncurses5
 libpam-modules
 libpam-runtime
 libpam0g
 libuuid1
 libwrap0
 libdevmapper1.02
 libselinux1
 libsepol1
 login
 module-init-tools 
 mount
 net-tools
 netbase
 nis
 nvi
 passwd 
 portmap
 ppp
 procps
 psmisc
 sysklogd
 sysvinit
 tar
 tcpd
 telnet
 tftp
 util-linux
""$ADDITIONAL_PCK"

script="
 binutils-multiarch
 diff
 findutils
 gawk
 sed
 "

gcc="
 debianutils
 m4
 autoconf
 perl
 libgdbm3
 perl-base
 perl-modules
 binutils
 cpp
 cpp-3.4
 gdb
 gcc
 gcc-3.4
 gcc-3.4-base
 g++-3.4
 libstdc++6-dev
 libc6-dev
 libcap-dev
 libx11-6
 libssl0.9.7
 libssl-dev 
 make
 strace
 tcl8.3
 tk8.3
 emacs21-nox
 emacs21-bin-common
 emacs21-common
 emacsen-common
 emacs21-el
 liblockfile1
 libreadline5
"

# get debian package
getpackage() {
    # This function sets global variable "package"
    if [ "$#" -eq 0 ]; then
	echo $"Usage: getpackage <package>"
	return 1
    fi

    if [ "$1" == "" ]; then
	echo $"getpackage(): package name is empty"
	return 1
    fi

    if [ ! -f $PACKAGES/Packages ]; then
	wget -P $PACKAGES ${SERVER}/${DISTRIBUTION}/main/binary-${ARCH}/Packages.gz
	wget -P $PACKAGES ${SERVER}/${DISTRIBUTION}/Contents-${ARCH}.gz
	rm -f $PACKAGES/Contents-${ARCH} $PACKAGES/Packages $PACKAGES/Filelist
	gunzip $PACKAGES/Packages.gz
	gunzip $PACKAGES/Contents-${ARCH}.gz
	egrep "(^Package: |^Filename: )" $PACKAGES/Packages >$PACKAGES/Filelist
    fi

    local deb=`cat $PACKAGES/Filelist | awk -v deb=$1 '{if ($1 == "Package:" && $2 == deb) {found=1}; if ($1 == "Filename:" && found == 1) {found = 0; print $2}}'`
    if [ ! -f $PACKAGES/`basename $deb` ]; then
	wget -P $PACKAGES ${SERVER}/$deb
    fi

    package=`basename $deb`
}

#
# Base distribution
#

echo "========================================="
echo "  UNPACKING BASE DISTRIBUTION PACKAGES   "
echo "========================================="

rm -fr ./$DISTNAME
mkdir ./$DISTNAME

mkdir -p $PACKAGES
for deb in $packages; do
    getpackage $deb
    echo $package
    dpkg -x $PACKAGES/$package ./$DISTNAME 
done

# Assemble LIABBASE in temporary directory
rm -rf ./tmpdir
mkdir ./tmpdir
cp -a $LIABBASE/* ./tmpdir
tar zxf ${LIABBASE}_devfiles.tgz -C ./tmpdir
date "+${LIABVERSION} %c" >./tmpdir/etc/version


echo "========================================="
echo "  SETTING BASE DISTRO PERMISSIONS        "
echo "========================================="
# Assign ownership to root, and remove SVN files
chown -R root:root ./tmpdir
find ./tmpdir -depth -name .svn -exec rm -rf {} \;
### Make sure permissions are set correctly - SVN doesn't preserve permissions
find ./tmpdir -type d -exec chmod 755 {} \;
find ./tmpdir -type f -exec chmod 644 {} \;
# Directories
chmod 777 ./tmpdir/tmp
# Excutables & scripts
find ./tmpdir/etc/watchdog.d -type f -exec chmod 755 {} \;
find ./tmpdir/*bin ./tmpdir/usr/*bin -type f -exec chmod 755 {} \;
find ./tmpdir/etc/rc.d -type f -exec chmod 755 {} \;
find ./tmpdir/etc/ppp -name \*-chat -exec chmod 755 {} \;
find ./tmpdir/etc/ppp/ip-up.d -name \* -exec chmod 755 {} \;
find ./tmpdir/etc/ppp/ip-down.d -name \* -exec chmod 755 {} \;
find ./tmpdir/etc/ifscript -name \* -exec chmod 755 {} \;
find ./tmpdir/etc/cron.d -name \* -exec chmod 755 {} \;
find ./tmpdir/etc/cron.hourly -name \* -exec chmod 755 {} \;
# Libs
find ./tmpdir/*lib ./tmpdir/usr/*lib -type f -exec chmod 755 {} \;
# Other files
if [[ $SSH_SERVER_AVAILABLE == "yes" ||  $SSH_CLIENT_AVAILABLE == "yes" ]]; then
    find ./tmpdir/etc/ssh -type f ! -name *.pub -exec chmod 600 {} \;
else
    rm -fr ./tmpdir/etc/ssh
    rm -fr ./tmpdir/root/.ssh
fi
chmod 600 /etc/shadow

# Copy files from temporary dir to the distribution, overwriting if necessary
cp -a tmpdir/* ./$DISTNAME/


if [ -f ./$DISTNAME/usr/bin/netkit-rsh ]; then
    mv ./$DISTNAME/usr/bin/netkit-rsh    ./$DISTNAME/usr/bin/rsh
    mv ./$DISTNAME/usr/bin/netkit-rcp    ./$DISTNAME/usr/bin/rcp
    mv ./$DISTNAME/usr/bin/netkit-rlogin ./$DISTNAME/usr/bin/rlogin
fi
mv ./$DISTNAME/sbin/halt             ./$DISTNAME/sbin/reboot
mv ./$DISTNAME/usr/bin/nvi           ./$DISTNAME/bin/vi
#mv ./$DISTNAME/usr/bin/gawk          ./$DISTNAME/usr/bin/awk

if [[ -f ./$DISTNAME/usr/lib/libcrypto.so* && $ARCH == "arm" ]]; then
  arm-softfloat-linux-gnu-strip ./$DISTNAME/usr/lib/libcrypto.so.*
fi

echo "========================================="
echo "  SETTING BASE DISTRO CONFIGURATIONS     "
echo "========================================="
echo "Keeping default configurations from:"
confs=`ls ./$DISTNAME/etc`
for confname in $confs; do
    if echo $config | grep -q $confname; then
        echo "Keeping $confname"
    else
        rm -fr ./$DISTNAME/etc/$confname
    fi
done

cp -a ./tmpdir/etc/* ./$DISTNAME/etc/.

# Remove temporary directory for LIABBASE
rm -rf ./tmpdir

### Ryd op i lokal distribution
#rm -fr ./$DISTNAME/etc ; cp -a ./tmpdir/etc ./$DISTNAME/etc
rm -fr ./$DISTNAME/usr/share ; mkdir -p ./$DISTNAME/usr/share/empty
rm -fr ./$DISTNAME/usr/include
rm -fr ./$DISTNAME/usr/lib/gcc-lib
rm -fr ./$DISTNAME/usr/lib/gconv
rm -fr ./$DISTNAME/usr/lib/gnupg
rm -fr ./$DISTNAME/usr/lib/menu
rm -fr ./$DISTNAME/usr/lib/mime
rm -fr ./$DISTNAME/usr/lib/pt_chown
rm -fr ./$DISTNAME/usr/lib/pppd
rm -fr ./$DISTNAME/usr/lib/sftp-server
rm -fr ./$DISTNAME/usr/lib/ssh-keysign
rm -fr ./$DISTNAME/usr/lib/yp
rm -fr ./$DISTNAME/var/yp

# Put back zoneinfo
mkdir -p ./$DISTNAME/usr/share/zoneinfo
cp -a $LIABBASE/usr/share/zoneinfo/* ./$DISTNAME/usr/share/zoneinfo/.

### Sammenlign med 520 distributionen, og slet binaries der ikke findes i 
### den distribution. 

missing="$binaries"
for dirname in bin sbin usr/bin usr/sbin; do
    q0=`ls ./$LIABBASE/$dirname`
    q1=`ls ./$DISTNAME/$dirname`
    q2=`echo $q0 $q1 $binaries $binaries | tr " " "\n" | sort | uniq -u`
    echo cd ./$DISTNAME/$dirname ; cd ./$DISTNAME/$dirname
    echo rm -f $q2 ; rm -f $q2 
    echo cd - ; cd -
    missing=`echo $missing $q1 $q1 | tr " " "\n" | sort | uniq -u`
done
miss_bin="Missing executables: ${missing}"

. check_libs > /dev/null
# "$libs_unused" now contain a list of unused libraries and 
# "$libs_missing contain a list of missing libraries 
for lib in $libraries; do
    libs_unused=`echo "$libs_unused" | grep -v $lib`
done
for lib in $libs_unused ; do
    find ./$DISTNAME/usr/lib ./$DISTNAME/lib ./$DISTNAME/lib/security \( -lname $lib -o -name $lib \) -exec rm -f \{\} \;
done
miss_lib="Missing libraries: "${libs_missing}

# missing="$libraries"
# libs="`echo "$libraries" | sed 's/\(.*\)\.so/\1-2.3.2.so/'` $libraries"
# for dirname in lib lib/security usr/lib; do
#    
#     echo cd ./$DISTNAME/$dirname ; cd ./$DISTNAME/$dirname
#     q1=`ls | sort | uniq`
#     q2=`for l in $libraries; do ls --time-style=long-iso -l | awk '{print $8" "$10}'\
#         |grep ${l}; done`
#     q3=`echo $q1 $q2 $q2 | tr " " "\n" | sort | uniq -u`
#     for name in $q3; do
#        echo rm -fr ${name}* ; rm -fr ${name}*
#     done
#     echo cd - ; cd -
#     q4=`echo "$q1" | sed 's/\(.*\.so\).*/\1/' | sort | uniq`
#     missing=`echo $missing $q4 $q4 | tr " " "\n" | sort | uniq -u`
# done
# miss_lib="Missing libraries: ${missing}"

echo
verbose="true"; . check_libs
echo $miss_bin
du -hks ./$DISTNAME

