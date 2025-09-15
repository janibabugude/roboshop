# ----- Setup Dispatch server ----
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
# --------- Install golang ----------
log_info "Installing golang..." | tee -a "$LOG_FILE"
yum install golang -y &>> "$LOG_FILE"
validate $? "Install golang" | tee -a "$LOG_FILE"
# ----------- Add application user -----------  
id roboshop &>> "$LOG_FILE"
if [ $? -ne 0 ];then
    log_info "Adding application user roboshop..." | tee -a "$LOG_FILE"
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>> "$LOG_FILE"
    validate $? "Add application user roboshop" | tee -a "$LOG_FILE"
else
    log_warning "Application user roboshop already exists. Skipping user creation..." | tee -a "$LOG_FILE"
fi
# -------- Creating /app directory --------
log_info "Creating /app directory..." | tee -a "$LOG_FILE"
mkdir -p /app &>> "$LOG_FILE"
validate $? "Creating /app directory" | tee -a "$LOG_FILE"
# ----------- Downloading the application code ------------
log_info "Downloading the application code..." | tee -a "$LOG_FILE"
curl -L -o /tmp/dispatch.zip https://roboshop-artifacts.s3.amazonaws.com/dispatch-v3.zip &>> "$LOG_FILE"
validate $? "Downloading the application code" | tee -a "$LOG_FILE"
# ----------- Extracting the application code ------------
log_info "Extracting the application code..." | tee -a "$LOG_FILE"
cd /app || exit 1
rm -rf * &>> "$LOG_FILE"
unzip -o /tmp/dispatch.zip &>> "$LOG_FILE"
validate $? "Extracting the application code" | tee -a "$LOG_FILE"
# ----------- Downloading the dependencies ------------
log_info "Downloading the dependencies..." | tee -a "$LOG_FILE"
go mod init dispatch &>> "$LOG_FILE" 
go get &>> "$LOG_FILE"
go build &>> "$LOG_FILE"
validate $? "Downloading the dependencies" | tee -a "$LOG_FILE"
# ----------- copying dispatch systemd service ------------
log_info "Copying the dispatch service file..." | tee -a "$LOG_FILE"
cp dispatch.service /etc/systemd/system/dispatch.service &>> "$LOG_FILE"
validate $? "Copying the dispatch service file" | tee -a "$LOG_FILE"
# ----------- Starting the dispatch service ------------
log_info "Starting the dispatch service..." | tee -a "$LOG_FILE"
systemctl daemon-reload &>> "$LOG_FILE"
systemctl enable dispatch &>> "$LOG_FILE"
systemctl restart dispatch &>> "$LOG_FILE"
validate $? "Starting the dispatch service" | tee -a "$LOG_FILE"
# ----------- Script completed successfully ------------
log_success "Script execution completed successfully at $SCRIPT_DATE" | tee -a "$LOG_FILE"
echo "------------------  END  ------------------" | tee -a "$LOG_FILE"
echo