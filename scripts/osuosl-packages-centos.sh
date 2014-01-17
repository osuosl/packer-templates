# OSUOSL Specific setup
. /tmp/common.sh
set -x

# add epel repo, exclude cfengine (we don't want version > 3.0)
cat > /etc/yum.repos.d/epel.repo << EOM
[epel]
name=epel
baseurl=http://epel.osuosl.org/${OSRELEASE}/\$basearch
enabled=1
gpgcheck=0
exclude=cfengine
EOM

# Remove extra packages
$yum remove gnome-mount gtk2 cups cups-libs libX11 libXau libXdmcp atk \
    alsa-lib audiofile portmap ppp avahi

# Set yum repos to us
for i in CentOS-Base epel ; do
  sed -i -e 's/^\(mirrorlist.*\)/#\1/g' /etc/yum.repos.d/$i.repo
done
sed -i -e 's/^#baseurl=.*$releasever\/os\/$basearch\//baseurl=http\:\/\/centos.osuosl.org\/$releasever\/os\/$basearch\//g' /etc/yum.repos.d/CentOS-Base.repo
sed -i -e 's/^#baseurl=.*$releasever\/updates\/$basearch\//baseurl=http\:\/\/centos.osuosl.org\/$releasever\/updates\/$basearch\//g' /etc/yum.repos.d/CentOS-Base.repo
sed -i -e 's/^#baseurl=.*$releasever\/addons\/$basearch\//baseurl=http\:\/\/centos.osuosl.org\/$releasever\/addons\/$basearch\//g' /etc/yum.repos.d/CentOS-Base.repo
sed -i -e 's/^#baseurl=.*$releasever\/extras\/$basearch\//baseurl=http\:\/\/centos.osuosl.org\/$releasever\/extras\/$basearch\//g' /etc/yum.repos.d/CentOS-Base.repo
sed -i -e 's/^#baseurl=.*$releasever\/centosplus\/$basearch\//baseurl=http\:\/\/centos.osuosl.org\/$releasever\/centosplus\/$basearch\//g' /etc/yum.repos.d/CentOS-Base.repo
sed -i -e 's/^#baseurl=.*$releasever\/contrib\/$basearch\//baseurl=http\:\/\/centos.osuosl.org\/$releasever\/contrib\/$basearch\//g' /etc/yum.repos.d/CentOS-Base.repo
sed -i -e 's/^#baseurl=.*pub\/epel\/5\/$basearch$/baseurl=http\:\/\/epel.osuosl.org\/$releasever\/$basearch\//g' /etc/yum.repos.d/epel.repo
sed -i -e 's/^#baseurl=.*pub\/epel\/5\/$basearch\/debug$/baseurl=http\:\/\/epel.osuosl.org\/$releasever\/$basearch\/debug\//g' /etc/yum.repos.d/epel.repo
sed -i -e 's/^#baseurl=.*pub\/epel\/5\/$basearch\/SRPMS$/baseurl=http\:\/\/epel.osuosl.org\/$releasever\/$basearch\/SRPMS\//g' /etc/yum.repos.d/epel.repo

rsync -q ${cfengine_host}::yumrepo-osl/centos/osl.repo /etc/yum.repos.d/osl.repo
$yum upgrade
rpm -e sysklogd --nodeps
$yum install syslog-ng

