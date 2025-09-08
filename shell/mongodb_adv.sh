#!/bin/bash

# =====================================================
# MongoDB Setup Script - Version 3.0
# Author  : Roboshop Automation
# Purpose : Automates MongoDB installation & configuration
# =====================================================

# ---- Colours ----
RED='\e[0;31m'
GREEN='\e[0;32m'
YELLOW='\e[1;33m'
RESET='\e[0m'

# ---- Variables ----
LOG_DIR="/var/log/roboshop"
SCRIPT_NAME=$(basename "$0")
LOG_FILE="$LOG_DIR/$SCRIPT_NAME.log"
START_TIME=$(date '+%d-%m-%Y %H:%M:%S')

# ---- Functions ----

# Print header
print_header() {
    echo "====================================================" | tee -a "$LOG_FILE"
    echo " Script Name   : $SCRIPT_NAME" | tee -a "$LOG_FILE"
    echo " Execution Time: $START_TIME" | tee -a "$LOG_FILE"
    echo "====================================================" | tee -a "$LOG_FILE"
}

# Ensure log directory and file
init_logs() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    echo -e "${GREEN}INFO: Logging initialized at $LOG_FILE${RESET}"
}

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}ERROR: This script must be run as root.${RESET}" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Validate commands
validate() {
    local exit_code=$1
    local step=$2
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}ERROR: $step failed. Check log: $LOG_FILE${RESET}" | tee -a "$LOG_FILE"
        exit 1
    else
        echo -e "${GREEN}SUCCESS: $step completed.${RESET}" | tee -a "$LOG_FILE"
    fi
}

# Copy repo file
setup_repo() {
    echo "Copying MongoDB repo file..." | tee -a "$LOG_FILE"
    cp ~/mongodb.repo /etc/yum.repos.d/mongodb.repo &>> "$LOG_FILE"
    validate $? "Copy MongoDB repo file"
}

# Install MongoDB
install_mongo() {
    echo "Installing MongoDB server..." | tee -a "$LOG_FILE"
    dnf install -y mongodb-org &>> "$LOG_FILE"
    validate $? "MongoDB installation"
}

# Configure MongoDB
configure_mongo() {
    echo "Configuring MongoDB to listen on all interfaces..." | tee -a "$LOG_FILE"
    sed -i -e 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf &>> "$LOG_FILE"
    validate $? "Update mongod.conf"
}

# Start & Enable MongoDB
manage_service() {
    echo "Starting and enabling MongoDB service..." | tee -a "$LOG_FILE"
    systemctl enable --now mongod &>> "$LOG_FILE"
    validate $? "MongoDB service enable & start"
}

# Verify MongoDB
verify_mongo() {
    echo "Verifying MongoDB service and version..." | tee -a "$LOG_FILE"
    systemctl is-active --quiet mongod
    validate $? "MongoDB service status"
    
    mongod --version &>> "$LOG_FILE"
    validate $? "MongoDB version check"
}

# ---- Main Execution ----
main() {
    init_logs
    print_header
    check_root
    setup_repo
    install_mongo
    configure_mongo
    manage_service
    verify_mongo

    echo "====================================================" | tee -a "$LOG_FILE"
    echo -e "${GREEN}INFO: MongoDB setup completed successfully.${RESET}" | tee -a "$LOG_FILE"
    echo "Finished at: $(date '+%d-%m-%Y %H:%M:%S')" | tee -a "$LOG_FILE"
    echo "====================================================" | tee -a "$LOG_FILE"
}

main
