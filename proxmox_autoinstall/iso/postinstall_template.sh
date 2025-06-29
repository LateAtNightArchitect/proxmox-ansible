#!/bin/sh

# This script reconfigures /etc/network/interfaces to use VLAN aware Linux Bridges

# This script is run after the installation of Proxmox VE and is intended to be used
# in conjunction with the Proxmox Autoinstall ISO.

# Env

VLAN_AWARE_BRIDGE="vmbr0"
VLAN_ID="100"


# Presets
#IFACE_FILE="/etc/network/interfaces"
#TMP_FILE="/etc/network/interfaces.edittmp"

IFACE_FILE="interfaces"
TMP_FILE="interfaces.edit"



# Ensure the script is run with root privileges

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Check if the script is being run in a Proxmox environment
if [ ! -d /etc/pve ]; then
    echo "This script is intended to be run in a Proxmox environment" >&2
    exit 1
fi
# Check if the network interfaces file exists
if [ ! -f /etc/network/interfaces ]; then
    echo "Network interfaces file not found: /etc/network/interfaces" >&2
    exit 1
fi

# Backup the original network interfaces file
cp /etc/network/interfaces /etc/network/interfaces.install  || {
    echo "Failed to backup /etc/network/interfaces" >&2
    exit 1
}   fi

set -e

# Extract the original vmbrA block
awk -v br="$VLAN_AWARE_BRIDGE" '
  $0 ~ "^auto "br"$" {inblock=1; print; next}
  inblock && $0 ~ "^auto " {inblock=0}
  inblock {print; next}
  {if (!inblock) print}
' "$IFACE_FILE" > "$TMP_FILE"

# Get address and gateway from original vmbrA block
ADDRESS=$(awk -v br="$VLAN_AWARE_BRIDGE" '
  $0 ~ "^auto "br"$" {inblock=1; next}
  inblock && $0 ~ "^auto " {inblock=0}
  inblock && $1=="address" {print $2}
' "$IFACE_FILE")

GATEWAY=$(awk -v br="$VLAN_AWARE_BRIDGE" '
  $0 ~ "^auto "br"$" {inblock=1; next}
  inblock && $0 ~ "^auto " {inblock=0}
  inblock && $1=="gateway" {print $2}
' "$IFACE_FILE")

# Remove address and gateway from vmbrA block, add vlan-aware lines
awk -v br="$VLAN_AWARE_BRIDGE" '
  $0 ~ "^auto "br"$" {inblock=1; print; next}
  inblock && $0 ~ "^auto " {inblock=0}
  inblock && ($1=="address" || $1=="gateway") {next}
  inblock && $0 ~ "^iface "br" " {print; next}
  inblock && $0 ~ "^bridge-fd" {
    print
    print "        bridge-vlan-aware yes"
    print "        bridge-vids 2-4094"
    next
  }
  {print}
' "$TMP_FILE" > "$TMP_FILE.2"

# Append new vmbrVVVV block
cat <<EOF >> "$TMP_FILE.2"

auto vmbr${VLAN_ID}
iface vmbr${VLAN_ID} inet manual
        address ${ADDRESS}
        gateway ${GATEWAY}
        bridge-ports ${VLAN_AWARE_BRIDGE}.${VLAN_ID}
        bridge-stp off
        bridge-fd 0
EOF

# Replace the original file
cp "$IFACE_FILE" "${IFACE_FILE}.bak"
mv "$TMP_FILE.2" "$IFACE_FILE"
#rm -f "$TMP_FILE"

echo "Network interfaces updated for VLAN-aware bridge and new VLAN bridge."
