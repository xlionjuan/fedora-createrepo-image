FROM quay.io/fedora/fedora:43@sha256:ab2f1c21441452f4d380352a2bb003eccf986fd5d0a007ac2ff6bddb43505ca7

LABEL org.opencontainers.image.description="Simple container image just for create RPM and APT repo."

# devscripts: Scripts for Debian Package maintainers

RUN dnf -y install createrepo_c devscripts reprepro jq wget2-wget tree rpm-sign gnupg git rpm-build gh \
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
