# ----- Setup shipping server ----
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
# ----------- Install maven ------------
log_info "Installing maven..." | tee -a "$LOG_FILE"
yum install maven -y &>> "$LOG_FILE"
validate $? "Installing maven" | tee -a "$LOG_FILE"
# -------- Creating /app directory --------
log_info "Creating /app directory..." | tee -a "$LOG_FILE"
mkdir -p /app &>> "$LOG_FILE"
validate $? "Creating /app directory" | tee -a "$LOG_FILE"
# ----- Creating roboshop System_user -----
log_info "Creating roboshop system user..." | tee -a "$LOG_FILE"
id roboshop &>> "$LOG_FILE"
if [ $? -ne 0 ]; then
    useradd -r -d /app -s /sbin/nologin -c "Roboshop system_user" roboshop &>> "$LOG_FILE"
    validate $? "Creating roboshop system user" | tee -a "$LOG_FILE"
else
     log_warning "User roboshop already exists." | tee -a "$LOG_FILE"
fi    
# -------- Downloading the shipping code --------
log_info "Downloading the shipping code..." | tee -a "$LOG_FILE"
curl -s -L -o /tmp/shipping.zip "https://roboshop-artifacts.s3.amazonaws.com/shipping-v3.zip" &>> "$LOG_FILE"
validate $? "Downloading the shipping code  " | tee -a "$LOG_FILE"
# -------- Extracting the shipping code --------
log_info "Extracting the shipping code..." | tee -a "$LOG_FILE"
cd /app || exit 1
rm -rf * &>> "$LOG_FILE"
unzip -o /tmp/shipping.zip -d /app/ &>> "$LOG_FILE" 
validate $? "Extracting the shipping code" | tee -a "$LOG_FILE"
# -------- Installing the dependencies -------- 
log_info "Installing the dependencies..." | tee -a "$LOG_FILE"
mvn clean package &>> "$LOG_FILE"
validate $? "Installing the dependencies" | tee -a "$LOG_FILE"
mv target/shipping-1.0.jar shipping.jar &>> "$LOG_FILE"
validate $? "Renaming the shipping jar file" | tee -a "$LOG_FILE"
# -------- Copying the shipping systemd file --------
log_info "Copying the shipping systemd file..." | tee -a "$LOG_FILE"
cp shipping.service /etc/systemd/system/shipping.service &>> "$LOG_FILE"
validate $? "Copying the shipping systemd file" | tee -a "$LOG_FILE"
# -------- Starting the shipping service --------
log_info "Starting the shipping service..." | tee -a "$LOG_FILE"
systemctl daemon-reload &>> "$LOG_FILE"
systemctl enable shipping &>> "$LOG_FILE"
systemctl start shipping &>> "$LOG_FILE"
validate $? "Starting the shipping service" | tee -a "$LOG_FILE"
# -------- Verifying the shipping service --------
log_info "Verifying the shipping service..." | tee -a "$LOG_FILE"
systemctl is-active shipping &>> "$LOG_FILE"
validate $? "Verifying the shipping service" | tee -a "$LOG_FILE"
# -------- Installing the mysql client --------
log_info "Installing the mysql client..." | tee -a "$LOG_FILE"
yum install mysql -y &>> "$LOG_FILE"
validate $? "Installing the mysql client" | tee -a "$LOG_FILE"
# -------- Loading the shipping schema --------
log_info "Loading the schema..." | tee -a "$LOG_FILE"
mysql -h mysql.johndaws.shop -uroot -pDaws@84s < /app/db/schema.sql &>> "$LOG_FILE"
validate $? "Loading the schema" | tee -a "$LOG_FILE"
# -------- Creating app-user for shipping --------
log_info "Creating app-user for shipping..." | tee -a "$LOG_FILE"
mysql -h mysql.johndaws.shop -uroot -pDaws@84s < /app/db/app-user.sql &>> "$LOG_FILE"
validate $? "Creating app-user for shipping" | tee -a "$LOG_FILE"
# -------- Loading Master data for shipping --------
log_info "Loading Master data for shipping..." | tee -a "$LOG_FILE"
mysql -h mysql.johndaws.shop -uroot -pDaws@84s < /app/db/master-data.sql &>> "$LOG_FILE"
validate $? "Loading Master data for shipping" | tee -a "$LOG_FILE"
# ------ Restarting the shipping service ------
log_info "Restarting the shipping service..." | tee -a "$LOG_FILE"
systemctl restart shipping &>> "$LOG_FILE"
validate $? "Restarting the shipping service" | tee -a "$LOG_FILE"

# ----------- Script completed successfully ------------
log_success "Script execution completed successfully at $SCRIPT_DATE" | tee -a "$LOG_FILE"   
echo "------------------  END  ------------------" | tee -a "$LOG_FILE"
echo
