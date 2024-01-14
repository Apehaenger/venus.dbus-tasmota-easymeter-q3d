#!/bin/bash
DATA_DIR="/data"
#SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SERVICE_NAME="dbus-tasmota-easymeter-q3d"

# Greeting and major information
cat << EOF
This script will install '$SERVICE_NAME' service for VenusOS.
At any place you may press 'Ctrl-c' to abort the installation process!

In detail, this script does the following:
1. Check if /data partition exists and has enough space. If not, installation will abort with a message.
2. Check if 'git' command exists. If not tries to install it via systems 'opkg'.

EOF

read -p "Press any key to continue or 'Ctrl-c' to abort... " -n1

##### Validate /data #####
echo -en "\n1. Check '$DATA_DIR'..."
if [[ ! -d $DATA_DIR ]]; then
    echo "failed!"
    echo "ERROR: Haven't found '$DATA_DIR' directory(partition)! Are your sure that you started this install script on a VenusOS device?"
    exit 1
fi

# Free blocks * blocksize of /data
DATA_FREE=$(($(stat -fc "%a*%s" $DATA_DIR)))
# FIXME: Evaluate real required size when done
if (( DATA_FREE < 1048578 )); then
    echo "failed!"
    printf "\nERROR: Need at least 1 MByte free space on '$DATA_DIR', but only detected %'u MByte!\n" $(($DATA_FREE/1024/1024))
    echo "       Consider running '/opt/victronenergy/swupdate-scripts/resize2fs.sh' to get unused space allocated."
    exit 2
fi

echo "ok"

##### Check if git exists
echo -n "2. Check for git command..."
command -v git >/dev/null 2>&1 || {
    echo "failed!"
    echo "Trying to install git command..."
    opkg update && opkg install git || {
        echo "ERROR: Failed installing 'git' package. Please try yourself running 'opkg update && opkg install git' and watch whats wrong."
        exit 3
    }
}
echo "ok"

##### Git clone #####
cd $DATA_DIR
git clone --branch develop --recurse-submodules https://github.com/Apehaenger/venus.dbus-tasmota-easymeter-q3d.git


exit 0


exit 0

# set permissions for script files
chmod 744 $SCRIPT_DIR/$SERVICE_NAME.py
chmod 744 $SCRIPT_DIR/install.sh
chmod 744 $SCRIPT_DIR/restart.sh
chmod 744 $SCRIPT_DIR/uninstall.sh
chmod 744 $SCRIPT_DIR/test.sh
chmod 755 $SCRIPT_DIR/service/run

# create sym-link to run script in deamon
ln -s $SCRIPT_DIR/service /service/$SERVICE_NAME

# add install-script to rc.local to be ready for firmware update
filename=/data/rc.local
if [ ! -f $filename ]
then
    touch $filename
    chmod 777 $filename
    echo "#!/bin/bash" >> $filename
    echo >> $filename
fi

# if not alreay added, then add to rc.local
grep -qxF "bash $SCRIPT_DIR/install.sh" $filename || echo "bash $SCRIPT_DIR/install.sh" >> $filename
