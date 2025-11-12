#!/bin/bash
#
# Checkmk Agent Update Script
# Updates agents from 2.3.0p24 to 2.4.0p2
#

set -e
set -o pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CHECKMK_SERVER="10.10.10.5"
CHECKMK_USER="brian"
TARGET_VERSION="2.4.0p2"
AGENT_DEB="/omd/sites/monitoring/share/check_mk/agents/check-mk-agent_2.4.0p2-1_all.deb"
AGENT_RPM="/omd/sites/monitoring/share/check_mk/agents/check-mk-agent-2.4.0p2-1.noarch.rpm"

# Logging
log() {
    echo -e "${2:-$NC}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

log_success() {
    log "✓ $1" "$GREEN"
}

log_error() {
    log "✗ $1" "$RED"
}

log_warning() {
    log "⚠ $1" "$YELLOW"
}

log_info() {
    log "ℹ $1" "$BLUE"
}

# Check current version
check_version() {
    local host=$1
    log_info "Checking version on $host..."
    version=$(ssh $CHECKMK_USER@$CHECKMK_SERVER "sudo su - monitoring -c 'cmk -d $host 2>&1 | grep \"Version:\" | head -1 | cut -d: -f2 | tr -d \" \"'")
    echo "$version"
}

# Update Linux host (Debian/Ubuntu)
update_linux_deb() {
    local hostname=$1
    local ip=$2
    local ssh_user=$3

    log_info "Updating $hostname ($ip) - Debian/Ubuntu"

    # Copy package to local temp
    log_info "Downloading agent package from Checkmk server..."
    scp -q $CHECKMK_USER@$CHECKMK_SERVER:$AGENT_DEB /tmp/check-mk-agent.deb || {
        log_error "Failed to download agent package"
        return 1
    }

    # Copy to remote host
    log_info "Copying package to $hostname..."
    scp -q /tmp/check-mk-agent.deb $ssh_user@$ip:/tmp/ || {
        log_error "Failed to copy package to $hostname"
        rm -f /tmp/check-mk-agent.deb
        return 1
    }

    # Install on remote
    log_info "Installing agent on $hostname..."
    ssh $ssh_user@$ip "sudo dpkg -i /tmp/check-mk-agent.deb && sudo systemctl restart check-mk-agent.socket" || {
        log_error "Failed to install agent on $hostname"
        rm -f /tmp/check-mk-agent.deb
        return 1
    }

    # Clean up
    rm -f /tmp/check-mk-agent.deb
    ssh $ssh_user@$ip "rm -f /tmp/check-mk-agent.deb"

    # Verify
    sleep 2
    new_version=$(check_version $hostname)
    if [[ "$new_version" == "$TARGET_VERSION" ]]; then
        log_success "$hostname updated successfully to $new_version"
        return 0
    else
        log_warning "$hostname reports version $new_version (expected $TARGET_VERSION)"
        return 1
    fi
}

# Update Linux host (RPM-based)
update_linux_rpm() {
    local hostname=$1
    local ip=$2
    local ssh_user=$3

    log_info "Updating $hostname ($ip) - RPM-based"

    # Copy package to local temp
    log_info "Downloading agent package from Checkmk server..."
    scp -q $CHECKMK_USER@$CHECKMK_SERVER:$AGENT_RPM /tmp/check-mk-agent.rpm || {
        log_error "Failed to download agent package"
        return 1
    }

    # Copy to remote host
    log_info "Copying package to $hostname..."
    scp -q /tmp/check-mk-agent.rpm $ssh_user@$ip:/tmp/ || {
        log_error "Failed to copy package to $hostname"
        rm -f /tmp/check-mk-agent.rpm
        return 1
    }

    # Install on remote
    log_info "Installing agent on $hostname..."
    ssh $ssh_user@$ip "sudo rpm -U /tmp/check-mk-agent.rpm && sudo systemctl restart check-mk-agent.socket" || {
        log_error "Failed to install agent on $hostname"
        rm -f /tmp/check-mk-agent.rpm
        return 1
    }

    # Clean up
    rm -f /tmp/check-mk-agent.rpm
    ssh $ssh_user@$ip "rm -f /tmp/check-mk-agent.rpm"

    # Verify
    sleep 2
    new_version=$(check_version $hostname)
    if [[ "$new_version" == "$TARGET_VERSION" ]]; then
        log_success "$hostname updated successfully to $new_version"
        return 0
    else
        log_warning "$hostname reports version $new_version (expected $TARGET_VERSION)"
        return 1
    fi
}

# Detect OS type
detect_os() {
    local ip=$1
    local ssh_user=$2

    os_info=$(ssh $ssh_user@$ip "cat /etc/os-release 2>/dev/null | grep ^ID= | cut -d= -f2 | tr -d '\"'")
    echo "$os_info"
}

# Main menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "  Checkmk Agent Update Tool"
    echo "  Target Version: $TARGET_VERSION"
    echo "=========================================="
    echo ""
    echo "Hosts to update:"
    echo "  1) bookworm    (10.10.10.7)   - Debian 12"
    echo "  2) jarvis      (10.10.10.49)  - Ubuntu 24.04"
    echo "  3) jellyfin    (10.10.10.42)  - Ubuntu 22.04"
    echo "  4) ser8        (10.10.10.96)  - Linux"
    echo "  5) zeus        (10.10.10.2)   - Linux"
    echo ""
    echo "  6) Update ALL Linux hosts"
    echo "  7) Check versions only"
    echo "  0) Exit"
    echo ""
    read -p "Select option: " choice
}

# Update all hosts
update_all() {
    log_info "Starting bulk update of all Linux hosts..."
    echo ""

    declare -A hosts=(
        ["bookworm"]="10.10.10.7:brian"
        ["jarvis"]="10.10.10.49:brian"
        ["jellyfin"]="10.10.10.42:brian"
        ["ser8"]="10.10.10.96:brian"
        ["zeus"]="10.10.10.2:brian"
    )

    success_count=0
    fail_count=0

    for hostname in "${!hosts[@]}"; do
        IFS=':' read -r ip ssh_user <<< "${hosts[$hostname]}"
        echo ""
        log_info "Processing $hostname..."

        # Check if already updated
        current_version=$(check_version $hostname)
        if [[ "$current_version" == "$TARGET_VERSION" ]]; then
            log_success "$hostname already at version $TARGET_VERSION"
            ((success_count++))
            continue
        fi

        # Detect OS
        os_type=$(detect_os $ip $ssh_user)
        log_info "Detected OS: $os_type"

        # Update based on OS
        if [[ "$os_type" =~ ^(debian|ubuntu)$ ]]; then
            if update_linux_deb $hostname $ip $ssh_user; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        elif [[ "$os_type" =~ ^(rhel|centos|rocky|fedora)$ ]]; then
            if update_linux_rpm $hostname $ip $ssh_user; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        else
            log_warning "Unknown OS type: $os_type, assuming Debian-based"
            if update_linux_deb $hostname $ip $ssh_user; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        fi
        echo ""
    done

    echo ""
    echo "=========================================="
    log_info "Update Summary"
    echo "=========================================="
    log_success "Successful: $success_count"
    if [[ $fail_count -gt 0 ]]; then
        log_error "Failed: $fail_count"
    fi
    echo ""
}

# Check versions only
check_all_versions() {
    log_info "Checking agent versions on all hosts..."
    echo ""

    hosts=("bookworm" "jarvis" "jellyfin" "ser8" "zeus" "geekom" "checkmk" "homeassistant")

    for hostname in "${hosts[@]}"; do
        version=$(check_version $hostname 2>/dev/null || echo "ERROR")
        if [[ "$version" == "$TARGET_VERSION" ]]; then
            log_success "$hostname: $version"
        elif [[ "$version" == "ERROR" ]]; then
            log_error "$hostname: Unable to check"
        else
            log_warning "$hostname: $version (needs update)"
        fi
    done
    echo ""
}

# Main loop
main() {
    while true; do
        show_menu
        case $choice in
            1)
                echo ""
                update_linux_deb "bookworm" "10.10.10.7" "brian"
                ;;
            2)
                echo ""
                update_linux_deb "jarvis" "10.10.10.49" "brian"
                ;;
            3)
                echo ""
                update_linux_deb "jellyfin" "10.10.10.42" "brian"
                ;;
            4)
                echo ""
                ip="10.10.10.96"
                os_type=$(detect_os $ip "brian")
                log_info "Detected OS: $os_type"
                if [[ "$os_type" =~ ^(debian|ubuntu)$ ]]; then
                    update_linux_deb "ser8" $ip "brian"
                else
                    update_linux_rpm "ser8" $ip "brian"
                fi
                ;;
            5)
                echo ""
                ip="10.10.10.2"
                os_type=$(detect_os $ip "brian")
                log_info "Detected OS: $os_type"
                if [[ "$os_type" =~ ^(debian|ubuntu)$ ]]; then
                    update_linux_deb "zeus" $ip "brian"
                else
                    update_linux_rpm "zeus" $ip "brian"
                fi
                ;;
            6)
                echo ""
                read -p "Update ALL Linux hosts? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    update_all
                fi
                ;;
            7)
                echo ""
                check_all_versions
                ;;
            0)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option"
                ;;
        esac

        read -p "Press Enter to continue..."
    done
}

# Run main
main
