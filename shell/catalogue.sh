# --------------- Setup Catalogue server -------------------
#!/bin/bash

# ------------- COLOURS ------------
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RESET='\e[0m'

# ---------- Variable configurations -----------
LOG_DIR="/var/log/roboshop"
SCRIPT_NAME=$(basename "$0" | sed 's/\.sh//' )
LOG_FILE="$LOG_DIR/$SCRIPT_NAME.log"
SCRIPT_DATE=$(date '+%F %T')

# ---------- Check the Log directory and Log file --------
check_dir() {
    echo
    if [ ! -d "$LOG_DIR" ];then
        echo -e "${RED}ERROR: Log folder $LOG_DIR doesnot exist.${RESET}"
        mkdir -p $LOG_DIR
        echo -e "${GREEN}SUCCESS: Log folder $LOG_DIR created successfully.${RESET}"
        touch $LOG_FILE
        echo -e "${GREEN}SUCCESS: Log file $LOG_FILE created successfully.${RESET}"

    else
        echo -e "${YELLOW}SKIP: Log folder $LOG_DIR already exists.${RESET}"
        if [ ! -f "$LOG_FILE" ];then
            echo -e "${RED}ERROR: Log file $LOG_FILE doesnot exist.${RESET}"
            touch $LOG_FILE
            echo -e "${GREEN}SUCCESS: Log file $LOG_FILE created successfully.${RESET}"
        else
            echo -e "${YELLOW}SKIP: Log file $LOG_FILE already exists.${RESET}"
        fi
    fi       
}
check_dir
# ---------- Check ROOT privilege ------------
check_root(){
    USER_ID=$(id -u)
    if [ "$USER_ID" -ne 0 ];then
        echo -e "${RED}ERROR: Please run the script with only ROOT privilege....${RESET}" | tee -a "$LOG_FILE"
        exit 1
    else
        echo -e "${GREEN}INFO: This script is runned by ROOT privilege...${RESET}" | tee -a "$LOG_FILE"
    fi
}
check_root
# ----------- Validation Check ---------------
validate(){
    echo
    echo "=================================================================================="
    SCRIPT_DATE=$(date '+%F %T')
    if [ $1 -ne 0 ];then
        echo -e "${RED}ERROR: $2 is Failed. Please check the log file:\
         ${LOG_FILE} for more information.${RESET}" | tee -a "$LOG_FILE"
        echo -e "${RED}INFO: Script execution failed at ${RESET} ${SCRIPT_DATE}" | tee -a "$LOG_FILE"
        exit 1
    else
        echo -e "${GREEN}SUCCESS: $2 completed successfully.${RESET}" | tee -a "$LOG_FILE"
    fi 
}
# -------- Main process start here --------
# -------- Disable Current nodejs module --------
echo "Disable Current nodejs module" | tee -a "$LOG_FILE"
dnf module disable nodejs -y &>> "$LOG_FILE"
validate $? "Disable Current nodejs module" | tee -a "$LOG_FILE"
# -------- Enable nodejs:20 module ------------
echo "Enable nodejs:20 module" | tee -a "$LOG_FILE"
dnf module enable nodejs:20 -y &>> "$LOG_FILE"
validate $? "Enable nodejs:20 module" | tee -a "$LOG_FILE"
# -------- Installing nodejs module -----------
echo "Installing nodejs module" | tee -a "$LOG_FILE"
dnf module install nodejs -y &>> "$LOG_FILE"
validate $? "Installing nodejs module" | tee -a "$LOG_FILE"
# --------- Creating one dedicated directory -------------
echo "Creating /app directory" | tee -a "$LOG_FILE"
mkdir -p "/app" &>> "$LOG_FILE"
validate $? "Creating /app directory" | tee -a "$LOG_FILE"
# --------- Creating one SYSTEM USER --------------------
echo "Creating roboshop as SYSTEM_USER" | tee -a "$LOG_FILE"
useradd --system --home /app --shell /sbin/nologin --comment "roboshop as SYSTEM_USER" roboshop &>> "$LOG_FILE"
validate $? "Creating roboshop as SYSTEM_USER" | tee -a "$LOG_FILE"
# -------- Download the application code to /app directory --------
echo "Download the application code" | tee -a "$LOG_FILE"
curl -o /tmp/catalogue.zip https://roboshop-artifacts.s3.amazonaws.com/catalogue-v3.zip &>> "$LOG_FILE"
validate $? "Download the application code into /tmp" | tee -a "$LOG_FILE"
#cd /app &>> "$LOG_FILE"
# ------- Unzip the application code to /app directory ---------
echo "Unzip the application code to /app directory" | tee -a "$LOG_FILE"
unzip /tmp/catalogue.zip -d /app &>> "$LOG_FILE"
validate $? "Unzip the application code to /app directory" | tee -a "$LOG_FILE"
# -------- Download the dependencies ------------
echo "Download the dependencies" | tee -a "$LOG_FILE"
cd /app &>> "$LOG_FILE"
npm install &>> "$LOG_FILE"
validate $? "Download npm dependencies" | tee -a "$LOG_FILE"
# -------- Copying the catalogue.service into /etc/systemd/system/catalogue.service --------
echo "Copying the catalogue.service file into /etc/systemd/system/catalogue.service" | tee -a "$LOG_FILE"
cp catalogue.service /etc/systemd/system/catalogue.service &>> "$LOG_FILE"
validate $? "Copying the catalogue.service file into /etc/systemd/system/catalogue.service" | tee -a "$LOG_FILE"
# -------- Start the daemon-reload service -------
systemctl daemon-reload &>> "$LOG_FILE"
validate $? "Start the daemon-reload service" | tee -a "$LOG_FILE"
# ------- Enable and Start the catalogue service ------
echo "Enable and Start the catalogue service" | tee -a "$LOG_FILE"
systemctl start catalogue &>> "$LOG_FILE"
validate $? "Start catalogue service" | tee -a "$LOG_FILE"
systemctl enable catalogue &>> "$LOG_FILE"
validate $? "Enable catalogue service" | tee -a "$LOG_FILE"

# ---- copy mongodb.repo file into /etc/yum.repos.d/mongodb.repo ----
echo "Copying mongodb.repo into /etc/yum.repos.d/mongodb.repo " | tee -a "$LOG_FILE"
cp mongodb.repo /etc/yum.repos.d/mongodb.repo &>> "$LOG_FILE"
validate $? "Copying mongodb.repo into /etc/yum.repos.d/mongodb.repo" | tee -a "$LOG_FILE"
# ------ Installing mongodb-client from mongodb.repo ------
echo "Installing mongodb-mongosh from mongodb.repo" | tee -a "$LOG_FILE"
dnf install mongodb-mongosh -y &>> "$LOG_FILE"
validate $? "Installing mongodb-mongosh from mongodb.repo" | tee -a "$LOG_FILE"
# ------ Load Master Data of Products into MongoDB server --------
echo "Load Master Data of Products into MongoDB server" | tee -a "$LOG_FILE"
mongosh --host mongodb.johndaws.shop </app/db/master-data.js &>> "$LOG_FILE"
validate $? "Load Master Data of Products into MongoDB server" | tee -a "$LOG_FILE"
# -------- check data is loaded into mongodb or not ----------
echo "check data is loaded into mongodb or not" | tee -a "$LOG_FILE"
mongosh --host mongodb.johndaws.shop <<EOF &>> "$LOG_FILE"
show dbs
use catalogue
show collections
db.products.find().pretty()
EOF
validate $? "check data is loaded into mongodb or not" | tee -a "$LOG_FILE"

echo "=================================== THE END ===================================="
echo "Script completed successfully at: $(date '+%d-%m-%Y %H:%M:%S')" | tee -a "$LOG_FILE" 
echo -e "${GREEN}INFO: MongoDB setup completed successfully. ${RESET}" | tee -a "$LOG_FILE"
echo "=================================== THE END ===================================="
