# --------------- Setup User server -------------------
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
    if [ ! -d "$LOG_DIR" ]; then
        echo -e "${RED}ERROR: Log folder $LOG_DIR does not exist.${RESET}"
        mkdir -p "$LOG_DIR"
        echo -e "${GREEN}SUCCESS: Log folder $LOG_DIR created successfully.${RESET}"
        touch "$LOG_FILE"
        echo -e "${GREEN}SUCCESS: Log file $LOG_FILE created successfully.${RESET}"
    else
        echo -e "${YELLOW}SKIP: Log folder $LOG_DIR already exists.${RESET}"
        if [ ! -f "$LOG_FILE" ]; then
            echo -e "${RED}ERROR: Log file $LOG_FILE does not exist.${RESET}"
            touch "$LOG_FILE"
            echo -e "${GREEN}SUCCESS: Log file $LOG_FILE created successfully.${RESET}"
        else
            echo -e "${YELLOW}SKIP: Log file $LOG_FILE already exists.${RESET}"
        fi
    fi
}
check_dir

# ---------- Check ROOT privilege ------------
check_root() {
    USER_ID=$(id -u)
    if [ "$USER_ID" -ne 0 ]; then
        echo -e "${RED}ERROR: Please run the script with ROOT privilege....${RESET}" | tee -a "$LOG_FILE"
        exit 1
    else
        echo -e "${GREEN}INFO: Script is running with ROOT privilege...${RESET}" | tee -a "$LOG_FILE"
    fi
}
check_root

# ----------- Validation Check ---------------
validate() {
    echo
    echo "=================================================================================="
    SCRIPT_DATE=$(date '+%F %T')
    if [ $1 -ne 0 ]; then
        echo -e "${RED}ERROR: $2 failed. Check log file: ${LOG_FILE}.${RESET}" | tee -a "$LOG_FILE"
        echo -e "${RED}INFO: Script execution failed at ${RESET} ${SCRIPT_DATE}" | tee -a "$LOG_FILE"
        exit 1
    else
        echo -e "${GREEN}SUCCESS: $2 completed successfully.${RESET}" | tee -a "$LOG_FILE"
    fi
}

# -------- Main process start here --------
echo "Disable Current nodejs module" | tee -a "$LOG_FILE"
dnf module disable nodejs -y &>> "$LOG_FILE"
validate $? "Disable Current nodejs module" | tee -a "$LOG_FILE"

echo "Enable nodejs:20 module" | tee -a "$LOG_FILE"
dnf module enable nodejs:20 -y &>> "$LOG_FILE"
validate $? "Enable nodejs:20 module" | tee -a "$LOG_FILE"

echo "Installing nodejs module" | tee -a "$LOG_FILE"
dnf module install nodejs -y &>> "$LOG_FILE"
validate $? "Installing nodejs module" | tee -a "$LOG_FILE"

echo "Creating /app directory" | tee -a "$LOG_FILE"
mkdir -p "/app" &>> "$LOG_FILE"
validate $? "Creating /app directory" | tee -a "$LOG_FILE"

echo "Creating roboshop as SYSTEM_USER" | tee -a "$LOG_FILE"
if id roboshop &>> "$LOG_FILE"; then
    echo -e "${YELLOW}SKIP: User roboshop already exists.${RESET}" | tee -a "$LOG_FILE"
else
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>> "$LOG_FILE"
    validate $? "Creating roboshop as SYSTEM_USER"  | tee -a "$LOG_FILE"
fi

echo "Download the application code" | tee -a "$LOG_FILE"
curl -L -o /tmp/user.zip https://roboshop-artifacts.s3.amazonaws.com/user-v3.zip &>> "$LOG_FILE"
validate $? "Download the application code" | tee -a "$LOG_FILE"

echo "Unzip the application code to /app directory" | tee -a "$LOG_FILE"
unzip -o /tmp/user.zip -d /app &>> "$LOG_FILE"
validate $? "Unzip the application code" | tee -a "$LOG_FILE"

echo "Download the dependencies" | tee -a "$LOG_FILE"
cd /app &>> "$LOG_FILE"
rm -rf node_modules &>> "$LOG_FILE"
npm install &>> "$LOG_FILE"
validate $? "Download npm dependencies" | tee -a "$LOG_FILE"

echo "Copying user.service file into systemd" | tee -a "$LOG_FILE"
cp user.service /etc/systemd/system/user.service &>> "$LOG_FILE"
validate $? "Copy user.service" | tee -a "$LOG_FILE"

systemctl daemon-reload &>> "$LOG_FILE"
systemctl enable --now user &>> "$LOG_FILE"
validate $? "Enable and Start user service" | tee -a "$LOG_FILE"


echo "=================================== THE END ===================================="
echo "Script completed successfully at: $(date '+%d-%m-%Y %H:%M:%S')" | tee -a "$LOG_FILE"
echo -e "${GREEN}INFO: User setup completed successfully.${RESET}" | tee -a "$LOG_FILE"
echo "=================================== THE END ===================================="
