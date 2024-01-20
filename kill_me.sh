#!/bin/bash
svc -d /service/dbus-tasmota-easymeter-q3d
kill $(pgrep -f 'python /data/dbus-tasmota-easymeter-q3d/dbus-tasmota-easymeter-q3d.py')
