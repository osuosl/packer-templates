#!/bin/bash

PUBLISH=0
CHEF_VER="latest"

run_help() {
  echo
  echo " NAME:"
  echo "    $0 - deploy target image to OpenStack for further testing."
  echo
  echo " USAGE:"
  echo "    $0 [-p | -f [FILE] -c [CHEF_VER]] -n [IMG_NAME] -r [PR_NUM]"
  echo
  echo " OPTIONS:"
  echo "    -p          - Publish (publicly) the target image as '\$IMG_NAME', renaming"
  echo "                  the old '\$IMG_NAME' to '\$IMG_NAME - deprecated by PR#\$PR_NUM'"
  echo "                  and making that image private."
  echo
  echo " ARGUMENTS:"
  echo "    FILE        - Fully built image to be uploaded to OpenStack if [-p] is not"
  echo "                  specified. The image name will be: '\$IMG_NAME -PR#\$PR_NUM'."
  echo
  echo "    CHEF_VER    - Chef version used to build the image if [-p] is not set."
  echo
  echo "    IMG_NAME    - Name of the new image or name of the image to replace if"
  echo "                  [-p] is specified."
  echo
  echo "    PR_NUM      - GitHub Pull Request number to suffix private images with."
  echo
  exit 0
}

while getopts "hpf:c:n:r:" opt ; do
  case ${opt} in
    h)
      run_help
      ;;
    p)
      PUBLISH=1
      ;;
    f)
      FILE="$OPTARG"
      ;;
    c)
      CHEF_VER="$OPTARG"
      ;;
    n)
      IMG_NAME="$OPTARG"
      ;;
    r)
      PR_NUM="$OPTARG"
      ;;
  esac
done

[ -z "$1" ] && run_help
[ -z "$IMG_NAME" ] && echo "Error: IMG_NAME not set. Try '$0 -h'" && exit 1
[ -z "$PR_NUM" ] && echo "Error: PR_NUM not set. Try '$0 -h'" && exit 1

if [ "$PUBLISH" == 0 ]; then
    if [ ! -r "$FILE" ]; then echo "Error: Cannot read file '$FILE'. Try '$0 -h'" && exit 1; fi
    openstack image create --file "$FILE" --property chef-version="$CHEF_VER" --disk-format qcow2 "$IMG_NAME - PR#$PR_NUM"
    exit $?
else
  OLD_IMAGE_ID=$(openstack image show "$IMG_NAME" -f value -c id)
  NEW_IMAGE_ID=$(openstack image show "$IMG_NAME - PR#$PR_NUM" -f value -c id)
  openstack image set --name "$IMG_NAME - deprecated by PR#$PR_NUM" --private "$OLD_IMAGE_ID" && openstack image set --name "$IMG_NAME" --public "$NEW_IMAGE_ID"
  exit $?
fi
