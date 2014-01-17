# Cfengine
. /tmp/common.sh
set -x

if [ "$OS" == "centos" ] ; then
    $yum install cfengine
    /usr/bin/rsync -qr ${cfengine_host}::cfengine64 /var/cfengine/
elif [ "$OS" == "gentoo" ] ; then
    sed -i -e 's/passwd/echo \"root:vagrant\" \| chpasswd/' /mnt/gentoo/bootstrap.sh
fi

# Grab latest repo for local use
$run_cmd /usr/bin/rsync -qr ${cfengine_host}::cfengine-repo /var/cfengine/repository

# Change gold host to be local
sed -i -e 's/gold .*=.*/gold = ( localhost ) /' ${rootfs}/var/cfengine/inputs/update.conf
sed -i -e 's/gold .*=.*/gold = ( localhost ) /' \
    ${rootfs}/var/cfengine/repository/cfengine/inputs/{update.conf,cf.main}

# start up local cfservd
$run_cmd /usr/sbin/cfservd

# run cfengine
if [ "$OS" == "centos" ] ; then
    /usr/sbin/cfagent -q --update-only
    /usr/sbin/cfagent -q -D install_only -D $cf_class
    /usr/sbin/cfagent -q -D install_only -D $cf_class
elif [ "$OS" == "gentoo" ] ; then
    $run_cmd eselect python set python2.7
    $run_cmd /bootstrap.sh -D $cf_class
fi

