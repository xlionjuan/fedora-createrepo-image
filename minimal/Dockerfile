FROM registry.fedoraproject.org/fedora-minimal:41

LABEL org.opencontainers.image.description="Simple container image just for create RPM repo."

RUN microdnf -y install createrepo_c reprepro dpkg jq wget rpm-sign gnupg git \
    --setopt=install_weak_deps=False \
    && microdnf clean all \
    && rm -rf /var/cache/libdnf5 /var/log/dnf5.log /var/lib/rpm/__db*