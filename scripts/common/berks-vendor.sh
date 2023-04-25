#!/bin/bash -eux
rm -rf Berksfile.lock cookbooks
berks vendor cookbooks
