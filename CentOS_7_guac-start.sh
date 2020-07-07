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

# Constants
GUACVNCDIR=${HOME}/.guacvnc
if [ ! -d ${GUACVNCDIR} ]; then
	mkdir -p ${GUACVNCDIR}
fi

# Default settings variables
# Maybe use some conditionals here to check if theses variables are already set, and then source some other config file beforehand (~/.guacvnc.rc)?
GEOMETRY="1024x768"
DEPTH=24
DESKTOPNAME="X"
DEFAULTXSTARTUP='#!/bin/sh
HOST=$(hostname -f)
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

# Find display number.
# Choose a random open display between 0 and 99 by checking ports from 5900-5999.
# Start by assuming that the port is closed unless proven otherwise by lsof.
# Essentially, busy wait until a port within the range is free.
#TODO Add a timeout for circumstance where all displays are taken so it doesn't loop indefinitely /
# until someone kills their VNC session.
HOST="$(hostname -f)"
PORT_FREE=0
while [ ${PORT_FREE} -eq 0 ]; do
	DISPLAYNUM=$(shuf -i00-99 -n1)
	if ! nc -z ${HOST} 59${DISPLAYNUM} ; then
		PORT_FREE=1
	fi
	sleep 1
done
GUACVNCPORT="59$(printf '%02d' ${DISPLAYNUM})"

# Make an X server cookie using /dev/urandom.
COOKIE=$(head /dev/urandom | tr -dc a-f0-9 | head -c 12)
xauth -f ${GUACVNCDIR}/.Xauthority add ${HOST}:${DISPLAYNUM} . ${COOKIE}
xauth -f ${GUACVNCDIR}/.Xauthority add ${HOST}/unix:${DISPLAYNUM} . ${COOKIE}
export XAUTHORITY="${GUACVNCDIR}/.Xauthority"

# Construct log file path
GUACVNCDESKTOPLOG="${GUACVNCDIR}/${HOST}:${DISPLAYNUM}.log"

# In contrast to vncserver, each VNC server gets its own dynamically generated random password (sort of like the Jupyter notebook token).
# That's echoed to stdout when the server is first started up.
# Store the password in a plaintext file that can only be read by the user for queries
# about active sessions.
GUACVNCPASSWD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
GUACVNCPASSWDFILE="${GUACVNCDIR}/${HOST}:${DISPLAYNUM}-passwd"
GUACVNCPASSWDCLEAR="${GUACVNCDIR}/.${HOST}:${DISPLAYNUM}-passwd-clear"
echo ${GUACVNCPASSWD} | vncpasswd -f > ${GUACVNCPASSWDFILE}
touch ${GUACVNCPASSWDCLEAR}
chmod 0700 ${GUACVNCPASSWDCLEAR}
echo ${GUACVNCPASSWD} > ${GUACVNCPASSWDCLEAR}

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


# Run the command and record the process ID.
PIDFILE="${GUACVNCDIR}/${HOST}:${DISPLAYNUM}.pid"
CMD="Xvnc :${DISPLAYNUM} 
	-desktop ${DESKTOPNAME} 
	-auth ${GUACVNCDIR}/.Xauthority 
	-geometry ${GEOMETRY} 
	-depth ${DEPTH} 
	-rfbwait 120000
	-rfbauth ${GUACVNCPASSWDFILE}
	-rfbport ${GUACVNCPORT} 
	-fp ${FONTPATH}
	-pn
"
${CMD} >> ${GUACVNCDESKTOPLOG} 2>&1 & echo $! > ${PIDFILE}

# Create the user's xstartup script if necessary.
XSTARTUP=${GUACVNCDIR}/xstartup
if [ ! -f ${XSTARTUP} ]; then
	echo ${XSTARTUP} does not exist.  Creating now...
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

${XSTARTUP} >> ${GUACVNCDESKTOPLOG} 2>&1 &

GUACURI="vnc://$(whoami):${GUACVNCPASSWD}@${HOST}:${GUACVNCPORT}"
echo $GUACURI
