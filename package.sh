#!/bin/bash
cd ~
rm -f dash.tgz
tar czvf dash.tgz --exclude-vcs --exclude='*~' dash/reportuser.sql dash/bin dash/INSTALL dash/config.yml dash/environments dash/lib dash/public dash/views
