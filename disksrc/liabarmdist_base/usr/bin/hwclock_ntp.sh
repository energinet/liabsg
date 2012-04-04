#!/bin/bash -x

## Script that synchonizes the RTC to system time if ntp is running
## and the hwclock time differs more than N seconds from system time.

TIMEDIFF=10  # seconds

if ps aux | grep -q [n]tpd; then
    # we're assimung UTC on the RTC here ...
    HW_EPOCH=`cat /sys/class/rtc/rtc0/since_epoch`
    SYS_EPOCH=`date +%s`

    delta=$(expr $HW_EPOCH - $SYS_EPOCH)

    if [ "$delta" -lt 0 ]                  # If "adjusted" negative number,
    then                                        # then
        let "delta = (( 0 - $delta ))"  # renormalize to positive.
    fi  

    if [ $delta -gt $TIMEDIFF ]; then
        logger -is "Difference is too great ($delta). Synchonizing SYS to HC."
        hwclock --systohc
    fi
fi