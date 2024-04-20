#!/bin/bash

# This script should be placed in fs-state/mcfs_scripts folder
# Make sure that VeriFS2 is installed

LWEXT4_SZKB=256
VERIFS2_SZKB=0 

cd ..
sudo ./stop.sh

sudo ./setup.sh -f lwext4:$LWEXT4_SZKB:verifs2:$VERIFS2_SZKB