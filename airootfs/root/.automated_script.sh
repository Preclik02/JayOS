#!/usr/bin/env bash

script_cmdline() {
    local param
    for param in $(</proc/cmdline); do
        case "${param}" in
            script=*)
                echo "${param#*=}"
                return 0
                ;;
        esac
    done
}

automated_script() {
    local script rt
    script="$(script_cmdline)"

    # 1. Standard Archiso network parameter handler
    if [[ -n "${script}" && ! -x /tmp/startup_script ]]; then
        if [[ "${script}" =~ ^((http|https|ftp|tftp)://) ]]; then
            printf '%s: downloading %s\n' "$0" "${script}"
            systemd-run --pty --quiet -p Wants=network-online.target -p After=network-online.target \
                curl "${script}" --location --retry-connrefused --retry 10 --fail -s -o /tmp/startup_script
            rt=$?
        else
            cp "${script}" /tmp/startup_script
            rt=$?
        fi
        if [[ ${rt} -eq 0 ]]; then
            chmod +x /tmp/startup_script
            printf '%s: executing automated script\n' "$0"
            /tmp/startup_script
        fi

    # 2. JayOS Core Toolset Deployment Pipeline
    elif [[ -z "${script}" ]]; then
        printf '%s: Initializing custom JayOS deployment...\n' "$0"

        # Wait for system layers and package managers to stabilize
        systemctl is-system-running --wait

        # Create your default secure user (jaylub) if not present
        if ! id "jaylub" &>/dev/null; then
            printf 'Creating user account: jaylub...\n'
            useradd -m -G wheel,video,audio -s /bin/zsh jaylub
            echo "jaylub:password" | chpasswd
            echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
        fi

        # Bulletproof network synchronization check
        printf 'Waiting until network adapter is completely online...\n'
        systemctl start systemd-networkd-wait-online.service &>/dev/null
        sleep 3 # Give the network configuration table a brief moment to settle

        # Clone your custom secure environment toolset
        printf 'Fetching toolset from github.com/preclik02/null...\n'
        git clone https://github.com/jaylubiny/null.git /tmp/null-toolset

        # Execute the wrapper compilation/installation script
        if [[ -f /tmp/null-toolset/install.sh ]]; then
            printf 'Executing custom environment install.sh...\n'
            chmod +x /tmp/null-toolset/install.sh
            cd /tmp/null-toolset && ./install.sh
        else
            printf 'WARNING: No install.sh found at repository root.\n'
        fi
    fi
}

if [[ $(tty) == "/dev/tty1" ]]; then
    automated_script
fi
