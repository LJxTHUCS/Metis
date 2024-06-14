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

# TODO: hard code file system type
FUSE_SZKB=0
VERIFS2_SZKB=0 
FSLIST=(ext4_fuse verifs2)
MCFSLIST="ext4_fuse:$FUSE_SZKB:verifs2:$VERIFS2_SZKB"
n_fs=${#FSLIST[@]}

SWARM_ID=0 # 0 is the default swarm id without using swarm
USE_ENV_VAR=0

LOOPDEVS=()
verbose=1
_CFLAGS=""
KEEP_FS=0
SETUP_ONLY=0
CLEAN_AFTER_EXP=0

VERIFS_PREFIX="veri"
VERI_PREFIX_LEN="${#VERIFS_PREFIX}"

generic_cleanup() {
    n_fs=$1;
    SWARM_ID=$2;
    if [ "$KEEP_FS" = "0" ]; then
        for i in $(seq 0 $(($n_fs-1))); do
            fs=${FSLIST[$i]};
            if [ "$(mount | grep /mnt/test-$fs-i$i-s$SWARM_ID)" ]; then
                sudo umount -f /mnt/test-$fs-i$i-s$SWARM_ID;
                sudo rm -rf /mnt/test-$fs-i$i-s$SWARM_ID;
            fi
        done

        for device in ${LOOPDEVS[@]}; do
            if [ "$device" ]; then
                losetup -d $device;
            fi
        done

        for fs in ${FSLIST[@]}; do
            # Do not need to unset VeriFS and
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

unset_ext4_fuse() {
    :
}

# Set-up process begins
sudo ./stop.sh
runcmd losetup -D

# Setup mount points and each file system
for i in $(seq 0 $(($n_fs-1))); do
    # Run individual file system setup scripts defined above
    fs=${FSLIST[$i]};
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

# Run test program
if [ "$SETUP_ONLY" != "1" ]; then
    runcmd make CFLAGS=$_CFLAGS;
    mv *.o *.a pan* bin;
    echo "Test file systems: $MCFSLIST";
    echo 'Running file system checker...';
    echo 'Please check stdout in output.log, stderr in error.log';
    # Set environment variable MCFS_FSLIST for MCFS C Sources
    if [ "$USE_ENV_VAR" = "1" ]; then
        export MCFS_FSLIST$SWARM_ID="$MCFSLIST"
        ./bin/pan -K $SWARM_ID 2>./log/error.log > ./log/output.log
    else
        ./bin/pan -m100 -K $SWARM_ID:$MCFSLIST 2>./log/error.log > ./log/output.log
    fi

    # By default we don't want to clean up the file system for 
    # better analyzing discrepancies reported by MCFS
    if [ "$CLEAN_AFTER_EXP" = "1" ]; then
        generic_cleanup $n_fs $SWARM_ID;
    fi
fi
