#! /bin/bash -x

FIRMWAREPATH=$1

SAVE_FILES=(\
    "/jffs2/root/etc/pointercal" \
    "/jffs2/navtex.db" \
    "/jffs2/navtex.conf")
file_cnt=${#SAVE_FILES[@]}
BACKUPDIR=/tmp/backup
mkdir -p $BACKUPDIR

clean_jffs2="yes"
dry_run="no"



# MTD device names
MTDBLOCK=("/dev/mtd0" "/dev/mtd2")
# Names
NAME=("Root partition" "FLASH partition")

update_flash() {
###
# Parameters: update_flash(Partition no, imagefile)
### 

    ## Might want to keep JFFS2
    if [[ $1 == 1 && $clean_jffs2 == "no" ]]; then 
        echo "Checking ${NAME[$1]} firmware... update FLASH is disabled"
        return; 
    fi

    # Check whether we have a new firmware ... if so write it to flash
    echo -n "Checking ${NAME[$1]} firmware... "

		echo -n "Erasing ${NAME[$1]} . Please wait... "
    if [[ $dry_run != "yes" ]]; then
        $FIRMWAREPATH/bin/flash_eraseall ${MTDBLOCK[$1]}
    fi
		echo "done"

    echo -n "Updating ${NAME[$1]} . Please wait..."
    case $1 in 
        0)
            if [[ $dry_run != "yes" ]]; then
                if $FIRMWAREPATH/bin/nandwrite -p ${MTDBLOCK[$1]} $2; then
                    echo "done"
                else
                    echo "Failed"
                fi
            fi
            ;;
        1)
            if [[ $dry_run != "yes" ]]; then
                if mount -t yaffs2 /dev/mtdblock1 /jffs2; then
                    if tar zxvf $2 -C /jffs2; then
                        echo "done"
                    else
                        echo "failed"
                    fi
                fi
            else
                echo "Error mounting YAFFS2"
            fi
            ;;
    esac

    do_reboot="yes"       
}


if [ -x $FIRMWAREPATH/bin/update-splash ]; then
    $FIRMWAREPATH/bin/update-splash -s USB-DETECT
fi

## Check if this update has already been applied
FIRMWARENAME=`ls $FIRMWAREPATH/firmware-*.img | tail -1`
#if [ -f $FIRMWARENAME.loaded ]; then
#    echo "This firmware has already been applied."
#    exit 0;
#fi


if [ -x $FIRMWAREPATH/bin/update-splash ]; then
    $FIRMWAREPATH/bin/update-splash -s USB-DONE
fi


#backup files
if ! mount | grep jffs2; then
    mount -t yaffs2 /dev/mtdblock1 /jffs2
fi
sleep 1
for (( i = 0 ; i < file_cnt ; i++ ))
do
    if [ -f ${SAVE_FILES[$i]} ]; then
        cp ${SAVE_FILES[$i]} $BACKUPDIR        
    fi
done

if [[ $dry_run != "yes" ]]; then
    killall liabconnect -2
    sleep 2
    killall liabconnect -9
    killall contdaem -9
    killall modbusd -9 
    killall rpclient -9
    sleep 2
    umount /jffs2
fi

# the update procedure...
update_flash 0 $FIRMWAREPATH/images/image9260
update_flash 1 $FIRMWAREPATH/images/flash.tar.gz


#restore the files
for (( i = 0 ; i < file_cnt ; i++ ))
do
    FILENAME=`basename ${SAVE_FILES[$i]}`
    if [ -f $BACKUPDIR/$FILENAME ]; then
        cp $BACKUPDIR/$FILENAME ${SAVE_FILES[$i]}
    fi
done

if [ -x $FIRMWAREPATH/bin/update-splash ]; then
    $FIRMWAREPATH/bin/update-splash -s USB-OK
    sleep 3
fi

echo -n > $FIRMWARENAME.loaded

sync

if [ "$do_reboot" == "yes" ]; then
    echo "Rebooting..."
    sleep  1
    reboot -f
else
    mount -t yaffs2 /dev/mtdblock1 /jffs2
fi

