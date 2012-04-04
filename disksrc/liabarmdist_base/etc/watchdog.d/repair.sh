#!/bin/sh

if [ $1 ] ; then
    retval=$1
else
    retval=1
fi

logger -t "watchdog" -i -s "watchdog repair script invoked (with arg1: $1)"


#===================================================================
check_process_run()	# Check if a process of the name Arg_1 is running
#===================================================================
# Arg_1 = process name
# return 1 if process is running
# return 0 if process is not running
{
    if [ `ps aux  | grep -v grep | grep -c $1` -gt 0 ] ; then 
        echo 1
        return
    fi

    return

}

#===================================================================
restart_process()	# Check if a process of the name Arg_1 is running
#===================================================================
# Arg_1 = name
# return 1 if the process is started 
# return 0 if the process could not be started
{
    killall -9 $1
    #try to restart datalogger -t "watchdog"
    $1
    sleep 1
    #check if update process is running
    if [ `check_process_run $1` ] ; then 
        return
    fi

    echo 1
    return
}

#===================================================================
dump_log() # Dumps the log to /jffs2
#===================================================================
{
    # Copy the last syslog to jffs2 for later debugging
    logger -t "watchdog" -i -s "End of repair.sh script. Copying a dump to /jffs2"
    cp -a /var/log/messages /jffs2/messages-watchdog-dump-`date +%d%M%y_%H%M%S`
}


#===================================================================
# Repair scripts below
#===================================================================

if [ `check_process_run firmware_update` ]  ; then 
    logger -t "watchdog" -i -s "Update is running running"
    logger -t "watchdog" -i -s "No shutdown"
    exit 0 
fi

#wait until the datalogger is started 
# if [ -r /var/run/datalogger.pid ]; then
#     logger -t "watchdog" -i -s "datalogger pid file is present"
# else
#     #wait until the system is booted and the datalogger started
#     sleep 10
#     if [ -r /var/run/datalogger.pid ]; then
#         #if started then exit 0
#         logger -t "watchdog" -i -s "datalogger started"
#         exit 0
#     fi    
# fi


# INSPECT=httpd

# if [ `check_process_run $INSPECT` ] ; then 
#     logger -t "watchdog" -i -s "$INSPECT is running"
# else
#     logger -t "watchdog" -i -s "$INSPECT is not running"
#     if [ `restart_process $INSPECT` ] ; then
#         logger -t "watchdog" -i -s "could not restart $INSPECT"
#         dump_log
#         exit 1 # could not restart httpd
#     fi
#     logger -t "watchdog" -i -s "$INSPECT restarted"
#     retval=0;
# fi


## Check calling reason
case $1 in
#
#	ENETDOWN: network is down
#	ENETUNREACH: network is unreachable
#	=> try to reconfigure network interface, there is no guarantee that
#	   this helps, but if it does not, reboot won't either
#
	  
    100|101)
        retval=0
        ;;
esac

# write return value
logger -t "watchdog" -i -s "returning $retval"

# Notify console in case of reboot 
if [ $retval -gt 0 ] ; then
    logger -t "watchdog" -i -s "Watchdog rebooting system:"
    echo "Watchdog rebooting system:" > /dev/console
    dump_log
fi

exit $retval
