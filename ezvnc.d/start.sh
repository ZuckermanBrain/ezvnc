#!/bin/bash
# guac-start.sh
# jsp2205, 2020
# Columbia University, Zuckerman Research Computing
#
# This is an alternative wrapper script for Xvnc.
# It is designed to output a URI for end-users
# after their VNC sessions have been launched.
# It stands in contrast to the default wrapper script (vncserver),
# which does not output a URI.
# Nevertheless, it takes some inspiration from vncserver
#
# See here for more details: https://guacamole.apache.org/doc/gug/adhoc-connections.html#using-quickconnect


ezvnc-getdefaultxstartup() {
	if [ -e /usr/bin/xfce4-session ]; then
		export DEFAULTXSTARTUP='#!/bin/sh
env -i /bin/sh -c "export PATH=$PATH;
export XAUTHORITY=$XAUTHORITY;
export DISPLAY=$DISPLAY;
export HOME=$HOME;
export LOGNAME=$LOGNAME;
export USER=$USER;
/usr/bin/xfce4-session"
'
	elif [ -e /usr/bin/gnome-session -o -e /usr/bin/startkde ]; then
		if [ $(lsb_release -i 2> /dev/null | cut -d: -f2) = 'Debian' ] || [ $(lsb_release -i 2> /dev/null | cut -d: -f2) = 'Ubuntu' ]; then
		DEFAULTXSTARTUP='#!/bin/sh
DISPLAYNUM=$(echo $DISPLAY | cut -d: -f2)

xrdb $HOME/.Xresources
xsetroot -solid grey
#x-terminal-emulator -geometry 80x24+10+10 -ls -title $VNCDESKTOP Desktop &
#x-window-manager &
# Fix to make GNOME work
export XKL_XMODMAP_DISABLE=1
/etc/X11/Xsession
if [ -e /usr/bin/gnome-session ]; then
	exec gnome-session
elif [ -e /usr/bin/startkde ]; then
	exec startkde	
fi
if [ -e /usr/bin/gnome-session -o -e /usr/bin/startkde ]; then
	ezvnc stop ${HOST} ${DISPLAYNUM}
fi
'
		elif [ -e /etc/redhat_release ]; then
			DEFAULTXSTARTUP='#!/bin/sh
DISPLAYNUM=$(echo $DISPLAY | cut -d: -f2)
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
/etc/X11/xinit/xinitrc
# Assume either Gnome or KDE will be started by default when installed
# We want to kill the session automatically in this case when user logs out. In case you modify
# /etc/X11/xinit/Xclients or ~/.Xclients yourself to achieve a different result, then you should
# be responsible to modify below code to avoid that your session will be automatically killed
if [ -e /usr/bin/gnome-session -o -e /usr/bin/startkde ]; then
	guac-stop ${HOST} ${DISPLAYNUM}
fi
'
		fi

	fi
}

ezvnc-getvncserver() {
	if [[ $(Xvnc -version 2>&1) == *TightVNC* ]]; then
		export VNCVERSION="TightVNC"
	elif [[ $(Xvnc -version 2>&1) == *TigerVNC* ]]; then
		export VNCVERSION="TigerVNC"
	fi
}

ezvnc-start() {
	# Constants
	EZVNCDIR=${HOME}/.ezvnc
	if [ ! -d ${EZVNCDIR} ]; then
		mkdir -p ${EZVNCDIR}
	fi

	# Default settings variables
	# Maybe use some conditionals here to check if theses variables are already set, and then source some other config file beforehand (~/.ezvnc.rc)?
	GEOMETRY="1024x768"
	DEPTH=24
	if [ -z ${1} ]; then
		DESKTOPNAME="Nameless"
	else
		DESKTOPNAME=${1}
	fi

	# This will be used later to determine the Xvnc command used.
	ezvnc-getvncserver

	if [ -z ${HOST} ]; then
		# Find a hostname to bind to.
		# We just use the first one that can be found from a reverse lookup.
		declare HOSTS
		IPS=($(hostname -I))
		for IP in ${IPS[@]}; do
			HOST=$(dig -x ${IP} +short | sed -e 's/\.$//' | awk '{ print $1 }')
			if [ -z ${HOST} ]; then
				continue
			fi
			HOSTS+=(${HOST})
		done
		if [ -z ${HOSTS} ]; then
			echo "Could find no hostnames for this machine. Exiting."
			exit 1
		else
			HOST=${HOSTS[0]}
			IP=${IPS[0]}
		fi
	fi
	# For use in xstartup.
	export HOST

	# Find display number.
	# Choose a random open display between 0 and 99 by checking ports from 5900-5999.
	# Start by assuming that the port is closed unless proven otherwise by lsof.
	# Essentially, busy wait until a port within the range is free.
	#TODO Add a timeout for circumstance where all displays are taken so it doesn't loop indefinitely /
	# until someone kills their VNC session.
	PORT_FREE=0
	while [ ${PORT_FREE} -eq 0 ]; do
		DISPLAYNUM=$(shuf -i00-99 -n1)
		if ! nc -z ${HOST} 59${DISPLAYNUM} ; then
			PORT_FREE=1
		fi
		sleep 1
	done
	EZVNCPORT="59$(printf '%02d' ${DISPLAYNUM})"

	# Make an X server cookie using /dev/urandom.
	COOKIE=$(head /dev/urandom | tr -dc a-f0-9 | head -c 12)
	# Use $(uname -n) instead of HOST b/c that's how Xvnc names displays.
	xauth -f ${EZVNCDIR}/.Xauthority add $(uname -n):${DISPLAYNUM} . ${COOKIE}
	xauth -f ${EZVNCDIR}/.Xauthority add $(uname -n)/unix:${DISPLAYNUM} . ${COOKIE}
	export XAUTHORITY="${EZVNCDIR}/.Xauthority"

	# Construct log file path
	EZVNCDESKTOPLOG="${EZVNCDIR}/${HOST}:${DISPLAYNUM}.log"

	# In contrast to vncserver, each VNC server gets its own dynamically generated random password (sort of like the Jupyter notebook token).
	# That's echoed to stdout when the server is first started up.
	# Store the password in a plaintext file that can only be read by the user for queries
	# about active sessions.
	EZVNCPASSWD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
	EZVNCPASSWDFILE="${EZVNCDIR}/${HOST}:${DISPLAYNUM}-passwd"
	EZVNCPASSWDCLEAR="${EZVNCDIR}/.${HOST}:${DISPLAYNUM}-passwd-clear"
	echo ${EZVNCPASSWD} | vncpasswd -f > ${EZVNCPASSWDFILE}
	touch ${EZVNCPASSWDCLEAR}
	chmod 0700 ${EZVNCPASSWDCLEAR}
	echo ${EZVNCPASSWD} > ${EZVNCPASSWDCLEAR}

	# Get font path and config path
	X11FOUND=0
	if [ -z ${X11CONFIGPATH} ]; then
		for X11CONFIGPATH in "/etc/X11/xorg.conf" "/etc/X11/XF86Config-4" "/etc/X11/XF86Config"; do
			if [ -f ${X11CONFIGPATH} ]; then
				X11FOUND=1
				break
			fi
		done
	else
		if [ -f ${X11CONFIGPATH} ]; then
			X11FOUND=1
			break
		fi
	fi

	if [ -z ${FONTPATH} ]; then
		if [ ${X11FOUND} -ne "1" ]; then
			FONTPATH="/usr/share/fonts/X11/misc/,/usr/share/fonts/X11/Type1/,/usr/share/fonts/X11/75dpi/,/usr/share/fonts/X11/100dpi/"
		else
			FONTPATH=$(egrep "^[[:space:]]*FontPath[[:space:]]*.*[[:space:]]*$" ${X11CONFIGPATH} | awk '{print $2}' | sed 's/[\s"]//g')
		fi
	fi

	if [ ${VNCVERSION} == "TightVNC" ]; then
		if [ -z ${COLORPATH} ]; then
			if [ ${X11FOUND} -ne "1" ]; then
				COLORPATHFOUND=0
				for COLORPATH in "/etc/X11/rgb.txt" "/usr/share/X11/rgb.txt" "/usr/X11R6/lib/X11/rgb.txt"; do
					if [ -f ${COLORPATH} ]; then
						COLORPATHFOUND=1
						break
					fi
				done
			else
				COLORPATH=$(egrep "^[[:space:]]*RgbPath[[:space:]]*.*[[:space:]]*$" ${X11CONFIGPATH} | awk '{print $2}' | sed 's/[\s"]//g')
			fi
		fi

		if [ ${COLORPATHFOUND} -ne "1" ]; then
			echo "Error- color path not found"
			exit 1
		fi
	fi

	# Run the command and record the process ID.
	PIDFILE="${EZVNCDIR}/${HOST}:${DISPLAYNUM}.pid"
	if [ ${VNCVERSION} == "TightVNC" ]; then
		CMD="Xvnc :${DISPLAYNUM} 
			-desktop ${DESKTOPNAME} 
			-auth ${EZVNCDIR}/.Xauthority 
			-geometry ${GEOMETRY} 
			-depth ${DEPTH} 
			-rfbwait 120000
			-rfbauth ${EZVNCPASSWDFILE}
			-rfbport ${EZVNCPORT} 
			-fp ${FONTPATH}
			-co ${COLORPATH}
			-interface ${IP}
		"
	else
		CMD="Xvnc :${DISPLAYNUM} 
			-desktop ${DESKTOPNAME} 
			-auth ${EZVNCDIR}/.Xauthority 
			-geometry ${GEOMETRY} 
			-depth ${DEPTH} 
			-rfbwait 120000
			-rfbauth ${EZVNCPASSWDFILE}
			-rfbport ${EZVNCPORT} 
			-fp ${FONTPATH}
			-pn
			-interface ${IP}
		"
	fi
	${CMD} >> ${EZVNCDESKTOPLOG} 2>&1 & echo $! > ${PIDFILE}
	sleep 3

	# Create the user's xstartup script if necessary.
	XSTARTUP=${EZVNCDIR}/xstartup
	if [ ! -f ${XSTARTUP} ]; then
		echo ${XSTARTUP} does not exist.  Creating now...
		if [ -z ${DEFAULTXSTARTUP} ]; then
			ezvnc-getdefaultxstartup
		fi
		echo "${DEFAULTXSTARTUP}" > ${XSTARTUP}
		chmod 0755 ${XSTARTUP}
	fi

	# If the unix domain socket exists then use that (DISPLAY=:n) otherwise use
	# TCP (DISPLAY=host:n)
	if [ -e "/tmp/.X11-unix/X${DISPLAYNUM}" ]; then
	    export DISPLAY=":${DISPLAYNUM}"
	else 
	    export DISPLAY="${HOST}:${DISPLAYNUM}"
	fi
	export VNCDESKTOP=${DESKTOPNAME}

	${XSTARTUP} >> ${EZVNCDESKTOPLOG} 2>&1 &

	EZURI="vnc://${HOST}:${EZVNCPORT}?password=${EZVNCPASSWD}"
	echo ${EZURI}
}
