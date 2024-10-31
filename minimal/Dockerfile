FROM registry.fedoraproject.org/fedora-minimal:41

LABEL org.opencontainers.image.description="Simple container image just for create RPM repo."

RUN microdnf -y install createrepo_c reprepro dpkg jq wget rpm-sign gnupg git \
    --setopt=install_weak_deps=False \
    --setopt=keepcache=True \
    && rm -rf /var/log/dnf5.log