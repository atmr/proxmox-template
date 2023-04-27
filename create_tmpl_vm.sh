#!/bin/bash

TMP_FOLDER="/tmp"

source ./sensitive_data

wget http://cloud-images.ubuntu.com/minimal/releases/${CODENAME}/release/ubuntu-${RELEASE}-minimal-cloudimg-amd64.img -P ${TMP_FOLDER}

echo "Install libguestfs-tools"
sudo apt install libguestfs-tools -y

echo "Install qemu-guest-agent to image"
sudo virt-customize -a ${TMP_FOLDER}/ubuntu-$RELEASE-minimal-cloudimg-amd64.img --install qemu-guest-agent

cat <<EOF > ${TMP_FOLDER}/run.sh

qm create ${TEMPLATE_ID} \
  --name ubuntu-${CODENAME}-cloud-init --numa 0 --ostype l26 \
  --cores 1 --sockets 1 \
  --memory 1024  \
  --serial0 socket \
  --vga serial0 \
  --ide2 local-lvm:cloudinit \
  --scsihw virtio-scsi-pci \
  --agent 1 \
  --net0 virtio,bridge=vmbr0

qemu-img resize /tmp/ubuntu-${RELEASE}-minimal-cloudimg-amd64.img ${DISK_SIZE}

qm set ${TEMPLATE_ID} --scsi0 local-lvm:0,import-from=/tmp/ubuntu-${RELEASE}-minimal-cloudimg-amd64.img

qm set ${TEMPLATE_ID} --boot order='scsi0;ide2;net0,' --bootdisk scsi0

# qm set ${TEMPLATE_ID} --cicustom "user=local:snippets/cloud-init.yaml"

echo ${SSH_PUB_KEY} > /tmp/ssh.pub

qm set ${TEMPLATE_ID} \
--ipconfig0 ip=dhcp \
--ciuser ${CIUSER} \
--nameserver ${CINAMESERVER} \
--searchdomain ${CISEARCHDOMAIN} \
--cipassword ${CIPASSWORD} \
--sshkeys /tmp/ssh.pub

qm template ${TEMPLATE_ID}

rm /tmp/ubuntu-${RELEASE}-minimal-cloudimg-amd64.img /tmp/run.sh /tmp/ssh.pub

EOF

echo "Copy image and script to Proxmox Node ${PROXMOX_HOST}:"
scp ${TMP_FOLDER}/ubuntu-${RELEASE}-minimal-cloudimg-amd64.img ${TMP_FOLDER}/run.sh root@${PROXMOX_HOST}:/tmp/

echo "Run script on Proxmox Node ${PROXMOX_HOST}:"
ssh root@${PROXMOX_HOST} ". /tmp/run.sh"

rm  ${TMP_FOLDER}/ubuntu-${RELEASE}-minimal-cloudimg-amd64.img ${TMP_FOLDER}/run.sh
