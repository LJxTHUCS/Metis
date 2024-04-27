#!/bin/bash

#
# Copyright (c) 2020-2024 Yifei Liu
# Copyright (c) 2020-2024 Wei Su
# Copyright (c) 2020-2024 Erez Zadok
# Copyright (c) 2020-2024 Stony Brook University
# Copyright (c) 2020-2024 The Research Foundation of SUNY
#
# You can redistribute it and/or modify it under the terms of the Apache License, 
# Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0).
#

# Standalong setup script without using swarm

FSLIST=()
DEVSIZE_KB=()
DEVLIST=()
SWARM_ID=0 # 0 is the default swarm id without using swarm
MCFSLIST=""
USE_ENV_VAR=0

LOOPDEVS=()
verbose=0
POSITIONAL=()
_CFLAGS=""
KEEP_FS=0
SETUP_ONLY=0
CLEAN_AFTER_EXP=0
REPLAY=0
exclude_dirs=(
    lost+found
)
VERIFS_PREFIX="veri"
VERI_PREFIX_LEN="${#VERIFS_PREFIX}"
PML_SRC="./mcfs-main.pml"
PML_TEMP="./.pml_tmp"
PML_START_PATN="\/\* The persistent content of the file systems \*\/"
PML_END_PATN="\/\* Abstract state signatures of the file systems \*\/"

generic_cleanup() {
    n_fs=$1;
    SWARM_ID=$2;
    if [ "$KEEP_FS" = "0" ]; then
        for i in $(seq 0 $(($n_fs-1))); do
            fs=${FSLIST[$i]};
            if [ "$(mount | grep /mnt/test-$fs-i$i-s$SWARM_ID)" ]; then
                umount -f /mnt/test-$fs-i$i-s$SWARM_ID;
            fi
        done

        for device in ${LOOPDEVS[@]}; do
            if [ "$device" ]; then
                losetup -d $device;
            fi
        done

        for fs in ${FSLIST[@]}; do
            # Do not need to unset VeriFS
            if [ "${fs:0:${VERI_PREFIX_LEN}}" != "$VERIFS_PREFIX" ]; then
                unset_$fs;
            fi
        done
    fi
    login_user=$(who am i | cut -d ' ' -f 1);
    chown -R $login_user:$login_user .
}

runcmd() {
    if [ $verbose != "0" ]; then
        echo ">>> $@" >&2 ;
    fi
    sleep 0.5;
    $@;
    ret=$?;
    if [ $ret -ne 0 ]; then
        echo "Command '$0' exited with error ($ret)." >&2;
        generic_cleanup $n_fs $SWARM_ID;
        exit $ret;
    fi
}

runcmd losetup -D

# Setup mount points and each file system
for i in $(seq 0 $(($n_fs-1))); do
    # Run individual file system setup scripts defined above
    fs=${FSLIST[$i]};
    DEVICE=${DEVLIST[$i]};
    DEVSZKB=${DEVSIZE_KB[$i]};
    # Do not need to set up VeriFS
    if [ "${fs:0:${VERI_PREFIX_LEN}}" != "$VERIFS_PREFIX" ]; then
        # Unmount first
        if [ "$(mount | grep /mnt/test-$fs-i$i-s$SWARM_ID)" ]; then
            runcmd umount -f /mnt/test-$fs-i$i-s$SWARM_ID;
        fi
        if [ -d /mnt/test-$fs-i$i-s$SWARM_ID ]; then
            runcmd rm -rf /mnt/test-$fs-i$i-s$SWARM_ID;
        fi
        # Create mountpoint
        runcmd mkdir -p /mnt/test-$fs-i$i-s$SWARM_ID;
    fi
done

# Insert c_track statements in promela code
C_TRACK_CNT=0
CTRACKLIST=()
for i in $(seq 0 $(($n_fs-1))); do
    DEVICE=${DEVLIST[$i]};
    DEVSZKB=${DEVSIZE_KB[$i]};
    if [ "$DEVICE" != "" ]; then
        CTRACKLIST[$i]="c_track \"get_fsimgs()[$C_TRACK_CNT]\" \"$(($DEVSZKB * 1024))\" \"UnMatched\";"
        C_TRACK_CNT=$(($C_TRACK_CNT+1))
    fi
done

if [ "$C_TRACK_CNT" -gt "0" ]; then
    C_TRACK_STMT=""
    for i in $(seq 0 $(($C_TRACK_CNT-1))); do
        C_TRACK_STMT="${C_TRACK_STMT}${CTRACKLIST[$i]}\\n"
    done

    sed "/$PML_START_PATN/,/$PML_END_PATN/{//!d}" $PML_SRC > $PML_TEMP
    sed "/$PML_START_PATN/a$C_TRACK_STMT" $PML_TEMP > $PML_SRC
    rm $PML_TEMP
fi

# Run test program
if [ "$SETUP_ONLY" != "1" ]; then
    runcmd make CFLAGS=$_CFLAGS;
    mv *.o *.a pan* bin;
    echo 'Running file system checker...';
    echo 'Please check stdout in output.log, stderr in error.log';
    # Set environment variable MCFS_FSLIST for MCFS C Sources
    if [ "$USE_ENV_VAR" = "1" ]; then
        export MCFS_FSLIST$SWARM_ID="$MCFSLIST"
        ./bin/pan -K $SWARM_ID 2>./log/error.log > ./log/output.log
    else
        ./bin/pan -m10000 -K $SWARM_ID:$MCFSLIST 2>./log/error.log > ./log/output.log
    fi

    # By default we don't want to clean up the file system for 
    # better analyzing discrepancies reported by MCFS
    generic_cleanup $n_fs $SWARM_ID;
fi
