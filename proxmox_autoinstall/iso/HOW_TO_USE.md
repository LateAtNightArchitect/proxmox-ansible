# Proxmox Auto-Installation 

## Customize TOML file
## Customize Postinstall script
## Prepare ISO 
### proxmox-auto-install-assistant prepare-iso ./proxmox-ve_8.4-1.iso --fetch-from iso --answer-file ./answer.toml
### proxmox-auto-install-assistant prepare-iso ./proxmox-ve_8.4-1.iso --fetch-from iso --answer-file ./answer.toml --on-first-boot ./postinstall.sh
## Boot from ISO
## Delete first-boot settings
### apt purge proxmox-first-boot
