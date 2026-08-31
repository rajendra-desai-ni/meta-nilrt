#!/bin/bash

ARCH=$(uname -m)

export PATH="/sbin:/bin:/usr/sbin:/usr/bin"

umask 0022

NIRECOVERY_MOUNTPOINT=/mnt/NIRECOVERY
MOUNT_NIRECOVERY_USB_TIME=10

find_udhcpc() {
	if command -v udhcpc >/dev/null 2>&1; then
		echo "udhcpc"
		return 0
	fi

	if [ -x /usr/lib/busybox/sbin/udhcpc ]; then
		echo "/usr/lib/busybox/sbin/udhcpc"
		return 0
	fi

	if command -v busybox >/dev/null 2>&1; then
		echo "busybox udhcpc"
		return 0
	fi

	return 1
}

configure_static_network() {
	local dev="$1"
	local ipv4_cidr="${NETWORK_BOOTSTRAP_IPV4:-}"
	local gateway="${NETWORK_BOOTSTRAP_GATEWAY:-}"
	local dns_server="${NETWORK_BOOTSTRAP_DNS:-}"

	if [ -z "$ipv4_cidr" ]; then
		return 1
	fi

	ip address flush dev "$dev" scope global 2>/dev/null || true
	ip address add "$ipv4_cidr" dev "$dev" || return 1

	if [ -n "$gateway" ]; then
		ip route replace default via "$gateway" dev "$dev" || return 1
	fi

	if [ -n "$dns_server" ]; then
		echo "nameserver $dns_server" > /etc/resolv.conf
	fi

	return 0
}

network_bootstrap() {
	local udhcpc_cmd

	if [ "${NETWORK_BOOTSTRAP_ENABLED:-0}" != "1" ]; then
		return 0
	fi

	udhcpc_cmd=$(find_udhcpc || true)

	ip link set lo up 2>/dev/null || true
	for iface in /sys/class/net/*; do
		dev=${iface##*/}
		[ "$dev" = "lo" ] && continue
		ip link set "$dev" up 2>/dev/null || true
		if ! configure_static_network "$dev" && [ -n "$udhcpc_cmd" ]; then
			$udhcpc_cmd -i "$dev" -n -q -t 5 -T 3 || true
		fi
	done

	if command -v sshd >/dev/null 2>&1; then
		/usr/sbin/sshd -D &
	elif command -v dropbear >/dev/null 2>&1; then
		dropbear -R -p 22 &
	fi

	if [ -n "${PROVISIONING_BUNDLE_URL:-}" ] && command -v curl >/dev/null 2>&1; then
		mkdir -p /netprov
		curl -fsSL "${PROVISIONING_BUNDLE_URL}" -o /tmp/ni_provisioning.tar.gz || true
		if [ -f /tmp/ni_provisioning.tar.gz ]; then
			tar -xzf /tmp/ni_provisioning.tar.gz -C /netprov || true
			if [ -d /netprov/payload ]; then
				PAYLOAD_BASE=/netprov/payload
				export PAYLOAD_BASE
			fi
		fi
	fi

	if [ -n "${PROVISION_ANSWERS_URL:-}" ] && command -v curl >/dev/null 2>&1; then
		curl -fsSL "${PROVISION_ANSWERS_URL}" -o /tmp/ni_provisioning.answers || true
	fi
}

early_setup() {
	mkdir -p /proc
	mkdir -p /sys
	mkdir -p /run/lock
	mount -t proc proc /proc
	mount -t sysfs sysfs /sys
	mount -t efivarfs efivarfs /sys/firmware/efi/efivars
	mount -t devtmpfs none /dev

	if [ "${NETWORK_BOOTSTRAP_ENABLED:-0}" = "1" ]; then
		network_bootstrap
	fi

	COUNT=0
	while [ $COUNT -le "$MOUNT_NIRECOVERY_USB_TIME" ]; do
		mount_nirecovery_usb
		if mountpoint -q $NIRECOVERY_MOUNTPOINT; then
			break
		fi
		COUNT=$(expr $COUNT + 1)
		sleep 1
	done

	# Set hostname
	echo "recovery" | tee /etc/hostname > /proc/sys/kernel/hostname
}

# Removes the /boot/bootmode file that may force
# grub to boot into restore over and over again.
remove_bootmode() {
	NILRT_MOUNT_POINT=/mnt
	if mount -L nilrt $NILRT_MOUNT_POINT; then
		rm $NILRT_MOUNT_POINT/boot/bootmode
		umount $NILRT_MOUNT_POINT
	fi
}

# HACK: BIOS enables cstates when they should be disabled and this makes the
# processor frequency go bonkers on crio's 903x dual-core (not 9034) affecting
# performance of the restore-mode's rootfs unpacking. We disable all cstates
# except C0 in all cpu cores until we get a BIOS update with cstates disabled
disable_x64_cstates() {
	shopt -s nullglob
	for CSTATE_DISABLE in /sys/devices/system/cpu/cpu*/cpuidle/state[^0]/disable; do
		echo 1 > $CSTATE_DISABLE
	done
}

show_console() {
	while true; do
		echo ""
		echo " ------------------------------------------------------"
		echo " -  NI Linux Real-Time Recovery shell                 -"
		echo " ------------------------------------------------------"
		echo ""

		/usr/bin/setsid /sbin/getty 38400 console --noclear -a root --login-options "-p -- \u"

		sleep 1
	done
}

start_serial_console() {
	SERIAL_TTY="ttyS0"
	if [ -c /dev/${SERIAL_TTY} ]; then
		active_consoles=$(cat /sys/devices/virtual/tty/console/active)
		if [[ ! "${active_consoles[@]}" =~ "${SERIAL_TTY}" ]]; then
			while true; do
				/usr/bin/setsid /sbin/getty 115200 ${SERIAL_TTY} --noclear -a root --login-options "-p -- \u"

				sleep 1
			done
		fi
	fi
}

mount_nirecovery_usb()
{
	if ! mountpoint -q $NIRECOVERY_MOUNTPOINT; then
		if [ ! -d $NIRECOVERY_MOUNTPOINT ]; then
			mkdir -p $NIRECOVERY_MOUNTPOINT
		fi
		mount -o ro,sync,relatime -L NIRECOVERY $NIRECOVERY_MOUNTPOINT &> /dev/null
	fi
}

load_recovery_modules() {
	# Load input and common VM platform/network drivers before network bootstrap
	# so recovery can discover NICs and request DHCP during early setup.
	modprobe atkbd 2> /dev/null
	modprobe i8042 2> /dev/null
	modprobe e1000 2> /dev/null
	modprobe e1000e 2> /dev/null
	modprobe igb 2> /dev/null
	modprobe virtio_net 2> /dev/null
	modprobe vmxnet3 2> /dev/null
	modprobe hv_vmbus 2> /dev/null
	modprobe hv_balloon 2> /dev/null
	modprobe hv_storvsc 2> /dev/null
	modprobe hv_utils 2> /dev/null
	modprobe hyperv-keyboard 2> /dev/null
}

load_recovery_modules
early_setup

start_serial_console &

# Arch-specific set-up
if [[ $ARCH == "x86_64" ]]; then
	disable_x64_cstates
	remove_bootmode 2> /dev/null
fi

if [[ $ARCH =~ ^(x86_64|armv7l)$ ]]; then
	/ni_provisioning
else
	echo ""
	echo "ERROR: ARCH=$ARCH is not supported by provisioning tool."
	echo " You can try running /ni_provisioning manually from the shell."
	echo ""
fi

sync
show_console


# Uh oh. Something went wrong. We should never reach this point.
# Sync file systems and exit init (this process).

sync
exit 1
