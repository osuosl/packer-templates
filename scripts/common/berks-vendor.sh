#!/bin/bash -eux
rm -rf packer_templates/Berksfile.lock cookbooks
berks vendor cookbooks -b packer_templates/Berksfile
