# setup mongodb server

#!/bin/bash

# ---- Colours ----
red='\e[0;31m'
green='\e[0;32m'
yellow='\e[0;33m'
reset='\e[0m'
log_dir="/var/log/roboshop"
script_date=$(date '+%d-%m-%Y %H:%M:%S')
script_execution_date=$(date '+%d-%m-%Y %H:%M:%S')
script_name=$(basename "$0")
log_file="$log_dir/$script_name.log"

# ---- Create log directory ----
if [ ! -d "$log_dir" ];then
    mkdir -p $log_dir
    echo -e "${green}SUCCESS: Log directory $log_dir created successfully. ${reset}"
else
    echo -e "${yellow}SKIP: Log directory $log_dir already exists. ${resest}"
fi
# ---- Create log file ----
if [ ! -f "$log_file" ];then
    touch $log_file
    echo -e "${green}SUCCESS: Log file $log_file created successfully.${resert}"
else
    echo -e "${yellow}SKIP: Log file $log_file already exists.${reset}"
fi

echo "Script stated executing at: ${script_execution_date}" | tee -a "$log_file"

#---- Root user check ----
user_id=$(id -u)
if  [ "$user_id" -ne 0 ]; then
    echo -e "${red}ERROR: you must be root to run this script.${reset}" | tee -a "$log_file"
    exit 1
else 
    echo -e "${green}INFO: you are running with root user.${reset}" | tee -a "$log_file"
fi
# ---- validate function takesinput as exit status, what command they tried to install ----
validate(){
    if {[ $1 -ne 0]};then
        echo -e "${red}ERROR: $2 is failed. Please check the Logfile: $log_file for more information. ${reset}" | tee -a "$log_file"
        echo "Script execution failed at: $script_date" | tee -a "$log_file"
        exit 1
    else
        echo -e "${green}SUCCESS: $2 is completed successfully.${reset}" | tee -a "$log_file"
    fi
}

# ---- copy mongodb.repo file into /etc/yum.repos.d/mongodb.repo ----
echo -n "Copying mongodb.repo into /etc/yum.repos.d/mongodb.repo " | tee -a "${log_file}"
cp ~/mongodb.repo /etc/yum.repos.d/mongodb.repo &>> "${log_file}"
validate $? "Copying mongodb.repo into /etc/yum.repos.d/mongodb.repo"
# ---- Install mongodb ----
echo -n "Installing mongodb server " | tee -a "${log_file}"
dnf install mongodb-org -y &>> "${log_file}"
validate $? "Installing mongodb server"
# ---- Update Listen IP address in /etc/mongod.conf file ----
echo -n "Updating Listen IP address in /etc/mongod.conf file " | tee -a "${log_file}"
sed -i -e 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf &>> "${log_file}"
validate $? "Uodating Listen IP address in /etc/mongod.conf file"
# ---- start and enable mongodb service ----
echo -n "Starting and Enabling mongodb service " | tee -a "${log_file}"
systemctl start mongod &>> "${log_file}"
systemctl enable mongod &>> "${log_file}"
validate $? "Starting and Enabling mongodb service"
# ---- Check mongodb service status ----
echo -n "Checking mongodb service status " | tee -a "${log_file}"
systemctl status mongod &>> "${log_file}"
validate $? "Checking mongodb service status"
# ---- Print mongodb version ----
echo -n "Printing mongodb version " | tee -a "${log_file}"
mongod --version &>> "${log_file}"
validate $? "Printing mongodb version"

echo "Script completed successfully at: $(date '+%d-%m-%Y %H:%M:%S')" | tee -a "$log_file" 
echo -e "${green}INFO: MongoDB setup completed successfully. ${reset}" | tee -a "$log_file"




