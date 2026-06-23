#!/bin/sh -eux

# Workaround for a FreeBSD 15 ports issue where some packages link against an
# older libmd. Guarded so it is a safe no-op when the target already exists or the
# source library is absent (e.g. on 15.1-RELEASE this is typically not needed).
if [ ! -e /lib/libmd.so.6 ] && [ -e /lib/libmd.so.7 ]; then
  ln -s /lib/libmd.so.7 /lib/libmd.so.6
fi
