#!/bin/sh

touch /tmp/freq.run
/usr/share/modem/rm520n.sh >/tmp/rm520n-luci.log 2>&1 &

exit 0
