#!/bin/bash

# This script should be placed in fs-state/mcfs_scripts folder
# Make sure that VeriFS2 is installed

FUSE_SZKB=0
VERIFS2_SZKB=0 

cd ..
sudo ./stop.sh

sudo ./setup.sh -f ext4_fuse:$FUSE_SZKB:verifs2:$VERIFS2_SZKB