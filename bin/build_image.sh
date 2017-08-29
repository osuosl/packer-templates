#!/bin/bash
TEMPLATE=
export PATH=/opt/packer/bin:$PATH

run_help() {
  echo " Usage: $0 [-c] -t path/to/template.json"
  echo
  echo " Build packer build and compress the qcow2 file"
  echo
  echo "  -t FILE     Packer template to use"
  exit 0
}

while getopts "hcv:t:" opt ; do
  case $opt in
    t)
      TEMPLATE="$OPTARG"
      ;;
    h)
      run_help
      ;;
    *)
      ;;
  esac
done

[ -z "$TEMPLATE" ] && echo "Error: Template file not set" && exit 1

DIR_NAME="packer-$(basename -s .json $TEMPLATE)"
TEMPLATE_NAME="$(basename -s .json $TEMPLATE)"
IMAGE_NAME=$(grep vm_name $TEMPLATE | awk '{print $2}' | sed -e 's/\"//g' | sed -e 's/,//g')
FINAL_QCOW_FILE_NAME="${DIR_NAME}/${IMAGE_NAME}-compressed.qcow2"

set -xe

if [ -f $FINAL_QCOW_FILE_NAME ] ; then
   echo
   echo "A built qcow2 already present for $TEMPLATE_NAME. Skipping!"
   echo
   exit 0
fi

if [ -e chef/${TEMPLATE_NAME}/Berksfile ] ; then
  export BERKSHELF_PATH="chef/berkshelf"
  rm -rf $BERKSHELF_PATH chef/${TEMPLATE_NAME}/cookbooks chef/${TEMPLATE_NAME}/Berksfile.lock
  berks vendor -b chef/${TEMPLATE_NAME}/Berksfile chef/${TEMPLATE_NAME}/cookbooks
fi
export PACKER_LOG=1
packer build -force -debug $(basename $TEMPLATE)

if [ "$(packer version | grep ^Packer)" == "Packer v0.7.5" ] ; then
  qemu-img convert -o compat=0.10 -O qcow2 -c ${DIR_NAME}/${IMAGE_NAME}.qcow2 \
    $FINAL_QCOW_FILE_NAME
else
  qemu-img convert -o compat=0.10 -O qcow2 -c ${DIR_NAME}/${IMAGE_NAME} \
    $FINAL_QCOW_FILE_NAME
fi
