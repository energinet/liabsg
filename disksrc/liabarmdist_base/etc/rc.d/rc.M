#!/bin/bash

OPTIONSFILE=/tmp/optionsfile
# Mount /JFFS2
JFFS2MNTPNT=`grep "liabJFFS2=" $OPTIONSFILE | cut -f2 -d"="`
JFFS2DEV="/dev/mtdblock1"
if [ "$JFFS2MNTPNT" ]; then
  echo "Trying to mount $JFFS2DEV over $JFFS2MNTPNT ... "
  if mount -t yaffs2 $JFFS2DEV $JFFS2MNTPNT; then
    echo "... OK"
  else
    echo "*ERROR* mount of $JFFS2DEV Failed *"
  fi
fi

#
## Configure and start NTP ()
hwclock --hctosys
NTPOPTIONS=
LIABNTP=`grep "liabNTP=" $OPTIONSFILE | cut -f2 -d"="`
if [[ $LIABNTP &&  "$DHCPNTP" != "yes" ]]; then
    if [[ -x /usr/sbin/ntpd && -f /etc/ntp.conf ]]; then
        echo "server $LIABNTP" >> /etc/ntp.conf
        if [[ -nd /var/lib/ntp ]]; then
            mkdir -p /var/lib/ntp
        fi
        echo -n "Starting NTP server: ntpd..."
#        hwclock --localtime --systohc
        if /usr/sbin/ntpd -g -p /var/run/ntpd.pid; then
            echo "OK"
        else
            echo "FAIL"
        fi
    fi
fi

# start the xinetd super daemon
if [ -x /usr/sbin/xinetd ]; then
    echo Starting xinetd...
    /usr/sbin/xinetd -stayalive -reuse -pidfile /var/run/xinetd.pid
fi
if [ -x /usr/sbin/sshd ]; then
    echo Starting sshd...
    /usr/sbin/sshd
fi
if [ -x /usr/sbin/cron ]; then
    echo Starting cron...
    /usr/sbin/cron
fi
echo Starting httpd...
/usr/sbin/httpd

# Call /jffs2/StartApplication
RUN=`grep "liabRUN=" $OPTIONSFILE | cut -f2 -d"="`
if [ -x "$RUN" ]; then
    echo "Executing file $RUN"
    $RUN
fi


# Start the watchdog timer
if `grep -q liabWDT=on /tmp/optionsfile`; then
    modprobe -q at91rm9200_wdt wdt_time=60
    if [ -x /usr/sbin/watchdog ]; then
        echo "Starting watchdog..."
        /usr/sbin/watchdog
    fi
fi
