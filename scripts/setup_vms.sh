#!/bin/sh

STORAGE_POOL_ROOT=/var/lib/libvirt/images
BRIDGE=bridge0
DOMAIN=local
TIMEZONE=Europe/London
SSH_KEY=$( cat ~/.ssh/id_rsa.pub )
CENTOS_IMAGE=/data/vm_images/CentOS-7-x86_64-GenericCloud.qcow2
OKD_VM_MEMORY=4096
OKD_VM_VCPU=2
OKD_GLUSTERFS_DISKSIZE=20G
LB_VM_MEMORY=1024
LB_VM_VCPU=1
MASTERS="okd-311-master-1 okd-311-master-2 okd-311-master-3"
LOAD_BALANCER="okd-311-lb"


# Create cloudinit iso
create_cloud_init() {
  echo "Setting up cloud-init iso for ${VM}"
  # Create meta-data
  cat << EOF > ${STORAGE_POOL_DIR}/meta-data
instance-id: ${VM}
local-hostname: ${VM}
EOF

  # Create user-data
  cat << EOF > ${STORAGE_POOL_DIR}/user-data
#cloud-config
preserve_hostname: False
hostname: ${VM}
fqdn: ${VM}.${DOMAIN}
ssh_authorized_keys:
  - ${SSH_KEY}
output:
  all: ">> /var/log/cloud-init.log"
timezone: ${TIMEZONE}
runcmd:
  - systemctl stop network && systemctl start network
  - yum -y remove cloud-init
  - yum -y install avahi
  - systemctl enable --now avahi-daemon
EOF

  # Create cloud-init.iso
  mkisofs -o ${STORAGE_POOL_DIR}/${VM}-config.iso -V cidata -J -r ${STORAGE_POOL_DIR}/user-data ${STORAGE_POOL_DIR}/meta-data

}

create_storage_pool_dir() {
  echo "Creating storage pool dir for ${VM}"
  if [ -d ${STORAGE_POOL_DIR} ] ; then
    echo "Looks like VM is already created - exiting."
    exit 1
  else
    mkdir ${STORAGE_POOL_DIR}
  fi
}

create_base_disk() {
  echo "Setting up base image for ${VM}"
  qemu-img create -f qcow2 -o preallocation=metadata ${STORAGE_POOL_DIR}/${VM}-vda.qcow2 ${ROOT_DISKSIZE}
  virt-resize --expand /dev/sda1 ${CENTOS_IMAGE} ${STORAGE_POOL_DIR}/${VM}-vda.qcow2
}

create_glusterfs_disk() {
  echo "Setting up glusterfs disks for ${VM}"
  for DISK in vdb vdc vdd
  do
    qemu-img create -f qcow2 -o preallocation=metadata ${STORAGE_POOL_DIR}/${VM}-${DISK}.qcow2 ${OKD_GLUSTERFS_DISKSIZE}
  done
}

create_storage_pool() {
  echo "Setting up storage pool for ${VM}"
  cd ${STORAGE_POOL_DIR}
  virsh pool-create-as --name ${VM} --type dir --target /var/lib/libvirt/images/${VM}
}

create_okd_vm() {
  echo "Setting up virtual machine ${VM}"
  cd ${STORAGE_POOL_DIR}
  virt-install --import --name ${VM} \
  --memory ${OKD_VM_MEMORY} --vcpus ${OKD_VM_VCPU} --cpu host \
  --disk ${VM}-vda.qcow2,format=qcow2,bus=virtio \
  --disk ${VM}-vdb.qcow2,format=qcow2,bus=virtio \
  --disk ${VM}-vdc.qcow2,format=qcow2,bus=virtio \
  --disk ${VM}-vdd.qcow2,format=qcow2,bus=virtio \
  --disk ${VM}-config.iso,device=cdrom \
  --network bridge=${BRIDGE},model=virtio \
  --os-type=linux \
  --os-variant=centos7.0 \
  --graphics none \
  --noautoconsole
}

create_lb_vm() {
  echo "Setting up virtual machine ${VM}"
  cd ${STORAGE_POOL_DIR}
  virt-install --import --name $VM \
  --memory ${LB_VM_MEMORY} --vcpus ${LB_VM_VCPU} --cpu host \
  --disk ${VM}-vda.qcow2,format=qcow2,bus=virtio \
  --disk ${VM}-config.iso,device=cdrom \
  --network bridge=${BRIDGE},model=virtio \
  --os-type=linux \
  --os-variant=centos7.0 \
  --graphics none \
  --noautoconsole
}

for VM in ${MASTERS}
do
  STORAGE_POOL_DIR=${STORAGE_POOL_ROOT}/${VM}
  ROOT_DISKSIZE=40G
  create_storage_pool_dir
  create_cloud_init
  create_base_disk
  create_glusterfs_disk
  create_storage_pool
  create_okd_vm
done

for VM in ${LOAD_BALANCER}
do
  STORAGE_POOL_DIR=${STORAGE_POOL_ROOT}/${VM}
  ROOT_DISKSIZE=20G
  create_storage_pool_dir
  create_cloud_init
  create_base_disk
  create_storage_pool
  create_lb_vm
done

