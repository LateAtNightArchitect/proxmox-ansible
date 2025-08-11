#!/bin/sh

# This script reconfigures /etc/network/interfaces to use VLAN aware Linux Bridges

# This script is run after the installation of Proxmox VE and is intended to be used
# in conjunction with the Proxmox Autoinstall ISO.

# Env
LINUX_BRIDGE="vmbr0"
VLAN_ID="100"

# Presets
IF_FILE="/etc/network/interfaces"
BK_FILE="/etc/network/interfaces.org"
AP_FILE="/etc/network/interfaces.append"
TM_FILE="/etc/network/interfaces.edittmp"


# Ensure the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Check if the script is being run in a Proxmox environment
if [ ! -d /etc/pve ]; then
    echo "Warning: this script is intended to be run in a Proxmox environment" >&2
fi

# Check if the network interfaces file exists
if [ ! -f ${IF_FILE} ]; then
    echo "Network interfaces file not found: ${IF_FILE}" >&2
    exit 1
fi

# Backup the original network interfaces file
cp ${IF_FILE} ${BK_FILE}  || {
    echo "Failed to backup ${IF_FILE}" >&2
    exit 1
}

set -e


# Extract the original linux bridge block
echo "TARGET:"
awk -v lnbr="$LINUX_BRIDGE" '
  $0 ~ "auto "lnbr"$" {inblock=1; print; next}
  inblock && !NF {inblock=0; next}
  inblock {print; next}
  ' "${IF_FILE}"

# Get address and gateway from original vmbrA block
ADDRESS=$(awk -v lnbr="$LINUX_BRIDGE" '
  $0 ~ "auto "lnbr"$" {inblock=1; next}
  inblock && !NF {inblock=0; next}
  inblock && $1=="address" {print $2}
' "${IF_FILE}")

echo "ADDRESS: ${ADDRESS}"

GATEWAY=$(awk -v lnbr="$LINUX_BRIDGE" '
  $0 ~ "auto "lnbr"$" {inblock=1; next}
  inblock && !NF {inblock=0; next}
  inblock && $1=="gateway" {print $2}
' "${IF_FILE}")

echo "GATEWAY: ${GATEWAY}"

# New vmbrVVVV block to appennd
echo "ADD LINUX BRIDGE FOR VLAN ${VLAN_ID}:"

cat <<EOF > "${AP_FILE}"
auto vmbr${VLAN_ID}
iface vmbr${VLAN_ID} inet manual
        address ${ADDRESS}
        gateway ${GATEWAY}
        bridge-ports ${LINUX_BRIDGE}.${VLAN_ID}
        bridge-stp off
        bridge-fd 0
EOF
cat "${AP_FILE}"

# Remove address and gateway from vmbrA block, add vlan-aware lines
echo "VLAN-AWARE CONFIG: writing to ${TM_FILE}"
awk -v lnbr="${LINUX_BRIDGE}" '
  BEGIN {
    while (getline aline < "'"${AP_FILE}"'" > 0) {
      append = append aline "\n"
   }
  }
  $0 ~ "auto "lnbr"$" {inblock=1; print; next}
  inblock && !NF {inblock=0}
  inblock && ($1=="address" || $1=="gateway") {next}
  inblock && $1=="bridge-fd" {
    print
    print "        bridge-vlan-aware yes"
    print "        bridge-vids 2-4094"
    print ""
    print append
    next
  }
  {print}
' "${IF_FILE}" > "${TM_FILE}"


cat "${TM_FILE}"

# Replace the original file
cp -f "${TM_FILE}" "${IF_FILE}"
rm -f "${TM_FILE}"
rm -f "${AP_FILE}"

echo "DONE: Network interfaces updated for VLAN-aware bridge and new VLAN bridge."
