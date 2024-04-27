#!/bin/bash

# This script should be placed in fs-state/mcfs_scripts folder
# Make sure that VeriFS2 is installed

FUSE_LWEXT4_SZKB=256
LWEXT4_SZKB=256 

cd ..
sudo ./stop.sh

sudo ./setup.sh -f fuse_lwext4:$FUSE_LWEXT4_SZKB:lwext4:$LWEXT4_SZKB