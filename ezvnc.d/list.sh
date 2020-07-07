#!/bin/bash
# ez-list.sh
# jsp2205, 2020
# Columbia University, Zuckerman Research Computing
#
# This script will output URIs for all active VNC sessions that can be used with Guacamole.
#
# See here for more details: https://guacamole.apache.org/doc/gug/adhoc-connections.html#using-quickconnect

ezvnc-list() {
	shopt -s nullglob

	EZVNCDIR=${HOME}/.ezvnc

	# Create a hash to group VNC sessios by host.
	declare -A EZVNCURIS
	declare -A EZVNCDISPLAYNUMS
	declare -A EZVNCSESSIONHOSTIDX
	# Get the longest URI length for formatting / printf
	LONGESTURILEN=0
	for PIDFILE in ${EZVNCDIR}/*.pid;
	do
		HOST=$(basename -s .pid ${PIDFILE} | cut -d: -f1)
		# Make sure index is initialized and set to 1 (we're using 1-indexing for end-user readability)
		[ -z "${EZVNCSESSIONHOSTIDX[${HOST}]}" ] && EZVNCSESSIONHOSTIDX[${HOST}]=1
		DISPLAYNUM=$(basename -s .pid ${PIDFILE} | cut -d: -f2)
		EZVNCPORT="59$(printf '%02d' ${DISPLAYNUM})"
		EZVNCPASSWDCLEAR="${EZVNCDIR}/.${HOST}:${DISPLAYNUM}-passwd-clear"
		EZVNCPASSWD=$(cat ${EZVNCPASSWDCLEAR})
		IDX=${EZVNCSESSIONHOSTIDX[${HOST}]}
		EZVNCURI="vnc://$(whoami):${EZVNCPASSWD}@${HOST}:${EZVNCPORT}"
		if [ $(echo ${EZVNCURI} | wc -c) -gt ${LONGESTURILEN} ]; then
			LONGESTURILEN=$(echo ${EZVNCURI} | wc -c)
		fi
		EZVNCURIS[${HOST}_${IDX}]=${EZVNCURI}
		EZVNCDISPLAYNUMS[${HOST}_${IDX}]=${DISPLAYNUM}
		EZVNCSESSIONHOSTIDX[${HOST}]=$(( ${IDX} + 1 ))
	done

	for HOST in ${!EZVNCSESSIONHOSTIDX[@]};
	do
		IDX=1
		echo -e "Active VNC Connections for ${HOST}:\n"
		HOSTLEN=$(echo ${HOST} | wc -c)
		printf "%-3s %-${LONGESTURILEN}s %-${HOSTLEN}s %-2s\n" "" "URI" "Host" "Display Number"
		while [ ${IDX} -ne ${EZVNCSESSIONHOSTIDX[${HOST}]} ];
		do
			EZURI=${EZVNCURIS["${HOST}_${IDX}"]}
			EZDISPLAYNUM=${EZVNCDISPLAYNUMS["${HOST}_${IDX}"]}
			printf "%-3s %-${LONGESTURILEN}s %-${HOSTLEN}s %-2s\n" "${IDX}." ${EZURI} ${HOST} ${EZDISPLAYNUM}
			IDX=$(( ${IDX} + 1 ))
		done
		echo
	done
}
