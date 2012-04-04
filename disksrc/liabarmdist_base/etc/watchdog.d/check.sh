#!/bin/bash -x

# create a lockfile so we are not run multiple times
if [ ! -e /tmp/watchdog-check-lock ]; then
  : > /tmp/watchdog-check-lock
else
    exit 0
fi

# delete log files so that disk won't run full
if [ -d /var/log/watchdog ]; then
    rm -f /var/log/watchdog/test-bin.*
fi

if [ -f /jffs2/config ]; then
    source /jffs2/config
fi

if ps aux | grep "[/]bin/sh /root/tunnel"; then
    rm -f /tmp/watchdog-check-lock
    exit 0
fi


CONFIG=/tmp/config

if [ -f $CONFIG ]; then
    STATE=`grep STATE_CONNECTION $CONFIG | cut -d= -f2`
    case $STATE in
        3g)
            PPTP_TUNNEL=1
            ;;
        ethernet)
            PPTP_TUNNEL=1
            ;;
    esac

    if [ $PPTP_TUNNEL -eq 1 ]; then
        # Is the tunnel interface running?
        ADDR=172.16.0.1
        if ! ping -W 2 -qc 4 $ADDR; then
            logger -t "watchdog" -i -s "Tunnel interface down."
            
            # stop the existing tunnel
            /root/tunnel stop

            case $STATE in
                3g)
                    if [ -f /root/3g ]; then
                        if [ ! -e /tmp/restart-3g ]; then
                            logger -t "watchdog" -i -s "Stopping 3G. Restarting 3G on next call"
                            : > /tmp/restart-3g
                            /root/3g stop
                            killall -9 pppd
                        else
                            logger -t "watchdog" -i -s " Restarting 3G"
                            rm -f /tmp/restart-3g
                            /root/3g start
                            sleep 2
                            /root/tunnel start
                        fi
                    fi
                    ;;
            esac
        fi
    fi  
fi

rm -f /var/log/watchdog/*
rm -f /tmp/watchdog-check-lock