#!/bin/bash

FILE=/usr/lib/systemd/system/cloud-init.service
sed -i '/^Wants/s/$/ sshd.service/' $FILE
grep -q Before $FILE && sed -i '/Before/s/$/ sshd.service/' $FILE ||  sed -i '/[Unit]/aBefore=sshd.service' $FILE
