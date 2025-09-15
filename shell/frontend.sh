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
# ------ Disable,Enable 1.24,and Installing  nginx module ------
dnf module disable nginx -y &>> "$LOG_FILE"
validate $? "Disable current nginx module"
dnf module enable nginx:1.24 -y &>> "$LOG_FILE"
validate $? "Enable nginx 1.24 module"
dnf install nginx -y &>> "$LOG_FILE"
validate $? "Install nginx"
# ------  Enable and Start nginx service ------
systemctl enable nginx &>> "$LOG_FILE"
validate $? "Enable nginx service"
systemctl start nginx &>> "$LOG_FILE"
validate $? "Start nginx service"
# ------ Downloading and Extracting the Frontend content ------
rm -rf /usr/share/nginx/html/* &>> "$LOG_FILE"
validate $? "Remove old content"
curl -s -L -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip &>> "$LOG_FILE"
validate $? "Download Frontend content"
unzip -o /tmp/frontend.zip -d /usr/share/nginx/html/ &>> "$LOG_FILE"
validate $? "Extract Frontend content"
# ------ Updating the Roboshop Configuration ------
cp frontend.conf /etc/nginx/default.d/roboshop.conf &>> "$LOG_FILE"
validate $? "Update Roboshop Configuration"
# ------ Restart nginx service ------
systemctl restart nginx &>> "$LOG_FILE"
validate $? "Restart nginx service"  
# ------ Check the nginx service status ------
systemctl is-active --quiet nginx
validate $? "Nginx service status"  
# ------ Check the nginx version ------
nginx -v &>> "$LOG_FILE"
validate $? "Nginx version check"
# ------ Script completed successfully ------
log_success "Script execution completed successfully at $SCRIPT_DATE" | tee -a "$LOG_FILE"   
echo "------------------  END  ------------------" | tee -a "$LOG_FILE"
echo