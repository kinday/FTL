#!/usr/bin/bash

wget -O libsystemd.apk "https://github.com/Artox/alpine-systemd/releases/download/1/libsystemd-249-r0.$(uname -m).apk"

apk add --allow-untrusted libsystemd.apk
