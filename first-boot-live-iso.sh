#!/bin/bash
firstboot_args='console=tty0 rd.neednet=1'
#KERNEL_ARGS="ip=<node-ip>::<default-gw>:<mask>:<hostname>:<nic>:none:<dns>"

# Remove any existing VGs and PVs
#for vg in $(vgs -o name --noheadings) ; do vgremove -y $vg ; done
#for pv in $(pvs -o name --noheadings) ; do pvremove -y $pv ; done

if [ -b /dev/vda ] && [ "$(lsblk /dev/vda)" != "" ] ; then
  install_device='/dev/vda'
elif [ -b /dev/sda ] && [ "$(lsblk /dev/sda)" != "" ] ; then
  install_device='/dev/sda'
else
  # when prefered block device not detected
  # deploy to the first block device detected
  # ignores any sr0 or cdrom0 devie
  first_block_dev=$(lsblk -lpdn -o NAME | egrep -v "sr0|loop|cdrom0" | sed -n '1 p')
  if [[ $first_block_dev ]]; then
    install_device=$first_block_dev
  else
    echo "Can't find block device for installation"
    exit 1
  fi
fi

#cmd="coreos-installer install --firstboot-args=\"${firstboot_args}\" --append-karg=\"${KERNEL_ARGS}\" --ignition=/root/config.ign ${install_device}"
cmd="coreos-installer install --firstboot-args=\"${firstboot_args} ${KERNEL_ARGS}\" --ignition=/root/config.ign ${install_device}"
bash -c "$cmd"
if [ "$?" == "0" ] ; then
  echo "Install Succeeded!"
  reboot
else
  echo "Install Failed!"
  exit 1
fi
