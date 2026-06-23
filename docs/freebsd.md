# FreeBSD OpenStack images

Packer templates for FreeBSD 14 and 15 OpenStack base images, on three
architectures:

| Template | Arch | Build node |
|---|---|---|
| `freebsd-14-x86_64-openstack.json.pkr.hcl`  | x86_64 (amd64)        | x86_64 KVM |
| `freebsd-15-x86_64-openstack.json.pkr.hcl`  | x86_64 (amd64)        | x86_64 KVM |
| `freebsd-14-aarch64-openstack.json.pkr.hcl` | aarch64 (arm64)       | **native aarch64 KVM** |
| `freebsd-15-aarch64-openstack.json.pkr.hcl` | aarch64 (arm64)       | **native aarch64 KVM** |
| `freebsd-14-ppc64le-openstack.json.pkr.hcl` | ppc64le (powerpc64le) | **native ppc64le KVM** |
| `freebsd-15-ppc64le-openstack.json.pkr.hcl` | ppc64le (powerpc64le) | **native ppc64le KVM** |

The aarch64 and ppc64le templates use native KVM (`qemu_binary = "qemu-kvm"`),
so they must build on a build node of the matching architecture (the aarch64 node
also needs `/usr/share/AAVMF/AAVMF_{CODE,VARS}.fd`).

## How the unattended install works

Packer's QEMU builder can only type a `boot_command` over **VNC**, which does not
work on serial-only machines such as QEMU `pseries` (ppc64le) and is fragile on
arm64 + edk2 ([hashicorp/packer#11061](https://github.com/hashicorp/packer/issues/11061)).

Instead, every arch uses FreeBSD's built-in unattended path: `bsdinstall`
**auto-runs `/etc/installerconfig` from the boot media at boot with zero
keystrokes** (see `bsdinstall(8)` / `startbsdinstall`), then reboots. So the build:

1. `bin/remaster_freebsd_iso.sh -t <template>` downloads the official `disc1.iso`,
   verifies it against the official `CHECKSUM.SHA256-*`, and remasters it with
   `xorriso` to embed `installerconfig/freebsd.installerconfig.<gpt|chrp>` as
   `/etc/installerconfig`, writing `iso/FreeBSD-<rel>-RELEASE-<arch>-custom.iso`.
   `bin/build_image.sh` runs this automatically for `freebsd-*` templates.

   Modern FreeBSD `disc1.iso` ships only a `MANIFEST` in `/usr/freebsd-dist`, not
   the `.txz` distribution sets, so a stock scripted install stops at the
   interactive **Mirror Selection** screen to fetch them. The script therefore
   also downloads the sets named in `DISTRIBUTIONS` (`base.txz`, `kernel.txz`)
   from `<mirror>/<rel>-RELEASE/`, verifies them against the on-ISO MANIFEST, and
   bakes them into `/usr/freebsd-dist` — so the install runs fully **offline**
   (no network, no mirror prompt). The sets are cached under `iso/dist-*`.

   FreeBSD ISOs are built with `makefs(8)` and embed their El Torito boot images
   *outside* the file tree, so a naive `xorriso -boot_image any replay` silently
   drops them and yields an unbootable ISO. The script therefore rebuilds boot
   explicitly per platform: for **amd64/arm64** it extracts the boot images
   (`-extract_boot_images`) + the tree, re-attaches the embedded EFI System
   Partition as an appended `0xef` partition (plus `-b boot/cdboot` for amd64
   BIOS), and rebuilds with `xorriso -as mkisofs`, keeping the original volume
   label (the media mounts `/` by that label). For **ppc64le** the CHRP boot
   equipment *is* real tree files, so it uses `-boot_image any replay`. The script
   also patches `startbsdinstall` to drop its interactive "Console type" prompt,
   which would otherwise block the unattended install on a serial console
   (arm64/ppc64le).
2. Packer boots the **custom ISO** with an empty `boot_command`
   (`iso_checksum = "none"` — the source ISO was already verified during remaster).
   `bsdinstall` partitions `da0` (UFS, **no swap**, root last), extracts the dist
   sets from the local media, runs the post-install setup (accounts, sshd,
   `SYNCDHCP`, `growfs`), and reboots.
3. The post-install reboot boots the **disk** (not the CD), so sshd comes up and
   Packer connects as `freebsd`/`freebsd` to run the `scripts/freebsd/*.sh`
   provisioners, then powers off. On **amd64** this is forced with `-boot once=d`
   (SeaBIOS). `once=d` is **not supported on the arm64 `virt` machine** (qemu:
   "no function defined to set boot device list for this architecture"), so
   aarch64/ppc64le use `-boot strict=on` and rely on the firmware (UEFI efivars /
   SLOF) booting the installed disk after the install writes its boot entry. The
   raw image is captured and uploaded with `bin/upload.sh`.

Root grows to the flavor disk on first boot via FreeBSD's native `growfs`
(`growfs_enable="YES"` + `/firstboot`), not cloud-init (upstream excludes
growpart/resizefs on BSD). Ensure the OpenStack flavor / image min-disk exceeds
the built image size (`disk_size = 6144`, i.e. 6 GB).

## Per-arch notes

- **x86_64 / aarch64:** GPT layout (bsdinstall auto-adds the BIOS `freebsd-boot` +
  UEFI `efi` partitions on amd64, just `efi` on arm64). cloud-init
  (`net/cloud-init`) and the QEMU guest agent are installed and enabled, with an
  OpenStack ConfigDrive/metadata drop-in at
  `/usr/local/etc/cloud/cloud.cfg.d/99_openstack.cfg`. Serial console for
  `nova console-log`: `comconsole,vidconsole` (amd64) / `comconsole,efi` (arm64).
  `scripts/freebsd/freebsd_update.sh` runs `freebsd-update fetch install` so the
  image ships at the latest security/errata patchlevel (`-pN`), not just the ISO
  RELEASE level. A patch update is single-pass (no mid-build reboot); both arches
  are Tier 1 with a published `freebsd-update` stream.
- **ppc64le (QEMU pseries):** chrp layout — bsdinstall defaults to MBR and
  auto-adds a PReP boot partition (`boot1.elf`); the installerconfig omits the
  scheme so this default applies (GPT on SLOF is unreliable). The console is the
  Open Firmware / spapr `hvc0` serial console (auto-detected; no `comconsole_*`
  needed). **FreeBSD builds no official powerpc64le packages** (`pkg` can't even
  bootstrap), so ppc64le is a **base-only image**: all `pkg` steps are skipped
  (no cloud-init / qemu-guest-agent / sudo / curl) and the build is just base
  FreeBSD + ssh + growfs. Because there is no cloud-init, OpenStack can't inject
  an SSH key, so the templates take an **`ssh_authorized_key`** variable that
  `scripts/freebsd/seed_ssh_key.sh` writes to the freebsd user's
  `~/.ssh/authorized_keys` (sshd is still hardened to key-only). Set it in your
  var-file, e.g. `ssh_authorized_key = "ssh-ed25519 AAAA... osl"`; without it the
  image has no usable login.

## Verification status

- **amd64:** the remaster was boot-tested in QEMU under **both SeaBIOS and OVMF
  (UEFI)** — the custom ISO boots and `bsdinstall` auto-runs `/etc/installerconfig`
  unattended. With the dist sets embedded, a full install was run **offline
  (`-net none`)**: partition `da0` → checksum/extract `base.txz`+`kernel.txz` →
  install complete → reboot, with no Mirror Selection prompt. This is the path the
  OSL x86_64 build uses.
- **arm64:** the remaster produces the correct El Torito structure (single UEFI
  entry + appended `0xef` ESP), verified against the real arm64 media; the boot
  technique is identical to the amd64 UEFI path. Do a first boot on the aarch64
  node to confirm under AAVMF.
- **ppc64le (pseries/SLOF):** the CHRP `-boot_image any replay` path is not
  boot-tested here (no ppc64le host). Verify on the POWER node that the custom ISO
  boots, auto-runs the installerconfig over the serial console, and that the
  post-install reboot boots `da0` rather than re-entering the CD installer. The
  template uses `-boot strict=on` (`once=d` is rejected on non-x86 machines); if
  it loops into the installer, set the boot order explicitly (e.g. `-prom-env
  boot-device=disk`) or detach the CD. Fallback if a custom ISO won't boot on any
  arch: rebuild it with FreeBSD's `release/<arch>/mkisoimages.sh` on a FreeBSD host.
