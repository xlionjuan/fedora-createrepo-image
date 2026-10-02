FROM quay.io/fedora/fedora:43@sha256:15ecc6538eaf7d8a074e08880ce8769a0e2f43f70862a68c01f5fd2738f9a6f6

LABEL org.opencontainers.image.description="Simple container image just for create RPM and APT repo."

COPY scripts/* /usr/bin

# devscripts: Scripts for Debian Package maintainers
# The set opt will write to /etc/dnf/repos.override.d
# https://dnf5.readthedocs.io/en/latest/dnf5_plugins/config-manager.8.html
RUN dnf5 config-manager setopt fedora-cisco-openh264.enabled=0 &&\
    dnf -y install createrepo_c devscripts reprepro jq wget2-wget tree rpm-sign gnupg git rpm-build gh \
   # binutils policycoreutils policycoreutils-python-utils selinux-policy-devel \
    --setopt=install_weak_deps=False \
    --setopt=keepcache=True &&\
    dnf -y install ruby rubygem-json \
    --setopt=keepcache=True \
    --exclude=rubygem-rdoc &&\
    rm -rf /var/log/dnf*.log /root/.cache /usr/share/locale

    # From the line of the binutils is the requirements of the SELinux config rpm builder 

COPY aptly.sh /tmp/aptly.sh
RUN /tmp/aptly.sh

RUN gem update --system --no-document &&\
    gem install fpm --no-document &&\
    gem clean &&\
    rm -rf /root/.cache
