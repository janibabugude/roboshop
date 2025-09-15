# ----- Setup Payment server ----
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
# ----------- install python3 gcc python3-devel -----------
log_info "Installing python3, gcc and python3-devel packages..." | tee -a "$LOG_FILE"
yum install python3 gcc python3-devel -y &>> "$LOG_FILE"
validate $? "Install python3, gcc and python3-devel packages" | tee -a "$LOG_FILE"
# ----------- add application user ------------
id roboshop &>> "$LOG_FILE"
if [ $? -ne 0 ];then
    log_info "Adding application user roboshop..." | tee -a "$LOG_FILE"
    useradd --system --home /app --shell /sbin/nologin --comment "Roboshop System_user" roboshop &>> "$LOG_FILE"
    validate $? "Add application user roboshop" | tee -a "$LOG_FILE"
else
    log_warning "User roboshop already exists. Skipping user creation..." | tee -a "$LOG_FILE"
fi
# ----------- create application directory ------------
log_info "Creating application directory /app..." | tee -a "$LOG_FILE"
mkdir -p /app &>> "$LOG_FILE"
validate $? "Create application directory /app" | tee -a "$LOG_FILE"
# ----------- download application content ------------
log_info "Downloading application content..." | tee -a "$LOG_FILE"
curl -s -L -o /tmp/payment.zip https://roboshop-artifacts.s3.amazonaws.com/payment-v3.zip &>> "$LOG_FILE"
validate $? "Download application content" | tee -a "$LOG_FILE"
# ----------- extract application content ------------
log_info "Extracting application content..." | tee -a "$LOG_FILE"
rm -rf /app/* &>> "$LOG_FILE"
validate $? "Remove old application content" | tee -a "$LOG_FILE"
cd /app || exit 1
unzip -o /tmp/payment.zip &>> "$LOG_FILE"
validate $? "Extract application content" | tee -a "$LOG_FILE"
# ----------- install python dependencies ------------
log_info "Installing python dependencies..." | tee -a "$LOG_FILE"
pip3 install -r requirements.txt &>> "$LOG_FILE"
validate $? "Install python dependencies" | tee -a "$LOG_FILE"
# ----------- Copying payment systemd service file -----------
log_info "Copying payment systemd service file..." | tee -a "$LOG_FILE"
cp payment.service /etc/systemd/system/payment.service &>> "$LOG_FILE"
validate $? "Copy payment systemd service file" | tee -a "$LOG_FILE"
# ----------- Start payment service ------------
log_info "Starting payment service..." | tee -a "$LOG_FILE"
systemctl daemon-reload &>> "$LOG_FILE"
systemctl enable payment &>> "$LOG_FILE"
systemctl restart payment &>> "$LOG_FILE"
validate $? "Start payment service" | tee -a "$LOG_FILE"
# ----------- Script completed successfully ------------
log_success "Script execution completed successfully at $SCRIPT_DATE" | tee -a "$LOG_FILE"   
echo "------------------  END  ------------------" | tee -a "$LOG_FILE"
echo