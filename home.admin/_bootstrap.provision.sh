#!/bin/bash

# This script gets called from a fresh SD card
# starting up that has an config file on HDD
# from old RaspiBlitz or manufacturer to
# to install and config services 

# LOGFILE - store debug logs of bootstrap
logFile="/home/admin/raspiblitz.log"

# INFOFILE - state data from bootstrap
infoFile="/home/admin/raspiblitz.info"

# CONFIGFILE - configuration of RaspiBlitz
configFile="/mnt/hdd/raspiblitz.conf"

# debug info
echo "STARTED Provisioning --> see logs in ${logFile}"
echo "STARTED Provisioning from preset config file" >> ${logFile}
sudo sed -i "s/^message=.*/message='Provisioning from Config'/g" ${infoFile}

# check if there is a config file
configExists=$(ls ${configFile} 2>/dev/null | grep -c '.conf')
if [ ${configExists} -eq 0 ]; then
  echo "FAIL: no config file (${configFile}) found to run provision!" >> ${logFile}
  exit 1
fi

##########################
# BASIC SYSTEM SETTINGS
##########################

echo "### BASIC SYSTEM SETTINGS ###" >> ${logFile}

# set hostname data
echo "Setting lightning alias: ${hostname}" >> ${logFile}
sudo sed -i "s/^alias=.*/alias=${hostname}/g" /home/admin/assets/lnd.${network}.conf >> ${logFile} 2>&1

# auto-mount HDD
sudo umount -l /mnt/hdd >> ${logFile} 2>&1
echo "Auto-Mounting HDD - calling script" >> ${logFile}
/home/admin/40addHDD.sh >> ${logFile} 2>&1

# link and copy HDD content into new OS
echo "Link HDD content for user bitcoin" >> ${logFile}
sudo chown -R bitcoin:bitcoin /mnt/hdd/lnd >> ${logFile} 2>&1
sudo chown -R bitcoin:bitcoin /mnt/hdd/${network} >> ${logFile} 2>&1
sudo ln -s /mnt/hdd/${network} /home/bitcoin/.${network} >> ${logFile} 2>&1
sudo ln -s /mnt/hdd/lnd /home/bitcoin/.lnd >> ${logFile} 2>&1
sudo chown -R bitcoin:bitcoin /home/bitcoin/.${network} >> ${logFile} 2>&1
sudo chown -R bitcoin:bitcoin /home/bitcoin/.lnd >> ${logFile} 2>&1
echo "Copy HDD content for user admin" >> ${logFile}
sudo mkdir /home/admin/.${network} >> ${logFile} 2>&1
sudo cp /mnt/hdd/${network}/${network}.conf /home/admin/.${network}/${network}.conf >> ${logFile} 2>&1
sudo mkdir /home/admin/.lnd >> ${logFile} 2>&1
sudo cp /mnt/hdd/lnd/lnd.conf /home/admin/.lnd/lnd.conf >> ${logFile} 2>&1
sudo cp /mnt/hdd/lnd/tls.cert /home/admin/.lnd/tls.cert >> ${logFile} 2>&1
sudo mkdir /home/admin/.lnd/data >> ${logFile} 2>&1
sudo cp -r /mnt/hdd/lnd/data/chain /home/admin/.lnd/data/chain >> ${logFile} 2>&1
sudo chown -R admin:admin /home/admin/.${network} >> ${logFile} 2>&1
sudo chown -R admin:admin /home/admin/.lnd >> ${logFile} 2>&1
echo "Enabling Services" >> ${logFile}
sudo cp /home/admin/assets/${network}d.service /etc/systemd/system/${network}d.service >> ${logFile} 2>&1
sudo chmod +x /etc/systemd/system/${network}d.service >> ${logFile} 2>&1
sudo systemctl daemon-reload >> ${logFile} 2>&1
sudo systemctl enable ${network}d.service >> ${logFile} 2>&1
sed -i "5s/.*/Wants=${network}d.service/" ./assets/lnd.service >> ${logFile} 2>&1
sed -i "6s/.*/After=${network}d.service/" ./assets/lnd.service >> ${logFile} 2>&1
sudo cp /home/admin/assets/lnd.service /etc/systemd/system/lnd.service >> ${logFile} 2>&1
sudo chmod +x /etc/systemd/system/lnd.service >> ${logFile} 2>&1
sudo systemctl enable lnd >> ${logFile} 2>&1

# finish setup (SWAP, Benus, Firewall, Update, ..)
./90finishSetup.sh >> ${logFile} 2>&1

# set the local network hostname
if [ ${#hostname} -gt 0 ]; then
  echo "Setting new network hostname '$hostname'" >> ${logFile}
  sudo raspi-config nonint do_hostname ${hostname} >> ${logFile} 2>&1
else 
  echo "No hostname set." >> ${logFile}
fi

##########################
# PROVISIONING SERVICES
##########################

  echo "### RUNNING PROVISIONING SERVICES ###" >> ${logFile}

# TESTNET
if [ "${chain}" = "test" ]; then
    echo "Provisioning TESTNET - run config script" >> ${logFile}
    sudo sed -i "s/^message=.*/message='Provisioning Testnet'/g" ${infoFile}
    sudo /home/admin/config.scripts/network.chain.sh testnet >> ${logFile} 2>&1
else 
    echo "Provisioning TESTNET - keep default" >> ${logFile}
fi

# AUTO PILOT
if [ "${autoPilot}" = "on" ]; then
    echo "Provisioning AUTO PILOT - run config script" >> ${logFile}
    sudo sed -i "s/^message=.*/message='Provisioning AutoPilot'/g" ${infoFile}
    sudo /home/admin/config.scripts/lnd.autopilot.sh on >> ${logFile} 2>&1
else 
    echo "Provisioning AUTO PILOT - keep default" >> ${logFile}
fi

# AUTO NAT DISCOVERY
if [ "${autoNatDiscovery}" = "on" ]; then
    echo "Provisioning AUTO NAT DISCOVERY - run config script" >> ${logFile}
    sudo sed -i "s/^message=.*/message='Provisioning AutoNAT'/g" ${infoFile}
    sudo /home/admin/config.scripts/lnd.autonat.sh on >> ${logFile} 2>&1
else 
    echo "Provisioning AUTO NAT DISCOVERY - keep default" >> ${logFile}
fi

# RTL
if [ "${rtlWebinterface}" = "on" ]; then
    echo "Provisioning RTL - run config script" >> ${logFile}
    sudo sed -i "s/^message=.*/message='Provisioning RTL'/g" ${infoFile}
    sudo /home/admin/config.scripts/bonus.rtl.sh on >> ${logFile} 2>&1
else 
    echo "Provisioning RTL - keep default" >> ${logFile}
fi

# TOR
if [ "${runBehindTor}" = "on" ]; then
    echo "Provisioning TOR - run config script" >> ${logFile}
    sudo sed -i "s/^message=.*/message='Provisioning TOR'/g" ${infoFile}
    sudo /home/admin/config.scripts/internet.tor.sh on >> ${logFile} 2>&1
else 
    echo "Provisioning TOR - keep default" >> ${logFile}
fi

echo "END Provisioning" >> ${logFile}