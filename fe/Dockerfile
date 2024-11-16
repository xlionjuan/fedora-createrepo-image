FROM registry.fedoraproject.org/fedora:41

LABEL org.opencontainers.image.description="Simple container image just for create RPM and APT repo."

RUN dnf -y install createrepo_c reprepro dpkg deb-reversion jq wget rpm-sign gnupg git \
    rpm-build binutils policycoreutils policycoreutils-python-utils selinux-policy-devel \
    --setopt=install_weak_deps=False \
    --setopt=keepcache=True \
    && rm -rf /var/log/dnf5.log

    # From the line of the rpm-build is the requirements of the SELinux config rpm builder 
