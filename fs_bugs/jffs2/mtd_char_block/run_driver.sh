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

DRIVER_LOOP_MAX=100000

# jffs2 parameters
JFFS2_SIZE=262144
JFFS2_MNT_DIR="/mnt/test-jffs2"
MTDBLK_DEVICE="mtd0"

# Set up jffs2
setup_jffs2() {
    modprobe mtd
    modprobe mtdram total_size=$(expr $JFFS2_SIZE / 1024) erase_size=16
    modprobe mtdblock

    if test -n "$(mount | grep $JFFS2_MNT_DIR)" ; then
        umount $JFFS2_MNT_DIR || exit $?
    fi

    if test -d $JFFS2_MNT_DIR ; then
        rm -rf $JFFS2_MNT_DIR
    fi
    mkdir -p $JFFS2_MNT_DIR
    # mount -t jffs2 $MTDBLK_DEVICE $JFFS2_MNT_DIR
}

# Run driver
setup_jffs2

# Usage: ./driver mountpoint loop_max
./driver $JFFS2_MNT_DIR $DRIVER_LOOP_MAX

