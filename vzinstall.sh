#!/bin/bash

REDHAT_RELEASE=/etc/redhat-release
SYSCTL_DIR=/etc/sysctl.d
SYSCTL_CONF=$SYSCTL_DIR/openvz.conf
OPENVZ_REPO=http://ftp.openvz.org/openvz.repo
YUM_REPOS_DIR=/etc/yum.repos.d
OPENVZ_REPO_CONF=$YUM_REPOS_DIR/openvz.repo
RPM_GPG_KEY_URL=http://ftp.openvz.org/RPM-GPG-Key-OpenVZ

function announce () {
    echo -e "\
\033[36m$*\033[0m"
    GOOD=0
}

function good () {
    GOOD=1
    echo -e "\033[34mLOOKS GOOD!\033[0m"
}

function on_bad () {
    if [ $GOOD != 1 ] ; then
        die $*
    fi
}

function die () {
    echo -e "\
\033[31m$* \

Aborted.\033[0m 
"
    exit 1;
}


function check-distro () {
    announce "Checking distribution"
    if [ -e $REDHAT_RELEASE ] ; then
        cat $REDHAT_RELEASE
        good
    fi

    on_bad "RedHat Release is not exists!"
}

function create-sysctl () {
    announce "Creating sysctl entry in $SYSCTL_CONF"
    cat > $SYSCTL_CONF <<EOF
# On Hardware Node we generally need
# packet forwarding enabled and proxy arp disabled
net.ipv4.ip_forward = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.forwarding = 1
net.ipv4.conf.default.proxy_arp = 0

# Enables source route verification
net.ipv4.conf.all.rp_filter = 1

# Enables the magic-sysrq key
kernel.sysrq = 1

# We do not want all our interfaces to send redirects
net.ipv4.conf.default.send_redirects = 1
net.ipv4.conf.all.send_redirects = 0
EOF
    if [ -e $SYSCTL_CONF ] ; then
        good
    fi

    on_bad "Could not create $SYSCTL_CONF"
}

function import-rpm-gpg-key () {
    announce "Fetching openvz repository information from $OPENVZ_REPO."
    announce "And, Importing RPM-GPG-KEY from $RPM_GPG_KEY_URL"

    if [ -e $OPENVZ_REPO_CONF ] ; then
        good
    else 
        wget -P $YUM_REPOS_DIR/ $OPENVZ_REPO &&
            rpm --import $RPM_GPG_KEY_URL && good
    fi

    on_bad "Failure!"
}

function install-openvz () {
    announce "Installing vzkernel and some vz-tools"
    yum -y install vzkernel &&
        yum -y install vzctl vzquota ploop &&
        good

    on_bad "Failure to install!"
}

function disable-selinux () {
    announce "Tuen off SELinux"
    echo "SELINUX=disabled" > /etc/sysconfig/selinux && good

    on_bad "Failure!"
}

function finish-install () {
    announce 'Installation finished.'
    cat <<EOF

You have to reboot this machine for enable openvz kernel.

enjoy!

EOF
}

check-distro &&
    import-rpm-gpg-key &&
    install-openvz &&
    create-sysctl &&
    disable-selinux &&
    finish-install
