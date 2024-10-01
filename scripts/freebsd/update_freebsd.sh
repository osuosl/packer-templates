#!/bin/sh -eux

# Update FreeBSD
# NOTE: the install action fails if there are no updates so || true it
env ASSUME_ALWAYS_YES=true pkg update;
