#!/bin/bash
# guac-stop.sh
# jsp2205, 2020
# Columbia University, Zuckerman Research Computing
#
# This is a wrapper to used to kill active VNC sessions.
#
# See here for more details: https://guacamole.apache.org/doc/gug/adhoc-connections.html#using-quickconnect

ezvnc-stop() {
	if [ $# -eq 1 ]; then
		shopt -s nullglob
		QUERY=$(for i in ~/.ezvnc/*-name; do echo -e -n "$(cat ${i}),$(basename ${i})\n"; done | fgrep "${1},")
		if [ $(echo ${QUERY} | wc -w) -gt 1 ]; then
			echo "Found multiple displays with the name '${1}'.  This shouldn't happen." 
		       	echo "Contact your IT department or the developers to report an issue."
		       	echo "You can still stop displays by using the hostname and the display number."
			echo "Exiting..."
			exit 1
		fi
		RECORD=$(echo ${QUERY}  | fgrep "${1},")
		shopt -u nullglob
		if [ -z ${RECORD} ]; then
			echo "Could not find a display named '${1}' to stop. Exiting..."
			exit 1
		fi
		HOST=$(echo ${RECORD} | cut -d, -f2 | cut -d: -f1)
		DISPLAYNUM=$(echo ${RECORD} | cut -d, -f2 | cut -d: -f2 | sed -e 's/-name//')
	elif [ $# -eq 2 ]; then
		HOST=${1}
		DISPLAYNUM=${2}
	else
		return
	fi
	
	HOSTFLAG=0
	declare HOSTS
	for IP in $(hostname -I); do
		TMPHOST=$(dig -x ${IP} +short | sed -e 's/\.$//' | awk '{ print $1 }')
		if [ ${HOST} = ${TMPHOST} ]; then
			HOSTFLAG=1
			break
		fi
		HOSTS+=(${TMPHOST})
	done

	if [ ${HOSTFLAG} -eq 0 ]; then
		echo "$(basename ${0}) must be run on the server that the VNC session was started on."
		echo "Current host(s): ${HOSTS[@]}"
		echo "Specified host: ${HOST}"
		echo "Quitting now."
		return 1
	fi

	EZVNCDIR=${HOME}/.ezvnc
	PIDFILE="${EZVNCDIR}/${HOST}:${DISPLAYNUM}.pid"
	EZVNCPASSWDFILE="${EZVNCDIR}/${HOST}:${DISPLAYNUM}-passwd"
	EZVNCPASSWDCLEAR="${EZVNCDIR}/.${HOST}:${DISPLAYNUM}-passwd-clear"
	EZVNCDISPLAYNAMEFILE="${EZVNCDIR}/${HOST}:${DISPLAYNUM}-name"

	if [ ! -f ${PIDFILE} ]; then
		echo "Warning: The specified VNC session (${HOST}:${DISPLAYNUM}) does not exist."
		echo "Quitting now."
		return 1
	else
		kill $(cat ${PIDFILE})
		rm ${PIDFILE}
		rm ${EZVNCPASSWDFILE}
		rm ${EZVNCPASSWDCLEAR}
		if [ -f ${EZVNCDISPLAYNAMEFILE} ]; then
			rm ${EZVNCDISPLAYNAMEFILE}
		fi
		xauth -f ${EZVNCDIR}/.Xauthority remove ${HOST}:${DISPLAYNUM}
		xauth -f ${EZVNCDIR}/.Xauthority remove ${HOST}/unix:${DISPLAYNUM}
	fi
}
