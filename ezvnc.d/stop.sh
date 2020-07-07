#!/bin/bash
# guac-stop.sh
# jsp2205, 2020
# Columbia University, Zuckerman Research Computing
#
# This is a wrapper to used to kill active VNC sessions.
#
# See here for more details: https://guacamole.apache.org/doc/gug/adhoc-connections.html#using-quickconnect

ezvnc-stop() {
	if [ $# -ne 2 ]; then
		exit
	fi
	# Params
	HOST=${1}
	DISPLAYNUM=${2}

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
		exit 1
	fi

	EZVNCDIR=${HOME}/.ezvnc
	PIDFILE="${EZVNCDIR}/${HOST}:${DISPLAYNUM}.pid"
	EZVNCPASSWDFILE="${EZVNCDIR}/${HOST}:${DISPLAYNUM}-passwd"
	EZVNCPASSWDCLEAR="${EZVNCDIR}/.${HOST}:${DISPLAYNUM}-passwd-clear"

	if [ ! -f ${PIDFILE} ]; then
		echo "Warning: The specified VNC session (${HOST}:${DISPLAYNUM}) does not exist."
		echo "Quitting now."
		exit 1
	else
		kill $(cat ${PIDFILE})
		rm ${PIDFILE}
		rm ${EZVNCPASSWDFILE}
		rm ${EZVNCPASSWDCLEAR}
		xauth -f ${EZVNCDIR}/.Xauthority remove ${HOST}:${DISPLAYNUM}
		xauth -f ${EZVNCDIR}/.Xauthority remove ${HOST}/unix:${DISPLAYNUM}
	fi
}
