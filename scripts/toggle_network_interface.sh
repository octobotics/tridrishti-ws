#!/usr/bin/env bash

set -Eeuo pipefail

INTERFACE="enP1p1s0"
PROFILE="robot-network-mode"

INTER_DEVICE_ADDRESS="10.0.0.1/24"
INTER_DEVICE_PEER="10.0.0.2"

NORMAL_ADDRESS="192.168.0.10/24"
NORMAL_GATEWAY="192.168.0.1"
NORMAL_DNS="192.168.0.1,1.1.1.1"

MULTICAST_ROUTE="224.0.0.0/4"
MULTICAST_TEST_ADDRESS="239.0.0.1"
ROUTE_METRIC="10"

usage() {
    cat <<EOF
Usage: $(basename "$0") [MODE]

Default: inter-device (10.0.0.1/24)

Modes:
  inter-device  Set $INTERFACE to 10.0.0.1/24; peer device is 10.0.0.2/24
  normal        Set $INTERFACE to 192.168.0.10/24 with gateway 192.168.0.1
  toggle        Switch between inter-device and normal mode
  status        Show the current mode, routes and NetworkManager state
  help          Show this help

Multicast range $MULTICAST_ROUTE is always routed through $INTERFACE.
Changing modes can disconnect an SSH session using $INTERFACE.
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_system() {
    command -v nmcli >/dev/null 2>&1 ||
        die "nmcli is not installed"

    command -v ip >/dev/null 2>&1 ||
        die "iproute2 is not installed"

    [[ -e "/sys/class/net/$INTERFACE" ]] ||
        die "interface $INTERFACE does not exist"
}

require_root() {
    if (( EUID != 0 )); then
        exec sudo -- "$0" "$@"
    fi
}

ensure_profile() {
    if ! nmcli -g connection.id connection show "$PROFILE" \
        >/dev/null 2>&1; then

        nmcli connection add \
            type ethernet \
            con-name "$PROFILE" \
            ifname "$INTERFACE"
    fi

    nmcli connection modify "$PROFILE" \
        connection.interface-name "$INTERFACE" \
        connection.autoconnect yes \
        connection.autoconnect-priority 999 \
        ipv4.routes "$MULTICAST_ROUTE" \
        ipv4.route-metric "$ROUTE_METRIC" \
        ipv6.method link-local
}

verify_multicast_route() {
    local route

    route="$(ip route get "$MULTICAST_TEST_ADDRESS" 2>/dev/null || true)"

    printf '\nMulticast route:\n%s\n' "${route:-not available}"

    if [[ "$route" != *"dev $INTERFACE"* ]]; then
        printf 'Warning: multicast is not using %s\n' "$INTERFACE" >&2
        return 1
    fi

    printf 'Multicast is correctly routed through %s.\n' "$INTERFACE"
}

activate_profile() {
    nmcli connection up "$PROFILE" ifname "$INTERFACE"
    verify_multicast_route
}

set_inter_device() {
    ensure_profile

    nmcli connection modify "$PROFILE" \
        ipv4.method manual \
        ipv4.addresses "$INTER_DEVICE_ADDRESS" \
        ipv4.gateway "" \
        ipv4.dns "" \
        ipv4.never-default yes \
        ipv4.routes "$MULTICAST_ROUTE" \
        ipv4.route-metric "$ROUTE_METRIC"

    activate_profile

    printf '\nInter-device mode active:\n'
    printf '  Interface: %s\n' "$INTERFACE"
    printf '  Address:   %s\n' "$INTER_DEVICE_ADDRESS"
    printf '  Peer:      %s/24\n' "$INTER_DEVICE_PEER"
}

set_normal() {
    ensure_profile

    nmcli connection modify "$PROFILE" \
        ipv4.method manual \
        ipv4.addresses "$NORMAL_ADDRESS" \
        ipv4.gateway "$NORMAL_GATEWAY" \
        ipv4.dns "$NORMAL_DNS" \
        ipv4.never-default no \
        ipv4.routes "$MULTICAST_ROUTE" \
        ipv4.route-metric "$ROUTE_METRIC"

    activate_profile

    printf '\nNormal mode active:\n'
    printf '  Interface: %s\n' "$INTERFACE"
    printf '  Address:   %s\n' "$NORMAL_ADDRESS"
    printf '  Gateway:   %s\n' "$NORMAL_GATEWAY"
}

current_address() {
    nmcli -g IP4.ADDRESS device show "$INTERFACE" 2>/dev/null |
        awk -F/ 'NF { print $1; exit }'
}

show_status() {
    local address active_profile mode

    address="$(current_address || true)"
    active_profile="$(
        nmcli -g GENERAL.CONNECTION device show "$INTERFACE" \
            2>/dev/null || true
    )"

    case "$address" in
        10.0.0.1)     mode="inter-device" ;;
        192.168.0.10) mode="normal" ;;
        "")           mode="unconfigured" ;;
        *)            mode="other" ;;
    esac

    printf 'Interface:      %s\n' "$INTERFACE"
    printf 'Mode:           %s\n' "$mode"
    printf 'IPv4 address:   %s\n' "${address:-none}"
    printf 'Active profile: %s\n' "${active_profile:---}"

    printf '\nRoutes on %s:\n' "$INTERFACE"
    ip -4 route show dev "$INTERFACE"

    verify_multicast_route
}

main() {
    local action="${1:-inter-device}"

    require_system

    case "$action" in
        inter-device|interdevice|device)
            require_root "$@"
            set_inter_device
            ;;
        normal|node)
            require_root "$@"
            set_normal
            ;;
        toggle)
            require_root "$@"

            if [[ "$(current_address || true)" == "10.0.0.1" ]]; then
                set_normal
            else
                set_inter_device
            fi
            ;;
        status)
            show_status
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"

