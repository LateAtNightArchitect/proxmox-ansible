#!/bin/bash

echo "First boot script for proxmox"
date > /proxmox_firstboot.log
hostname > /proxmox_firstboot.log
cat "First boot script for proxmox" > /proxmox_firstboot.log

