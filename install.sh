#!/bin/bash
#
# LSM Agent Installation Script
#
# @version		1.0.6
# @date			2014-07-30
# @copyright	(c) 2018 https://github.com/SS88UK/Linux-Server-Monitoring
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Prepare output
echo -e "|\n|   SS88's Linux Server Monitoring Installer\n|   ===================\n|"

# Root required
if [ $(id -u) != "0" ];
then
	echo -e "|   Error: You need to be root to install the SS88's LSM agent\n|"
	echo -e "|          The agent itself will NOT be running as root but instead under its own non-privileged user\n|"
	exit 1
fi

# Parameters required
if [ $# -lt 1 ]
then
	echo -e "|   Usage: bash $0 'token'\n|"
	exit 1
fi

# Check if crontab is installed
if [ ! -n "$(command -v crontab)" ]
then

	# Confirm crontab installation
	echo "|" && read -p "|   Crontab is required and could not be found. Do you want to install it? [Y/n] " input_variable_install

	# Attempt to install crontab
	if [ -z $input_variable_install ] || [ $input_variable_install == "Y" ] || [ $input_variable_install == "y" ]
	then
		if [ -n "$(command -v apt-get)" ]
		then
			echo -e "|\n|   Notice: Installing required package 'cron' via 'apt-get'"
		    apt-get -y update
		    apt-get -y install cron
		elif [ -n "$(command -v yum)" ]
		then
			echo -e "|\n|   Notice: Installing required package 'cronie' via 'yum'"
		    yum -y install cronie
		    
		    if [ ! -n "$(command -v crontab)" ]
		    then
		    	echo -e "|\n|   Notice: Installing required package 'vixie-cron' via 'yum'"
		    	yum -y install vixie-cron
		    fi
		elif [ -n "$(command -v pacman)" ]
		then
			echo -e "|\n|   Notice: Installing required package 'cronie' via 'pacman'"
		    pacman -S --noconfirm cronie
		fi
	fi
	
	if [ ! -n "$(command -v crontab)" ]
	then
	    # Show error
	    echo -e "|\n|   Error: Crontab is required and could not be installed\n|"
	    exit 1
	fi	
fi

# Check if cron is running
if [ -z "$(ps -Al | grep cron | grep -v grep)" ]
then
	
	# Confirm cron service
	echo "|" && read -p "|   Cron is available but not running. Do you want to start it? [Y/n] " input_variable_service

	# Attempt to start cron
	if [ -z $input_variable_service ] || [ $input_variable_service == "Y" ] || [ $input_variable_service == "y" ]
	then
		if [ -n "$(command -v apt-get)" ]
		then
			echo -e "|\n|   Notice: Starting 'cron' via 'service'"
			service cron start
		elif [ -n "$(command -v yum)" ]
		then
			echo -e "|\n|   Notice: Starting 'crond' via 'service'"
			chkconfig crond on
			service crond start
		elif [ -n "$(command -v pacman)" ]
		then
			echo -e "|\n|   Notice: Starting 'cronie' via 'systemctl'"
		    systemctl start cronie
		    systemctl enable cronie
		fi
	fi
	
	# Check if cron was started
	if [ -z "$(ps -Al | grep cron | grep -v grep)" ]
	then
		# Show error
		echo -e "|\n|   Error: Cron is available but could not be started\n|"
		exit 1
	fi
fi

# Attempt to delete previous agent
if [ -f /etc/lsm-ss88/agent.sh ]
then
	# Remove agent dir
	rm -Rf /etc/lsm-ss88

	# Remove cron entry and user
	if id -u lsm-ss88 >/dev/null 2>&1
	then
		(crontab -u lsm-ss88 -l | grep -v "/etc/lsm-ss88/agent.sh") | crontab -u lsm-ss88 - && userdel lsm-ss88
	else
		(crontab -u root -l | grep -v "/etc/lsm-ss88/agent.sh") | crontab -u root -
	fi
fi

# Create agent dir
mkdir -p /etc/lsm-ss88

# Download agent
echo -e "|   Downloading agent.sh to /etc/lsm-ss88\n|\n|   + $(wget -nv -o /dev/stdout -O /etc/lsm-ss88/agent.sh --no-check-certificate https://raw.githubusercontent.com/SS88UK/Linux-Server-Monitoring/master/agent.sh)"

if [ -f /etc/lsm-ss88/agent.sh ]
then
	# Create auth file
	echo "$1" > /etc/lsm-ss88/auth.key
	
	# Create user
	useradd lsm-ss88 -r -d /etc/lsm-ss88 -s /bin/false
	
	# Modify user permissions
	chown -R lsm-ss88:lsm-ss88 /etc/lsm-ss88 && chmod -R 700 /etc/lsm-ss88
	
	# Modify ping permissions
	chmod +s `type -p ping`

	# Configure cron
	crontab -u lsm-ss88 -l 2>/dev/null | { cat; echo "*/3 * * * * bash /etc/lsm-ss88/agent.sh > /etc/lsm-ss88/cron.log 2>&1"; } | crontab -u lsm-ss88 -
	
	# Show success
	echo -e "|\n|   Success: The LSM agent has been installed\n|"
	
	# Attempt to delete installation script
	if [ -f $0 ]
	then
		rm -f $0
	fi
else
	# Show error
	echo -e "|\n|   Error: The LSM agent could not be installed\n|"
fi
