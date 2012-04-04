#! /bin/sh -x
#
# This is a new incarnation of the firmware upgrade scripts This
#
# script is meant to be called by either a USB or remote (net) update
# parent scripts or program, that extracts the tar.gz image file to
# TMPDIR.
#

if [ $# -gt 0 ]; then
    TMPDIR=$1
else
    TMPDIR=/tmp
fi

if [  $# -gt 1 ]; then
    # save stdout and redirect to file
    exec 6>&1
    echo -n > $2        
    exec > $2 
fi

FIRMWARE=`ls $TMPDIR/firmware.tgz | tail -1`
FIRMWARE_CS=`ls $TMPDIR/firmware.tgz.md5 | tail -1`

if [ -x /usr/bin/update-splash ]; then
    /usr/bin/update-splash -s USB-DETECT
fi

if [[ -f $FIRMWARE && -f $FIRMWARE_CS ]]; then
    echo "STATUS: Checking firmware MD5 checksum..."
    if /usr/bin/md5sum $FIRMWARE | cut -d " " -f 1 | diff - $FIRMWARE_CS ; then
        echo "STATUS: MD5 checksum OK"
        cd $TMPDIR
        tar zxf firmware.tgz 2>/dev/null
        $TMPDIR/do_update.sh $TMPDIR
        sleep 10
    else
        if [ -x /usr/bin/update-splash ]; then
            /usr/bin/update-splash -s USB-ERROR
        fi
        echo "ERROR: Error in MD5 checksum"
        exit 1
    fi
else
    if [ -x /usr/bin/update-splash ]; then
        /usr/bin/update-splash -s USB-ERROR
    fi
    echo "ERROR: Error finding $FIRMWARE and $FIRMWARE_CS"
    exit 1
fi

if [ $# -gt 1 ]; then
    # restore stdout
    exec 1>&6 6>&-
fi

