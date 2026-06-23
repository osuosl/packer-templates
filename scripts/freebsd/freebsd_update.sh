#!/bin/sh -eux

# Apply pending security/errata patches so the image ships at the latest
# patchlevel (-pN), not just the ISO RELEASE level: bsdinstall extracts base.txz
# + kernel.txz at the plain RELEASE level from the remastered media, and this
# brings the installed base up to date over the build's NAT network.
#
# Skipped on powerpc64le (uname -m reports "powerpc"): it is a Tier 2 arch with
# no Security Officer coverage and no freebsd-update binary stream, so it stays at
# the ISO RELEASE level -- consistent with it being a base-only image (no pkg).
#
# These templates use legacy distribution sets (DISTRIBUTIONS="kernel.txz
# base.txz"), NOT pkgbase, so freebsd-update is the correct tool on 14 and 15.
case "$(uname -m)" in
powerpc)
  echo "powerpc64le has no freebsd-update stream; staying at ISO RELEASE level"
  exit 0
  ;;
esac

# Run fetch+install in ONE invocation:
#   --not-running-from-cron : required -- with no controlling tty (Packer ssh)
#                             fetch otherwise aborts.
#   fetch install (chained) : the in-invocation fetch flag makes install exit 0
#                             when there is nothing to do; a separate `install`
#                             would exit 2 ("run fetch first") on an up-to-date
#                             system and fail the build.
# For a patch-level update this is single-pass: it writes BOTH the patched kernel
# and patched world to disk (the reboot-then-install-again step is only set by
# `freebsd-update upgrade`, never by fetch), so no mid-build reboot is needed --
# the patched kernel runs when the captured image is booted. A genuine failure
# (e.g. the update mirror is unreachable) fails the build instead of shipping an
# unpatched image.
export PAGER=cat
freebsd-update --not-running-from-cron fetch install

# Show the resulting kernel + userland patchlevel in the build log.
freebsd-version -ku
