#!/bin/bash
# ------------- colours ------------
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
CYAN='\e[0;36m'
RESET='\e[0m'

log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_success() { echo -e "${GREEN}  ↳ $1${RESET}"; }
log_warning() { echo -e "${YELLOW}[SKIP]${RESET} $1"; }
log_error() { echo -e "${RED}[ERROR]${RESET} $1"; }
# ---------- variable configurations -----------
LOG_DIR="/var/log/roboshop"
SCRIPT_NAME=$(basename "$0" | sed -i "s/\.sh//")
LOG_FILE="$LOG_DIR/$SCRIPT_NAME.log"
SCRIPT_DATE=$(date '+%F %T')
# ---------- check logfile -----------
check_logfile(){
    if [ ! -f "$LOG_FILE" ];then
        touch $LOG_FILE
        log_success "Log file $LOG_FILE created successfully."
    else
        log_warning "Log file $LOG_FILE already exists."
    fi
}
# ---------- check the log directory and log file --------
check_dir(){
    if [ ! -d "$LOG_DIR" ]; then
        log_info "Log folder $LOG_DIR doesnot exist."
        mkdir -p $LOG_DIR
        log_success "Log folder $LOG_DIR created successfully."
        check_logfile
        
    else
        check_logfile
    fi
}
check_dir
# ---------- check root user ------------
check_root(){
    USER_ID=$(id -u)
    if [ "$USER_ID" -ne 0];then

        log_error "Please run the script with ROOT privilege ...." | tee -a "$LOG_FILE"
        script_failed=$(date '+%F %T')
        log_error "Script execution failed at $script_failed" | tee -a "$LOG_FILE"
        exit 1
    else
        log_success "Script is running with ROOT privilege..." | tee -a "$LOG_FILE"
    fi 
}
check_root
# ----------- validation check ---------------
validate(){
    local exit_code=$1
    local step=$2
    if [ "$exit_code" -ne 0 ];then
        script_failed=$(date '+%F %T')
        log_error "Script execution failed at $script_failed" | tee -a "$LOG_FILE"
        log_error "$step failed. Check log file: $LOG_FILE" | tee -a "$LOG_FILE"
        exit 1
    else
        log_success "$step completed successfully." | tee -a "$LOG_FILE"
    fi
}
# ---------- Disable and enable nodejs module ------------
dnf module disable nodejs -y &>> "$LOG_FILE"
validate $? "Disable current nodejs module"
dnf module enable nodejs:20 -y &>> "$LOG_FILE"
validate $? "Enable nodejs:20 module"
dnf install nodejs -y &>> "$LOG_FILE"
validate $? "Installing nodejs 20"
# -------- Creating /app directory --------
mkdir -p /app &>> "$LOG_FILE"
validate $? "Creating /app directory"
# ---------- Creating roboshop system_user ------------
useradd --system --home /app --shell /sbin/nologin --comment "Roboshop System_user" roboshop &>> "$LOG_FILE"
if [ $? -ne 0 ];then
    log_warning "User roboshop already exists." | tee -a "$LOG_FILE"
else
    validate $? "Creating roboshop system_user"
fi
# ---------- Downloading and extracting the cart component ------------
log_info "Downloading cart component"
curl -s -L -o /tmp/cart.zip "https://roboshop-artifacts.s3.amazonaws.com/cart-v3.zip" &>> "$LOG_FILE"
validate $? "Downloading cart component"
log_info "Extracting cart component"
cd /app || exit 1
rm -rf * &>> "$LOG_FILE"
unzip -o /tmp/cart.zip &>> "$LOG_FILE"
validate $? "Extracting cart component"
# ---------- Installing nodejs dependencies ------------
log_info "Installing nodejs dependencies"
cd /app || exit 1
npm install &>> "$LOG_FILE" 
validate $? "Installing nodejs dependencies"
# ---------- Copying the systemd file ------------
log_info "Copying the cart service file"
cp cart.service /etc/systemd/system/cart.service &>> "$LOG_FILE"
validate $? "Copying the cart service file"
# ---------- Starting the cart service ------------
log_info "Starting the cart service"
systemctl daemon-reload &>> "$LOG_FILE"
systemctl enable cart &>> "$LOG_FILE"
systemctl start cart &>> "$LOG_FILE" 
validate $? "Starting the cart service"
# ---------- Verifying the cart service ------------
systemctl is-active cart &>> "$LOG_FILE"
validate $? "Verifying the cart service"
# ---------- Script completed ------------
script_completed=$(date '+%F %T')
log_success "Script execution completed at $script_completed" | tee -a "$LOG_FILE" 
echo "------------------  END  ------------------" | tee -a "$LOG_FILE"
echo