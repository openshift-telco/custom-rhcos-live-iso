#!/bin/bash

source ~/set-environment

# inject console password? yes|no
CORE_USER_CONSOLE="no"

#######################################
## DO NOT MODIFY AFTER THIS LINE
#######################################

ADDING_NODES=${1:-"add-nodes"}
USE_RENDERED=${2:-"true"}

if [ ! -f rhcos-live.x86_64.iso ]; then
  if [ -f ${RHCOS_LIVE_PATH} ] && [ ! -z "${RHCOS_LIVE_PATH}" ]; then
    echo "Taking copy of live ISO from ${RHCOS_LIVE_PATH}"
    cp ${RHCOS_LIVE_PATH} ./rhcos-live.x86_64.iso
  else
    echo "ERROR: Can not find base RHCOS Live ISO image on local directory. Set RHCOS_LIVE_PATH with correct location."
    echo "Try: curl -OL https://mirror.openshift.com/pub/openshift-v4/dependencies/rhcos/latest/latest/rhcos-live.x86_64.iso "
    exit 1
  fi 
fi

COREOSINSTALLER="podman run --privileged --rm --env-host -v /dev:/dev -v /run/udev:/run/udev -v $PWD:/data -w /data quay.io/coreos/coreos-installer:release"

show_usage(){
  echo -e "$0   [ new | add-nodes [true|false] ]"
  echo -e "\t new             : create Live ISO images for new deployment using UPI based ignition files"
  echo -e "\t add-nodes       : create Live ISO image to add nodes out of rendered MCP or from existing UPI base ignition file"
  echo -e "\t add-nodes true  : use rendered ignition files from api-int (default behaviour)"
  echo -e "\t add-nodes false : use UPI base ignition file from ~/${CLUSTER_NAME} directory"
}

generate_iso(){
  role=$1
  echo "Generating ISO image for $role"
  rm -f ./${CLUSTER_NAME}-$role.iso
  bash create-ign-for-live-iso.sh
  $COREOSINSTALLER iso ignition embed -fi iso.ign -o /data/${CLUSTER_NAME}-$role.iso rhcos-live.x86_64.iso
  #cp -f ./${CLUSTER_NAME}-$role.iso /opt/nginx/html/${CLUSTER_NAME}-$role.iso
}

if [[ $# -eq 0 ]] ; then
    echo "Missing arguments"
    show_usage
    exit 1
fi

if [ $ADDING_NODES == "add-nodes" ]; then
  echo "Using 'add-nodes' flows"
  # If doing live ISOs for adding nodes to an existing control plane
  for MCP_NAME in ${MCP_RWN[*]}; do
    if [ $USE_RENDERED == "false" ]; then
      echo "Using existing worker.ign as base for new MCP"
      # Creating base Ign for MCPs
      sed "s/worker/${role}/g" ~/${CLUSTER_NAME}/worker.ign > config.ign
    else
      # Pulling rendered MCP
      echo "Using rendered MCP as source ignition file"
      curl -o preconfig.ign -H "Accept: application/vnd.coreos.ignition+json; version=3.1.0" -Lk https://api-int.${CLUSTER_NAME}.${BASE_DOMAIN}:22623/config/$MCP_NAME
      if [ $CORE_USER_CONSOLE == "yes" ]; then
        # Inject console password (unix1234)
        cat preconfig.ign | jq '.passwd.users[0] += {"passwordHash": "$1$f9F1p5ap$VIFGF2QHttm6xPeGMh/YA/"}' > config.ign
      else
        cp preconfig.ign config.ign
      fi
      generate_iso $MCP_NAME
    fi
  done
elif [ $ADDING_NODES == "new" ]; then
  # If doing local profiles for new UPI install
  MCP_LIST=( bootstrap master worker )
  for MCP_NAME in ${MCP_LIST[*]}; do 
    cp ~/${CLUSTER_NAME}/${MCP_NAME}.ign config.ign
    generate_iso $MCP_NAME
  done
else
  echo "Not a valid option"
  show_usage
  exit 1
fi

#
# END OF FILE
#