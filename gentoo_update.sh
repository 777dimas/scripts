#!/bin/bash

# update portage tree
emerge-webrsync && \
# full update exclude next packages:
# 1.gentoo-sources
# 2.libreoffice
# 3.gcc
emerge -avuDN world --exclude gentoo-sources --exclude sys-devel/gcc --exclude libreoffice && \
# update /etc
etc-update && \
# Remove old package version
# emerge --depclean 
# Smart checking and rebuilding broken dependencies
emerge @smart-live-rebuild && \
# restart profile
source /etc/profile && \
# delete unused sources
eclean-dist

