#!/bin/bash -eux
curl https://omnitruck.cinc.sh/install.sh | bash
mkdir -p /tmp/cinc/cache /tmp/cinc/cookbooks
chmod -R 777 /tmp/cinc
