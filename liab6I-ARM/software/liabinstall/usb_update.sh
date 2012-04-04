#! /bin/sh -x

## Check for USB-stick and update 

function detect_usbstick() {
    TIMEOUT=20
    RV=1

    # Modules relevant for the USB firmware upload
    modprobe -q sd_mod > /dev/null 2>&1
    modprobe -q usb-storage > /dev/null 2>&1
    rmmod mytouchmod
    
    until [[ $RV -ne 1  || $TIMEOUT -lt 0 ]]; do
        grep -qi sda1 /proc/partitions
        RV=$?
        sleep 1
        TIMEOUT=$((TIMEOUT-1))
        echo -n "."
    done
    if [ $TIMEOUT -lt 0 ]; then
        # Fail
        rmmod usb-storage
        rmmod sd_mod
        rmmod scsi_mod
        return 1
    else
        # Success
        return 0
    fi
}

MOUNTPOINT=/mnt
TEMPSTORE=/mnt

echo -n "Looking for USB memory stick... "


if detect_usbstick; then
    
    echo "Found. Preparing to upgrade platform."    
    if ! [ -d $MOUNTPOINT ]; then
        mkdir -p $MOUNTPOINT
    fi
    
    #
    # Mount usb disk
    if mount /dev/sda1 $MOUNTPOINT > /dev/null 2>&1; then    
        FIRMWARE=`ls $MOUNTPOINT/firmware-*.img | tail -1`

        cd /

        if [ -f $FIRMWARE ]; then
            echo "Found new firmware - checking version"

            RUNNING_VER=`cat /etc/liab_version | cut -d '-' -f 3`
            UPDATE_VER=`ls $FIRMWARE | cut -d'-' -f 5|cut -d. -f1`

            if [[ "$RUNNING_VER" !=  "$UPDATE_VER" ]]; then
                echo "Versions differ"

                if [[ $MOUNTPOINT != $TEMPSTORE ]]; then
                    if [ -d $TEMPSTORE ]; then
                        rm -fr $TEMPSTORE
                    fi
                    mkdir $TEMPSTORE
                    if ! mount -t yaffs2 /dev/mtdblock2 $TEMPSTORE; then
                        echo "Error mounting $TEMPSTORE"
                        echo "Using regular method"
                        TEMPSTORE=$MOUNTPOINT
                    fi              
                fi
                
                if tar zxvp --no-same-owner -f $FIRMWARE -C $TEMPSTORE 2>/dev/null; then
                    /usr/sbin/update_firmware.sh $TEMPSTORE
                    sleep 5
                    umount $TEMPSTORE
                else
                    echo "Error unpacking update. Aborting."
                fi
            else
                echo "Same as running version. Skipping update."
            fi
        else
            echo "No firmware present on disk!"
        fi
        cd /
        umount $MOUNTPOINT

        rmmod usb-storage
        rmmod sd_mod
        rmmod scsi_mod
    else
        rmmod usb-storage
        rmmod sd_mod
        rmmod scsi_mod
        echo "ERROR: Couldn't MOUNT USB disk! Is it formatted properly?"
    fi

    rm -fr $TEMPSTORE
    rm -fr $MNTPOINT
else
    echo "Not found. Proceeding with normal boot."
fi
