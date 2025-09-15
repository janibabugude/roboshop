# ----- Setup RabbitMQ server ----
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
# ----------- Copy repo file -----------
log_info " Copying RabbitMQ repofile..." | tee -a "$LOG_FILE"
cp rabbitmq.repo /etc/yum.repos.d/rabbitmq.repo &>> "$LOG_FILE"
validate $? "Copy RabbitMQ repo file" | tee -a "$LOG_FILE"
# ----------- Install RabbitMQ ------------
log_info "Installing RabbitMQ server..." | tee -a "$LOG_FILE"  
yum install rabbitmq-server -y &>> "$LOG_FILE"
validate $? "Installing RabbitMQ server" | tee -a "$LOG_FILE"
# ----------- Enable and Start RabbitMQ service ------------
log_info "Enabling and starting RabbitMQ service..." | tee -a "$LOG_FILE"
systemctl enable rabbitmq-server &>> "$LOG_FILE"
validate $? "Enable RabbitMQ service" | tee -a "$LOG_FILE"
systemctl start rabbitmq-server &>> "$LOG_FILE"
validate $? "Start RabbitMQ service" | tee -a "$LOG_FILE"
# ----------- Check RabbitMQ service status ------------
log_info "Checking RabbitMQ service status..." | tee -a "$LOG_FILE"
systemctl status rabbitmq-server &>> "$LOG_FILE"
validate $? "Check RabbitMQ service status" | tee -a "$LOG_FILE"
# ----------- Create application user ------------
log_info "Creating application user..." | tee -a "$LOG_FILE"
rabbitmqctl add_user roboshop Daws@84s &>> "$LOG_FILE"
validate $? "Create application user" | tee -a "$LOG_FILE"
# ----------- Set permission to application user ------------
log_info "Setting permission to application user..." | tee -a "$LOG_FILE"
rabbitmqctl set_permissions -p / roboshop ".*" ".*" ".*" &>> "$LOG_FILE"
validate $? "Set permission to application user" | tee -a "$LOG_FILE"
# ----------- Script completed successfully ------------
log_success "Script execution completed successfully at $SCRIPT_DATE" | tee -a "$LOG_FILE"
echo "------------------  END  ------------------" | tee -a "$LOG_FILE"
echo