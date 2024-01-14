# dbus-tasmota-easymeter-q3d Service

### Purpose

This service is meant to be run on a cerbo gx with Venus OS from Victron.

The Python script cyclically reads data from a micro controller with Tasmota and an IR reader via REST API and publishes information on the dbus, using the service name com.victronenergy.grid. This makes the Venus OS work as if you had a physical Victron Grid Meter installed.

### Configuration

In the Python file, you should put the IP of your Tasmota device that hosts the REST API. In addition, you need to change the JSON attributes in lines 80-94 according to your JSON structure (see your tasmota device: http://192.168.XXX.XXX/cm?cmnd=status%2010)

### Installation

```
bash <(wget -qO- http://website.com/my-script.sh)
```


1. SSH into your Venus device and check (i.e. via `df -h`) that you have some kbyte left on your '/data' partition.<br>
If not, try `/opt/victronenergy/swupdate-scripts/resize2fs.sh` and check again.

2. If you don't have 'git' already installed, do:
   ```
   opkg update
   opkg install git
   ```

3. Install:
   ```
   cd /data
   git clone https://github.com/Apehaenger/venus.dbus-tasmota-easymeter-q3d.git
   cp venus.dbus-tasmota-easymeter-q3d/config.sample.ini venus.dbus-tasmota-easymeter-q3d/config.ini
   ```

4. Configure by `nano /data/venus.dbus-tasmota-easymeter-q3d/config.ini` and change (at least) 'host' and 'password' to yours.

5. First functionality test via `/data/venus.dbus-tasmota-easymeter-q3d/test`.<br>
   This will stop a probably already running 'venus.dbus-tasmota-easymeter' service and should show you some output.<br>
   Stop via 'Ctrl-c', change config if something is wrong, or go-on if the values have been reasonable.

6. Set permissions for files:

   `chmod 755 /data/dbus-tasmota-smartmeter/service/run`

   `chmod 744 /data/dbus-tasmota-smartmeter/kill_me.sh`

7.  Get two files from the [velib_python](https://github.com/victronenergy/velib_python) and install them on your venus:

   - /data/dbus-tasmota-smartmeter/vedbus.py
   - /data/dbus-tasmota-smartmeter/ve_utils.py

8.  Add a symlink to the file /data/rc.local:

   `ln -s /data/dbus-tasmota-smartmeter/service /service/dbus-tasmota-smartmeter`

   Or if that file does not exist yet, store the file rc.local from this service on your Raspberry Pi as /data/rc.local .
   You can then create the symlink by just running rc.local:
  
   `rc.local`

   The daemon-tools should automatically start this service within seconds.

### Update

   TODO

### Debugging

You can check the status of the service with svstat:

`svstat /service/dbus-tasmota-smartmeter`

It will show something like this:

`/service/dbus-tasmota-smartmeter: up (pid 10078) 325 seconds`

If the number of seconds is always 0 or 1 or any other small number, it means that the service crashes and gets restarted all the time.

When you think that the script crashes, start it directly from the command line:

`python /data/dbus-tasmota-smartmeter/dbus-tasmota-smartmeter.py`

and see if it throws any error messages.

If the script stops with the message

`dbus.exceptions.NameExistsException: Bus name already exists: com.victronenergy.grid"`

it means that the service is still running or another service is using that bus name.

#### Restart the script

If you want to restart the script, for example after changing it, just run the following command:

`/data/dbus-tasmota-smartmeter/kill_me.sh`

The daemon-tools will restart the scriptwithin a few seconds.

### Todo

- [x] Fix hung if tasmota device get unreachable (handle connection issues)
- [x] Add 'None' values to ensure that grid doesn't get powered by battery or battery get charged from grid
- [ ] Improve text/number formatting 
- [ ] Config instead of static source code changes

### Hardware

In my installation at home, I am using the following Hardware:

- Many Hoymiles Inverter
- ESP8266 mini Board d1 and bitShake SmartMeterReader
- Victron MultiPlus-II - Battery Inverter (single phase)
- Cerbo GX
- Pylontech US5000 - LiFePO Battery

## Thank you

Many thanks for sharing the knowledge:

* [venus.dbus-fronius-smartmeter](https://github.com/RalfZim/venus.dbus-fronius-smartmeter)
* [multiplus-ii-ess-modene-messeinrichtung-statt-em24](https://community.victronenergy.com/articles/170837/multiplus-ii-ess-modene-messeinrichtung-statt-em24.html)
* https://github.com/mr-manuel/venus-os_dbus-mqtt-grid/blob/master/dbus-mqtt-grid/install.sh
* https://github.com/vikt0rm/dbus-shelly-1pm-pvinverter
* https://github.com/madsci1016/SMAVenusDriver
* https://github.com/fabian-lauer/dbus-shelly-3em-smartmeter