#!/bin/bash
set -o errexit   # abort on nonzero exitstatus
set -o nounset   # abort on unbound variable
set -o pipefail  # don't hide errors within pipes

readonly REPO="https://github.com/Apehaenger/venus.dbus-tasmota-easymeter-q3d.git"
readonly DATA_DIR="/data"
readonly SERVICE_NAME="dbus-tasmota-easymeter-q3d"
readonly SERVICE_DIR="$DATA_DIR/$SERVICE_NAME"

THOST=""
TUSER="admin"
TPASS=""

main() {
    # If config.ini already exists, questionaire install already done
    if [[ -f $SERVICE_DIR/config.ini ]]; then
        activate
        exit 0
    fi

    # Greeting and major information
cat << EOF
This script will install '$SERVICE_NAME' service for VenusOS.
At any place you may press 'Ctrl-c' to abort the installation process!

In detail, this script will do the following:
1. Check if this service already got cloned. If so, installation will abort with a message
2. Check if $DATA_DIR partition exists and has enough space. If not, installation will abort with a message
3. Check if git command exists. If not, it tries to install it via systems 'opkg' package manager
4. Clone $REPO to $SERVICE_DIR
5. Ask for some mandatory Tasmota device infos (hostname, username, password)
6. Tries to connect to Tasmota device. If fail, rewind to step 5.
7. Save previously asked values to config.ini
8. Set script permissions, link service script and activate it

EOF
    
    read -p "Press any key to continue or 'Ctrl-c' to abort... " -n1
    
    ##### Check that clone doesn't already exists #####
    echo -en "\n1. Check '$SERVICE_DIR'..."
    if [[ -d $SERVICE_DIR ]]; then
        echo "exists!"
        echo "ERROR: You already cloned the service in '$SERVICE_DIR'!"
        echo "       Please run '$SERVICE_DIR/update.sh' or"
        echo "       '$SERVICE_DIR/uninstall.sh' and remove '$SERVICE_DIR' directory."
        exit 1
    fi
    echo "ok"
    
    ##### Validate /data #####
    echo -n "2. Check '$DATA_DIR'..."
    if [[ ! -d $DATA_DIR ]]; then
        echo "failed!"
        echo "ERROR: Haven't found '$DATA_DIR' directory(partition)! Are your sure that you started this install script on a VenusOS device?"
        exit 2
    fi
    
    # Free blocks * blocksize of /data
    DATA_FREE=$(($(stat -fc "%a*%s" $DATA_DIR)))
    # FIXME: Evaluate real required size when done
    if (( DATA_FREE < 1048578 )); then
        echo "failed!"
        printf "\nERROR: Need at least 1 MByte free space on '$DATA_DIR', but only detected %'u MByte!\n" $(($DATA_FREE/1024/1024))
        echo "       Consider running '/opt/victronenergy/swupdate-scripts/resize2fs.sh' to get unused space allocated."
        exit 3
    fi
    
    echo "ok"
    
    ##### Check if git exists
    echo -n "3. Check for git command..."
    command -v git >/dev/null 2>&1 || {
        echo "failed!"
        echo "Trying to install git command..."
        opkg update && opkg install git || {
            echo "ERROR: Failed installing 'git' package. Please try yourself running 'opkg update && opkg install git' and watch whats wrong."
            exit 3
        }
    }
    echo "ok"
    
    ##### Clone #####
    echo -n "4. Clone repository..."
    git clone --branch develop --recurse-submodules $REPO $SERVICE_DIR || {
        echo "failed!"
        echo "ERROR: Installation failed. Check result of the previous 'git clone...' command what went wrong!"
        exit 4
    }
    echo "ok"
    
    ##### Tasmota settings #####
    cp $SERVICE_DIR/config.sample.ini $SERVICE_DIR/config.ini
    
    ask=1
    while (( $ask )); do
        ask_device_infos
        echo "DBG: $THOST $TUSER $TPASS"
        get_device_infos
    done
    
    # Store gathered infos to config.ini
    echo -n "7. Save Tasmota settings to $SERVICE_DIR/config.ini ..."
    if [[ ! -z "$THOST" ]]; then
        sed -iE "/^host[[:space:]]*=/s/=.*/= $THOST/" $SERVICE_DIR/config.ini
    fi
    if [[ ! -z "$TUSER" ]]; then
        sed -iE "/^username[[:space:]]*=/s/=.*/= $TUSER/" $SERVICE_DIR/config.ini
    fi
    if [[ ! -z "$TPASS" ]]; then
        sed -iE "/^password[[:space:]]*=/s/=.*/= $TPASS/" $SERVICE_DIR/config.ini
    fi
    echo "ok"
    
    echo -n "8. Set script permissions, link ... and activate it (boot & update save)..."
    activate
    echo "ok"

    echo -e "\nAll done.\nCheck your Venus device, it should list now the new smartmeter in its main screen."
}

activate () {
    chmod 744 $SERVICE_DIR/$SERVICE_NAME.py
    chmod 744 $SERVICE_DIR/install.sh
    chmod 744 $SERVICE_DIR/uninstall.sh
    chmod 744 $SERVICE_DIR/restart.sh
    chmod 744 $SERVICE_DIR/update.sh
    chmod 755 $SERVICE_DIR/service/run
    
    # Create sym-link to run script in deamon
    ln -s $SERVICE_DIR/service /service/$SERVICE_NAME
    
    # Add service to rc.local to be save also after firmware update
    filename=/data/rc.local
    if [ ! -f $filename ]
    then
        touch $filename
        chmod 777 $filename
        echo "#!/bin/bash" >> $filename
        echo >> $filename
    fi
    
    # If not alreay added, then add to rc.local
    grep -qxF "ln -s $SERVICE_DIR/service /service/$SERVICE_NAME" $filename || echo "ln -s $SERVICE_DIR/service /service/$SERVICE_NAME" >> $filename
    echo "ok"
}

get_device_infos () {
    echo "6. Get device info from $THOST..."
    tmpfile=$(mktemp)
    # FIXME: Shouldn't we urlencode $TUSER and $TPASS?
    wget -O $tmpfile "http://$THOST/cm?user=$TUSER&password=$TPASS&cmnd=status%200" || {
        echo "ERROR: wget failed gathering tasmota infos. Check previous lines about what was wrong and try again."
        return
    }
    ask=0
}

ask_device_infos () {
    echo "5. Ask for required Tasmota device infos:"
    # Ask for hostname or IP
    read -p "Fully qualified hostname or IP of your Tasmota Smartmeter device [$THOST]: " answer
    if [[ ! -z "$answer" ]]; then
        THOST=$answer
    fi
    # Ask for username
    read -p "Username [$TUSER]: " answer
    if [[ ! -z "$answer" ]]; then
        TUSER=$answer
    fi
    # Ask for password
    if [[ -z "$TPASS" ]]; then
        read -sp "Password: " answer
    else
        read -sp "Password [***]: " answer
    fi
    if [[ ! -z "$answer" ]]; then
        TPASS=$answer
    fi
    echo ""
}

main "${@}"
