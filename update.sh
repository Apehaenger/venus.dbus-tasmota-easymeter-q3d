#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SERVICE_NAME=$(basename $SCRIPT_DIR)

echo -e "\nSCRIPT_DIR '$SCRIPT_DIR', SERVICE_NAME '$SERVICE_NAME'\n"
read

cd $SCRIPT_DIR
git pull
kill $(pgrep -f "python $SCRIPT_DIR/$SERVICE_NAME.py")