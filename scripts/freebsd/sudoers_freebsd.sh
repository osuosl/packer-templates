#!/bin/sh -eux

# sudo is a package; powerpc64le has no pkg repo, so skip it there (the freebsd
# user is in the wheel group and can still su to root).
case "$(uname -m)" in
powerpc)
  echo "powerpc64le has no pkg repo; skipping sudo install"
  ;;
*)
  pkg install -y sudo
  echo "freebsd ALL=(ALL) NOPASSWD: ALL" >>/usr/local/etc/sudoers
  ;;
esac
