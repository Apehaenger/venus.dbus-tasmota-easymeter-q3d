#!/usr/bin/env python3

#####################################################################################
# Adapt form
# juf
# and
# fabian-lauer / dbus-shelly-3em-smartmeter
# and
# RalfZim / venus.dbus-fronius-smartmeter
# and 
# AchimKre / https://github.com/AchimKre/venus.dbus-tasmota-smartmeter
# and
# Apehaenger / https://github.com/Apehaenger/venus.dbus-tasmota-easymeter-q3d
#
# See https://github.com/victronenergy/velib_python/blob/master/dbusdummyservice.py
#####################################################################################

import platform 
import logging
import sys
import os
if sys.version_info.major == 2:
  import gobject
else:
  from gi.repository import GLib as gobject
import requests
import configparser

# Victron packages
sys.path.insert(1, os.path.join(os.path.dirname(__file__), '/opt/victronenergy/dbus-systemcalc-py/ext/velib_python'))
from vedbus import VeDbusService

# Read config.ini
try:
  config_file = (os.path.dirname(os.path.realpath(__file__))) + "/config.ini"
  if not os.path.exists(config_file):
    print(
      'ERROR: "' + config_file + '" file not found!\n' +
      'Did you copied "config.sample.ini" to "config.ini"?')
    sys.exit()

  config = configparser.ConfigParser()
  config.read(config_file)
  if config["TASMOTA"]["host"] == "IP_ADDR_OR_FQDN" or config["TASMOTA"]["host"] == "":
    print('ERROR: "config.ini" contains invalid default values like IP_ADDR_OR_FQDN. Adapt config.ini to your local configuration.')
    sys.exit()

except Exception:
  exception_type, exception_object, exception_traceback = sys.exc_info()
  file = exception_traceback.tb_frame.f_code.co_filename
  line = exception_traceback.tb_lineno
  print(f"Exception occurred: {repr(exception_object)} of type {exception_type} in {file} line #{line}")
  sys.exit()


class DbusEasymeterService:
  def __init__(self, servicename, deviceinstance, paths, productname='Tasmota', connection='Tasmota Web service'):
    self._dbusservice = VeDbusService("{}.http_{:02d}".format(servicename, deviceinstance))
    self._paths = paths
 
    logging.debug("%s /DeviceInstance = %d" % (servicename, deviceinstance))

    # Create the management objects, as specified in the ccgx dbus-api document
    self._dbusservice.add_path('/Mgmt/ProcessName', __file__)
    self._dbusservice.add_path('/Mgmt/ProcessVersion', 'Unkown version, and running on Python ' + platform.python_version())
    self._dbusservice.add_path('/Mgmt/Connection', connection)
 
    # Create the mandatory objects
    self._dbusservice.add_path('/DeviceInstance', deviceinstance)
    self._dbusservice.add_path('/ProductId', 45069) # found on https://www.sascha-curth.de/projekte/005_Color_Control_GX.html#experiment - should be an ET340 Engerie Meter
    self._dbusservice.add_path('/ProductName', productname)
    self._dbusservice.add_path('/FirmwareVersion', 0.2)
    self._dbusservice.add_path('/HardwareVersion', 0)
    self._dbusservice.add_path('/Connected', 1)

    # Create optional objects    
    self._dbusservice.add_path('/DeviceType', 345) # found on https://www.sascha-curth.de/projekte/005_Color_Control_GX.html#experiment - should be an ET340 Engerie Meter
    self._dbusservice.add_path('/CustomName', 'SM-Haus')    
    self._dbusservice.add_path('/Serial', '0272024812927') # if you like numbers, like me ;-)
 
    # Add path values to dbus
    for path, settings in self._paths.items():
      self._dbusservice.add_path(
        path, settings['initial'], gettextcallback=settings['textformat'], writeable=True, onchangecallback=self._handlechangedvalue)
 
    # Add _update function 'timer'
    gobject.timeout_add(500, self._update) # Pause 500ms before the next request

  def _update(self):   
    try:
      # Might be more fail save to use the IP instead of the hostname, but depends on the stability of (your) DNS!
      #meter_url = "http://192.168.2.117/cm?user=admin&password=jetSMset&cmnd=status%2010"
      meter_url = "http://sm-haus.int.shbe.net/cm?user=admin&password=jetSMset&cmnd=status%2010"
      meter_r = requests.get(url=meter_url, timeout=5) # Request data from the Tasmota Smartmeter, with a timeout of x seconds
      #print("meter_r is: ", meter_r)
      meter_data = meter_r.json()

    except Exception as e:
      # Better send 'invalid' values, otherwise the old ones may remain active which in turn might end up in high costs
      self._dbusservice['/Ac/Power'] = None
      self._dbusservice['/Ac/Energy/Forward'] = None
      self._dbusservice['/Ac/Energy/Reverse'] = None
      self._dbusservice['/Ac/L1/Voltage'] = None
      self._dbusservice['/Ac/L2/Voltage'] = None
      self._dbusservice['/Ac/L3/Voltage'] = None
      self._dbusservice['/Ac/L1/Current'] = None
      self._dbusservice['/Ac/L2/Current'] = None
      self._dbusservice['/Ac/L3/Current'] = None
      self._dbusservice['/Ac/L1/Power'] = None
      self._dbusservice['/Ac/L2/Power'] = None
      self._dbusservice['/Ac/L3/Power'] = None

      logging.critical('Error at %s', '_update', exc_info=e)
       
    else:
      # Send data to DBus
      #print("meter_data is: ", meter_data)
      self._dbusservice['/Ac/Power'] = float(meter_data['StatusSNS']['Haus']['PowerTotal']) # positive: consumption, negative: feed into grid
      self._dbusservice['/Ac/Energy/Forward'] = float(meter_data['StatusSNS']['Haus']['EnergyTotalConsumed'])
      self._dbusservice['/Ac/Energy/Reverse'] = float(meter_data['StatusSNS']['Haus']['EnergyTotalDelivered'])
      self._dbusservice['/Ac/L1/Voltage'] = 230
      self._dbusservice['/Ac/L2/Voltage'] = 230
      self._dbusservice['/Ac/L3/Voltage'] = 230
      self._dbusservice['/Ac/L1/Current'] = round(float(meter_data['StatusSNS']['Haus']['PowerL1'] / 230 ), 3)
      self._dbusservice['/Ac/L2/Current'] = round(float(meter_data['StatusSNS']['Haus']['PowerL2'] / 230 ), 3)
      self._dbusservice['/Ac/L3/Current'] = round(float(meter_data['StatusSNS']['Haus']['PowerL3'] / 230 ), 3)
      self._dbusservice['/Ac/L1/Power'] = round(float(meter_data['StatusSNS']['Haus']['PowerL1']), 2)
      self._dbusservice['/Ac/L2/Power'] = round(float(meter_data['StatusSNS']['Haus']['PowerL2']), 2)
      self._dbusservice['/Ac/L3/Power'] = round(float(meter_data['StatusSNS']['Haus']['PowerL3']), 2)

      # Logging
      logging.debug("Total Power   (/Ac/Power)         : %s" % (self._dbusservice['/Ac/Power']))
      logging.debug("Total Forward (/Ac/Energy/Forward): %s" % (self._dbusservice['/Ac/Energy/Forward']))
      logging.debug("Total Reverse (/Ac/Energy/Revers) : %s" % (self._dbusservice['/Ac/Energy/Reverse']))
      logging.debug("L1-3 Voltage  (/Ac/Lx/Voltage)    : %s, %s, %s" % (self._dbusservice['/Ac/L1/Voltage'], self._dbusservice['/Ac/L2/Voltage'], self._dbusservice['/Ac/L3/Voltage']))
      logging.debug("L1-3 Current  (/Ac/Lx/Current)    : %s, %s, %s" % (self._dbusservice['/Ac/L1/Current'], self._dbusservice['/Ac/L2/Current'], self._dbusservice['/Ac/L3/Current']))
      logging.debug("L1-3 Power    (/Ac/Lx/Power)      : %s, %s, %s" % (self._dbusservice['/Ac/L1/Power'], self._dbusservice['/Ac/L2/Power'], self._dbusservice['/Ac/L3/Power']))
      logging.debug("---");

    # Return true, otherwise add_timeout will be removed from GObject - see docs http://library.isr.ist.utl.pt/docs/pygtk2reference/gobject-functions.html#function-gobject--timeout-add
    return True
 
  def _handlechangedvalue(self, path, value):
    logging.debug("someone else updated %s to %s" % (path, value))
    return True # accept the change

def getLogLevel():
  if config["TASMOTA"]["logging"]:
    level = logging.getLevelName(config["TASMOTA"]["logging"])
  else:
    level = logging.INFO

  return level

def main():
  logging.basicConfig(format='%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s',
                      datefmt='%Y-%m-%d %H:%M:%S',
                      level=getLogLevel(),
                      handlers=[
                        logging.FileHandler("%s/current.log" % (os.path.dirname(os.path.realpath(__file__)))),
                        logging.StreamHandler()
                      ])
 
  try:
      logging.info("Start");
  
      from dbus.mainloop.glib import DBusGMainLoop
      # Have a mainloop, so we can send/receive asynchronous calls to and from dbus
      DBusGMainLoop(set_as_default=True)
     
      # Formatting 
      _kwh = lambda p, v: (str(f'{round(v, 2):,}') + 'kWh')
      _a = lambda p, v: (str(round(v, 1)) + 'A')
      _w = lambda p, v: (str(f'{round(v, 1):,}') + 'W')
      _v = lambda p, v: (str(round(v, 1)) + 'V')   
     
      # Start our main-service
      output = DbusEasymeterService(
        servicename='com.victronenergy.grid',
        deviceinstance=40,
        paths={
          '/Ac/Power': {'initial': 0, 'textformat': _w},
          '/Ac/L1/Voltage': {'initial': 0, 'textformat': _v},
          '/Ac/L2/Voltage': {'initial': 0, 'textformat': _v},
          '/Ac/L3/Voltage': {'initial': 0, 'textformat': _v},
          '/Ac/L1/Current': {'initial': 0, 'textformat': _a},
          '/Ac/L2/Current': {'initial': 0, 'textformat': _a},
          '/Ac/L3/Current': {'initial': 0, 'textformat': _a},
          '/Ac/L1/Power': {'initial': 0, 'textformat': _w},
          '/Ac/L2/Power': {'initial': 0, 'textformat': _w},
          '/Ac/L3/Power': {'initial': 0, 'textformat': _w},
          '/Ac/Energy/Forward': {'initial': 0, 'textformat': _kwh}, # energy bought from the grid
          '/Ac/Energy/Reverse': {'initial': 0, 'textformat': _kwh}, # energy sold to the grid
        })
     
      logging.info('Connected to dbus, and switching over to gobject.MainLoop() (= event based)')
      mainloop = gobject.MainLoop()
      mainloop.run()

  except Exception as e:
    logging.critical('Error at %s', 'main', exc_info=e)

if __name__ == "__main__":
  main()
