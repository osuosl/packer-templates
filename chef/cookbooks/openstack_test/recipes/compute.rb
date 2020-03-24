# This fails during packer installs so disable these resources
delete_resource(:file, '/etc/modprobe.d/options_kvm-intel.conf')
delete_resource(:kernel_module, 'kvm-intel')
