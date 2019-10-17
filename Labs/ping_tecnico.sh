#!/bin/sh
if [ -e /data ]
then
    TARGET=/data/ping.log
else
    TARGET=./ping.log
fi
ping -c 3 tecnico.ulisboa.pt >> $TARGET
exit 0
