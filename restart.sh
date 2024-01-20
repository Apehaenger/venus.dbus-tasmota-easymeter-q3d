#!/bin/bash
#svc -d /service/dbus-tasmota-easymeter-q3d
#kill $(pgrep -f 'python /data/dbus-tasmota-easymeter-q3d/dbus-tasmota-easymeter-q3d.py')

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SERVICE_NAME=$(basename $SCRIPT_DIR)

echo -e "\nSCRIPT_DIR '$SCRIPT_DIR', SERVICE_NAME '$SERVICE_NAME'\n"
read

kill $(pgrep -f "python $SCRIPT_DIR/$SERVICE_NAME.py")