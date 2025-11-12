#!/bin/bash
#
# Checkmk 2.3 to 2.4 Upgrade Script
# For Debian 12 (Bookworm)
# Upgrades Checkmk Raw Edition with full backup and safety checks
#

set -e  # Exit on error
set -o pipefail  # Exit on pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CHECKMK_VERSION_SHORT="2.4.0p1"
CHECKMK_VERSION="2.4.0p1.cre"
DOWNLOAD_URL="https://download.checkmk.com/checkmk/${CHECKMK_VERSION_SHORT}/check-mk-raw-${CHECKMK_VERSION_SHORT}_0.bookworm_amd64.deb"
BACKUP_DIR="/tmp/checkmk_upgrade_backups"
LOG_FILE="/tmp/checkmk_upgrade_$(date +%Y%m%d_%H%M%S).log"
DOWNLOAD_FILE="/tmp/check-mk-raw-${CHECKMK_VERSION_SHORT}_0.bookworm_amd64.deb"

# Logging function
log() {
    echo -e "${2:-$NC}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
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

# Error handler
error_exit() {
    log_error "$1"
    log_error "Upgrade failed! Check log file: $LOG_FILE"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root. Use: sudo bash $0"
    fi
    log_success "Running as root"
}

# Detect site name
detect_site() {
    log_info "Detecting Checkmk site..."

    SITES=$(omd sites | awk '{print $1}')
    SITE_COUNT=$(echo "$SITES" | wc -l)

    if [ -z "$SITES" ]; then
        error_exit "No Checkmk sites found! Please create a site first."
    fi

    if [ "$SITE_COUNT" -gt 1 ]; then
        log_warning "Multiple sites found:"
        echo "$SITES"
        read -p "Enter the site name to upgrade: " SITE_NAME
    else
        SITE_NAME="$SITES"
    fi

    if [ -z "$SITE_NAME" ]; then
        error_exit "No site selected"
    fi

    log_success "Selected site: $SITE_NAME"
}

# Check current version
check_current_version() {
    log_info "Checking current Checkmk version..."

    CURRENT_VERSION=$(su - "$SITE_NAME" -c "omd version" 2>/dev/null | grep -oP 'OMD.*Version \K[0-9.p]+' || echo "unknown")

    if [[ "$CURRENT_VERSION" == "unknown" ]]; then
        error_exit "Could not detect current Checkmk version"
    fi

    log_success "Current version: $CURRENT_VERSION"

    if [[ "$CURRENT_VERSION" == "2.4."* ]]; then
        log_warning "Site is already running version $CURRENT_VERSION"
        read -p "Continue anyway? (y/N): " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            log_info "Upgrade cancelled by user"
            exit 0
        fi
    fi
}

# Create backup directory
create_backup_dir() {
    log_info "Creating backup directory..."
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    log_success "Backup directory: $BACKUP_DIR"
}

# Create pre-upgrade backup
create_backup() {
    log_info "Creating pre-upgrade backup for site: $SITE_NAME"
    log_warning "This may take several minutes depending on site size..."

    BACKUP_FILE="$BACKUP_DIR/pre-upgrade-${SITE_NAME}-$(date +%Y%m%d_%H%M%S).tar.gz"

    # Stop site
    log_info "Stopping site..."
    su - "$SITE_NAME" -c "omd stop" >> "$LOG_FILE" 2>&1 || error_exit "Failed to stop site"
    log_success "Site stopped"

    # Create backup
    log_info "Creating backup (this will take a few minutes)..."
    if omd backup "$SITE_NAME" "$BACKUP_FILE" >> "$LOG_FILE" 2>&1; then
        log_success "Backup created: $BACKUP_FILE"
        BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log_info "Backup size: $BACKUP_SIZE"
    else
        error_exit "Backup creation failed"
    fi

    # Restart site
    log_info "Restarting site..."
    su - "$SITE_NAME" -c "omd start" >> "$LOG_FILE" 2>&1 || log_warning "Site failed to restart (will retry after upgrade)"
    log_success "Site restarted"
}

# Check disk space
check_disk_space() {
    log_info "Checking available disk space..."

    AVAILABLE_SPACE=$(df /opt/omd | tail -1 | awk '{print $4}')
    REQUIRED_SPACE=5000000  # 5GB in KB

    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        log_warning "Low disk space detected!"
        log_warning "Available: $(df -h /opt/omd | tail -1 | awk '{print $4}')"
        read -p "Continue anyway? (y/N): " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
            error_exit "Upgrade cancelled due to low disk space"
        fi
    else
        log_success "Sufficient disk space available"
    fi
}

# Download Checkmk 2.4
download_checkmk() {
    log_info "Downloading Checkmk ${CHECKMK_VERSION}..."

    if [ -f "$DOWNLOAD_FILE" ]; then
        log_warning "Package already exists, skipping download"
        return 0
    fi

    if wget -O "$DOWNLOAD_FILE" "$DOWNLOAD_URL" >> "$LOG_FILE" 2>&1; then
        log_success "Download complete"
        PACKAGE_SIZE=$(du -h "$DOWNLOAD_FILE" | cut -f1)
        log_info "Package size: $PACKAGE_SIZE"
    else
        error_exit "Failed to download Checkmk package"
    fi
}

# Install Checkmk 2.4
install_checkmk() {
    log_info "Installing Checkmk ${CHECKMK_VERSION}..."

    # Check if already installed
    if omd versions | grep -q "$CHECKMK_VERSION"; then
        log_warning "Checkmk ${CHECKMK_VERSION} already installed"
        return 0
    fi

    if dpkg -i "$DOWNLOAD_FILE" >> "$LOG_FILE" 2>&1; then
        log_success "Checkmk ${CHECKMK_VERSION} installed"
    else
        log_warning "dpkg reported errors, attempting to fix dependencies..."
        apt-get install -f -y >> "$LOG_FILE" 2>&1 || error_exit "Failed to install Checkmk"
        log_success "Dependencies fixed, Checkmk installed"
    fi

    # Verify installation
    if omd versions | grep -q "$CHECKMK_VERSION"; then
        log_success "Verified: Checkmk ${CHECKMK_VERSION} is available"
    else
        error_exit "Checkmk ${CHECKMK_VERSION} installation verification failed"
    fi
}

# Perform the upgrade
perform_upgrade() {
    log_info "Starting upgrade process for site: $SITE_NAME"

    # Stop the site
    log_info "Stopping site..."
    su - "$SITE_NAME" -c "omd stop" >> "$LOG_FILE" 2>&1 || error_exit "Failed to stop site"
    log_success "Site stopped"

    # Perform upgrade with automatic conflict resolution
    log_info "Running 'omd update' (this may take several minutes)..."
    log_warning "Automatically installing new versions for config conflicts"

    # Use 'install' conflict resolution to automatically use new versions
    if omd -f -V "$CHECKMK_VERSION" update --conflict=install "$SITE_NAME" >> "$LOG_FILE" 2>&1; then
        log_success "Upgrade completed successfully"
    else
        error_exit "Upgrade failed! Check log file for details: $LOG_FILE"
    fi

    # Start the site
    log_info "Starting upgraded site..."
    if su - "$SITE_NAME" -c "omd start" >> "$LOG_FILE" 2>&1; then
        log_success "Site started successfully"
    else
        error_exit "Site failed to start after upgrade"
    fi
}

# Verify upgrade
verify_upgrade() {
    log_info "Verifying upgrade..."

    # Check version
    NEW_VERSION=$(su - "$SITE_NAME" -c "omd version" 2>/dev/null | grep -oP 'OMD.*Version \K[0-9.p]+' || echo "unknown")

    if [[ "$NEW_VERSION" == "$CHECKMK_VERSION"* ]]; then
        log_success "Version verified: $NEW_VERSION"
    else
        log_error "Version mismatch! Expected: $CHECKMK_VERSION, Got: $NEW_VERSION"
    fi

    # Check site status
    log_info "Checking site status..."
    SITE_STATUS=$(su - "$SITE_NAME" -c "omd status" 2>/dev/null)

    if echo "$SITE_STATUS" | grep -q "Overall state:.*running"; then
        log_success "All services are running"
    else
        log_warning "Some services may not be running properly"
        log_info "Site status:"
        echo "$SITE_STATUS" | tee -a "$LOG_FILE"
    fi
}

# Create post-upgrade backup
create_post_upgrade_backup() {
    log_info "Creating post-upgrade backup..."

    POST_BACKUP_FILE="$BACKUP_DIR/post-upgrade-${SITE_NAME}-$(date +%Y%m%d_%H%M%S).tar.gz"

    # Stop site
    su - "$SITE_NAME" -c "omd stop" >> "$LOG_FILE" 2>&1

    # Create backup
    if omd backup "$SITE_NAME" "$POST_BACKUP_FILE" >> "$LOG_FILE" 2>&1; then
        log_success "Post-upgrade backup created: $POST_BACKUP_FILE"
        POST_BACKUP_SIZE=$(du -h "$POST_BACKUP_FILE" | cut -f1)
        log_info "Backup size: $POST_BACKUP_SIZE"
    else
        log_warning "Post-upgrade backup failed (non-critical)"
    fi

    # Restart site
    su - "$SITE_NAME" -c "omd start" >> "$LOG_FILE" 2>&1
}

# Cleanup
cleanup() {
    log_info "Cleaning up..."

    if [ -f "$DOWNLOAD_FILE" ]; then
        rm -f "$DOWNLOAD_FILE"
        log_success "Removed downloaded package"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "=============================================="
    log_success "UPGRADE COMPLETED SUCCESSFULLY!"
    echo "=============================================="
    echo ""
    log_info "Upgrade Summary:"
    echo "  - Old version: $CURRENT_VERSION"
    echo "  - New version: $NEW_VERSION"
    echo "  - Site name: $SITE_NAME"
    echo "  - Backup location: $BACKUP_DIR"
    echo "  - Log file: $LOG_FILE"
    echo ""
    log_warning "IMPORTANT NEXT STEPS:"
    echo ""
    echo "1. Access your Checkmk web interface:"
    echo "   http://10.10.10.5/$SITE_NAME/"
    echo ""
    echo "2. Login and look for a RED notification in the Help menu"
    echo ""
    echo "3. Click it and ACKNOWLEDGE all 'incompatible Werks'"
    echo "   (This is required to complete the upgrade)"
    echo ""
    echo "4. Test your monitoring:"
    echo "   - Verify hosts are being monitored"
    echo "   - Check that notifications work"
    echo "   - Review dashboards and graphs"
    echo ""
    echo "5. If you need to migrate to another server:"
    echo "   - Use backup file: $POST_BACKUP_FILE"
    echo "   - Transfer to new server with: scp $POST_BACKUP_FILE root@<new-server>:/tmp/"
    echo "   - Restore with: omd restore /tmp/$(basename $POST_BACKUP_FILE)"
    echo ""
    log_info "Rollback instructions (if needed):"
    echo "   omd rm -f $SITE_NAME"
    echo "   omd restore $BACKUP_FILE"
    echo ""
    echo "=============================================="
}

# Main execution
main() {
    log_info "=== Checkmk Upgrade Script Started ==="
    log_info "Target version: $CHECKMK_VERSION"
    log_info "Log file: $LOG_FILE"
    echo ""

    check_root
    detect_site
    check_current_version

    echo ""
    log_warning "About to upgrade site '$SITE_NAME' from $CURRENT_VERSION to $CHECKMK_VERSION"
    read -p "Continue? (y/N): " CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        log_info "Upgrade cancelled by user"
        exit 0
    fi

    echo ""
    create_backup_dir
    check_disk_space
    create_backup
    download_checkmk
    install_checkmk
    perform_upgrade
    verify_upgrade
    create_post_upgrade_backup
    cleanup
    print_summary

    log_success "All done!"
}

# Run main function
main
