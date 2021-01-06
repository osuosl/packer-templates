#!/bin/bash

TEMPLATE=
export PATH=/usr/local/bin:$PATH

run_help() {
  echo " Usage: $0 -t path/to/template.json"
  echo
  echo " Build and compress Packer images to a .qcow2 file"
  echo
  echo "  -t FILE     Packer template to use"
  exit 0
}

while getopts "h:t:" opt; do
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

DIR_NAME="packer-$(basename -s .json "$TEMPLATE")"
TEMPLATE_NAME="$(basename -s .json "$TEMPLATE")"
IMAGE_NAME=$(grep vm_name "$TEMPLATE " | awk '{print $2}' | sed -e 's/\"//g' | sed -e 's/,//g')
FINAL_QCOW_FILE_NAME="${DIR_NAME}/${IMAGE_NAME}-compressed.qcow2"
FINAL_RAW_FILE_NAME="${DIR_NAME}/${IMAGE_NAME}-converted.raw"

if [ -f "$FINAL_QCOW_FILE_NAME" ]; then
  echo
  echo "A built qcow2 imsage is already present for $TEMPLATE_NAME. Aborting!"
  echo
  exit 1
fi

set -xe

if [ -e "chef/${TEMPLATE_NAME}/Berksfile" ]; then
  export BERKSHELF_PATH="chef/berkshelf"
  rm -rf $BERKSHELF_PATH "chef/${TEMPLATE_NAME}/cookbooks" "chef/${TEMPLATE_NAME}/Berksfile.lock"
  berks vendor --delete -b "chef/${TEMPLATE_NAME}/Berksfile" "chef/${TEMPLATE_NAME}/cookbooks"
fi

packer build -on-error=abort -color=false -force "$(basename "$TEMPLATE")"

qemu-img convert -O qcow2 -c "${DIR_NAME}/${IMAGE_NAME}" "$FINAL_QCOW_FILE_NAME"
qemu-img convert -O raw "${DIR_NAME}/${IMAGE_NAME}" "$FINAL_RAW_FILE_NAME"
