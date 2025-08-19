#!/bin/bash

run_help() {
  echo
  echo " NAME:"
  echo "    $0 - Upload target image to OpenStack"
  echo
  echo " USAGE:"
  echo "    $0 [-v | -f [FILE] -n [IMG_NAME]"
  echo
  echo " OPTIONS:"
  echo "    -v          - Show verbose output."
  echo
  echo " ARGUMENTS:"
  echo "    FILE        - Fully built image to be uploaded to OpenStack if [-p] is not"
  echo "                  specified. The image name will be: '\$IMG_NAME -PR#\$PR_NUM'."
  echo
  echo "    IMG_NAME    - Name of the new image or name of the image to replace if"
  echo "                  [-p] is specified."
	echo
  echo "    OPTIONS     - Raw options for the image. i.e. '--property <key1=value> --property <key2=value>'"
  exit 0
}

IMG_TYPE="raw"

while getopts "hpvf:c:n:r:d:o:t:" opt ; do
  case ${opt} in
    h)
      run_help
      ;;
    v)
      set -x
      ;;
    f)
      FILE="$OPTARG"
      ;;
    n)
      IMG_NAME="$OPTARG"
      ;;
    t)
      IMG_TYPE="$OPTARG"
      ;;
    o)
      OPTIONS="$OPTARG"
      ;;
    *)
      run_help
      ;;
  esac
done

[ -z "$1" ] && run_help
[ -z "$IMG_NAME" ] && echo "Error: IMG_NAME not set. Try '$0 -h'" && exit 1

openstack image create \
  --progress \
  --file "$FILE" \
  --disk-format "$IMG_TYPE" \
  --property hw_scsi_model=virtio-scsi \
  --property hw_disk_bus=scsi \
  --property hw_qemu_guest_agent=yes \
  --property os_require_quiesce=yes \
  $OPTIONS \
  "$IMG_NAME"
