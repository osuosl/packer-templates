#!/bin/bash -eux
FILE=/etc/ssh/sshd_config

grep -q 'UseDNS .*' $FILE && sed -i 's/\(^# \)UseDNS .*/UseDNS no/Ig' $FILE || echo 'UseDNS no' >> $FILE

grep -q 'PermitRootLogin .*' $FILE && sed -i 's/\(^# \)PermitRootLogin .*/PermitRootLogin no/Ig' $FILE || echo 'PermitRootLogin no' >> $FILE

grep -q 'GSSAPIAuthentication .*' $FILE && sed -i 's/\(^# \)GSSAPIAuthentication .*/GSSAPIAuthentication no/Ig' $FILE || echo 'GSSAPIAuthentication no' >> $FILE

grep -q 'KbdInteractiveAuthentication .*' $FILE && sed -i 's/\(^# \)KbdInteractiveAuthentication .*/KbdInteractiveAuthentication no/Ig' $FILE || echo 'KbdInteractiveAuthentication no' >> /etc/ssh/sshd_config

grep -q 'PasswordAuthentication .*' $FILE && sed -i 's/\(^# \)PasswordAuthentication .*/PasswordAuthentication no/Ig' $FILE || echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config

grep -q 'ChallengeResponseAuthentication .*' $FILE && sed -i 's/\(^# \)ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/Ig' $FILE || echo 'ChallengeResponseAuthentication no' >> /etc/ssh/sshd_config
