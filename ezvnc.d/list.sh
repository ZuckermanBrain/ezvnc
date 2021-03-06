#!/bin/bash
# ez-list.sh
# jsp2205, 2020
# Columbia University, Zuckerman Research Computing
#
# This script will output URIs for all active VNC sessions that can be used with Guacamole.
#
# See here for more details: https://guacamole.apache.org/doc/gug/adhoc-connections.html#using-quickconnect

ezvnc-list() {
	EZVNCDIR=${HOME}/.ezvnc

	# We use nullglob her temporarily to fetch all the active processes that we know of.
	# If we don't use nullglob, the string with the wildcard is interpreted as a string literal
	# which messes up the for loop below.
	shopt -s nullglob
	PIDFILES=(${EZVNCDIR}/*.pid)
	shopt -u nullglob

	# Create a hash to group VNC sessios by host.
	declare -A EZVNCURIS
	declare -A EZVNCDISPLAYNUMS
	declare -A EZVNCDISPLAYNAMES
	declare -A EZVNCSESSIONHOSTIDX

	# Get the longest URI / display name lengths for formatting / printf
	LONGESTURILEN=0
	LONGESTNAMELEN=0

	for PIDFILE in ${PIDFILES[@]};
	do
		HOST=$(basename -s .pid ${PIDFILE} | cut -d: -f1)
		# Make sure index is initialized and set to 1 (we're using 1-indexing for end-user readability)
		[ -z "${EZVNCSESSIONHOSTIDX[${HOST}]}" ] && EZVNCSESSIONHOSTIDX[${HOST}]=1
		DISPLAYNUM=$(basename -s .pid ${PIDFILE} | cut -d: -f2)
		EZVNCPORT="59$(printf '%02d' ${DISPLAYNUM})"
		EZVNCPASSWD=$(cat "${EZVNCDIR}/.${HOST}:${DISPLAYNUM}-passwd-clear")
		if [ -f "${EZVNCDIR}/${HOST}:${DISPLAYNUM}-name" ]; then
			EZVNCDISPNAME=$(cat "${EZVNCDIR}/${HOST}:${DISPLAYNUM}-name")
		else
			EZVNCDISPNAME="Untitled"
		fi
		if [ $(echo "${EZVNCDISPNAME}" | wc -c) -gt ${LONGESTNAMELEN} ]; then
			LONGESTNAMELEN=$(echo ${EZVNCDISPNAME} | wc -c)
		fi
		IDX=${EZVNCSESSIONHOSTIDX[${HOST}]}
		EZVNCURI="vnc://${HOST}:${EZVNCPORT}?password=${EZVNCPASSWD}"
		if [ $(echo "${EZVNCURI}" | wc -c) -gt ${LONGESTURILEN} ]; then
			LONGESTURILEN=$(echo ${EZVNCURI} | wc -c)
		fi
		EZVNCURIS[${HOST}_${IDX}]=${EZVNCURI}
		EZVNCDISPLAYNUMS[${HOST}_${IDX}]=${DISPLAYNUM}
		EZVNCDISPLAYNAMES[${HOST}_${IDX}]=${EZVNCDISPNAME}
		EZVNCSESSIONHOSTIDX[${HOST}]=$(( ${IDX} + 1 ))
	done

	for HOST in ${!EZVNCSESSIONHOSTIDX[@]};
	do
		IDX=1
		echo -e "Active VNC Connections for ${HOST}:\n"
		HOSTLEN=$(echo ${HOST} | wc -c)
		printf "%-3s %-${LONGESTNAMELEN}s %-${LONGESTURILEN}s %-${HOSTLEN}s %-2s\n" "" "Name" "URI" "Host" "Display Number"
		while [ ${IDX} -ne ${EZVNCSESSIONHOSTIDX[${HOST}]} ];
		do
			EZVNCDISPNAME=${EZVNCDISPLAYNAMES["${HOST}_${IDX}"]}
			EZURI=${EZVNCURIS["${HOST}_${IDX}"]}
			EZDISPLAYNUM=${EZVNCDISPLAYNUMS["${HOST}_${IDX}"]}
			printf "%-3s %-${LONGESTNAMELEN}s %-${LONGESTURILEN}s %-${HOSTLEN}s %-2s\n" "${IDX}." "${EZVNCDISPNAME}" "${EZURI}" "${HOST}" "${EZDISPLAYNUM}"
			IDX=$(( ${IDX} + 1 ))
		done
		echo
	done
}
