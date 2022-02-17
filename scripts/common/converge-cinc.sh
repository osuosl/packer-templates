#!/bin/bash -eux
/opt/cinc/bin/cinc-client \
  --local-mode \
  --config /tmp/cinc/client.rb \
  --log_level auto \
  --force-formatter \
  --no-color \
  --json-attributes /tmp/cinc/dna.json \
  --chef-zero-port 8889

# TODO: https://github.com/chef/chef/issues/11975
if [ -e /tmp/cinc/results.json ] ; then
  if grep -q failed /tmp/cinc/results.json ; then
    echo "Integration test failed" && exit 1
  else
    echo "Integration test passed!"
  fi
fi
