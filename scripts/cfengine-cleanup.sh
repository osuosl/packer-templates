# Cfengine Cleanup
. /tmp/common.sh
set -x

$run_cmd pkill cfservd
sed -i -e 's/.*cfexecd.*//' ${roofs}/etc/crontab
$run_cmd rm -rf /var/cfengine/repository /var/cfengine/inputs/ \
    /var/cfengine/backups/* /var/cfengine/ppkeys/root* /var/cfengine/*.db \
    /var/cfengine/cfengine.localhost.runlog
$run_cmd mkdir -p /var/cfengine/inputs/

if [ "$OS" == "gentoo" ] ; then
    $run_cmd rc-update add cfservd default
    rm ${rootfs}/bootstrap.sh
fi

