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

TEMPLATE_NAME="$(basename "$TEMPLATE" | sed -E 's/\.(json\.pkr\.hcl|pkr\.hcl|json)$//')"
# vm_name as the last quoted token on its line -- works for both JSON ("vm_name":
# "x") and HCL (vm_name = "x"); the old `awk '{print $2}'` returned "=" for HCL.
IMAGE_NAME="$(grep vm_name "$TEMPLATE" | grep -oE '"[^"]+"' | tail -1 | tr -d '"')"
# HCL openstack templates set no output_directory, so Packer writes to
# output-<source name>; the older .json templates set output_directory=packer-<name>.
case "$TEMPLATE" in
  *.pkr.hcl)
    SRC_NAME="$(grep -oE 'source[[:space:]]+"qemu"[[:space:]]+"[^"]+"' "$TEMPLATE" | grep -oE '"[^"]+"' | tail -1 | tr -d '"')"
    DIR_NAME="output-${SRC_NAME}"
    ;;
  *)
    DIR_NAME="packer-${TEMPLATE_NAME}"
    ;;
esac
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

# FreeBSD and ArchPOWER templates install unattended from a remastered ISO (neither
# has a preseed/kickstart-style autoinstaller). Build that custom ISO first.
case "$(basename "$TEMPLATE")" in
  freebsd-*-openstack*)
    ./bin/remaster_freebsd_iso.sh -t "$TEMPLATE"
    ;;
  archpower-*-openstack*)
    ./bin/remaster_archpower_iso.sh -t "$TEMPLATE"
    ;;
esac

packer build -on-error=abort -color=false -force "$(basename "$TEMPLATE")"

qemu-img convert -O qcow2 -c "${DIR_NAME}/${IMAGE_NAME}" "$FINAL_QCOW_FILE_NAME"
qemu-img convert -O raw "${DIR_NAME}/${IMAGE_NAME}" "$FINAL_RAW_FILE_NAME"
