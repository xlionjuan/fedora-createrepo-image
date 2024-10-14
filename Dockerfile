FROM fedora:latest

RUN dnf -y install createrepo_c jq wget rpm-sign gnupg git
