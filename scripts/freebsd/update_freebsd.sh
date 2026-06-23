#!/bin/sh -eux

# Update the pkg catalog. Skipped on powerpc64le, which has no pkg repository
# (FreeBSD builds no official powerpc64le packages, so pkg can't bootstrap).
case "$(uname -m)" in
powerpc)
  echo "powerpc64le has no pkg repo; skipping pkg update"
  ;;
*)
  env ASSUME_ALWAYS_YES=true pkg update
  ;;
esac
