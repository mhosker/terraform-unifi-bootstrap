#!/bin/bash

# ---------------------------------------------------------
# Update / Upgrade
# ---------------------------------------------------------

echo "Updating / Upgrading..."
sudo apt-get update
sudo apt-get upgrade -y

# ---------------------------------------------------------
# Change Hostname
# ---------------------------------------------------------

echo "Changing hostname..."
hostname "${server_name}-${env_name}"
echo "${server_name}-${env_name}" > /etc/hostname

# ---------------------------------------------------------
# Install Prerequisites
# ---------------------------------------------------------

echo "Installing prerequisites..."
sudo apt-get install ca-certificates apt-transport-https awscli jq -y

# ---------------------------------------------------------
# Install MongoDB
# ---------------------------------------------------------

echo "Installing MongoDB ${mongo_version}..."

# https://www.mongodb.com/download-center/community/releases

# Install libssl1 as required for MongoDB
sudo wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
sudo apt-get install -f ./libssl1.1_1.1.1f-1ubuntu2_amd64.deb -y

# Loop through Ubuntu distros that are used in MongoDB download URLs
# Note the order of newest first... so we only install the version for the newest distro.
for distro in jammy focal bionic xenial trusty precise
do
    # Test wget for version on distro
    # Continue to next distro if 404
    sudo wget -q https://repo.mongodb.org/apt/ubuntu/dists/$distro/mongodb-org/$( echo ${mongo_version} | sed "s/\.[^.]*$//")/multiverse/binary-amd64/mongodb-org-server_${mongo_version}_amd64.deb 2>&1 || continue

    # Will only reach this point if wget above was sucessful
    # So... if it was sucessful then we install the MongoDB .deb that wget downloaded
    sudo apt-get install -f ./mongodb-org-server_${mongo_version}_amd64.deb -y
    sudo systemctl enable mongod
    # And break as we dont need to test any more distros...
    break
done

# ---------------------------------------------------------
# Install UniFi
# ---------------------------------------------------------

echo "Installing UniFi ${unifi_version}..."

# Install requested version of UniFi
sudo wget https://dl.ui.com/unifi/${unifi_version}/unifi_sysvinit_all.deb
sudo apt-get install -f ./unifi_sysvinit_all.deb -y

# ---------------------------------------------------------
# Restore UniFi
# ---------------------------------------------------------

echo "Restoring UniFi..."

# Copy backup files from S3 to tmp location
sudo aws s3 sync s3://${bucket_name}/backups/ /tmp/unifi/backups/

# Get the latest backup file - we will use this to restore from...

# Set as zero - this is used later for greater than numeric comparison
newestbackup[1]=0

# Merge the two UniFi backup .json files into one - autobackup and manual backups
cat /tmp/unifi/backups/meta.json /tmp/unifi/backups/autobackup/autobackup_meta.json > /tmp/unifi/allbackups.json

# Loop through each backup - format in loop of backupname=backupdatetime
for backup in $(jq -r 'keys[] as $k | "\($k)=\(.[$k] | .datetime)"' /tmp/unifi/allbackups.json)
do
    # Split the backup name / datetime into an array [0] / [1]
    backup=($${backup//=/ })

    # Convert backup time to UNIX epoch
    backup[1]=$(date --date=$${backup[1]} +"%s")

    # Check if current backup UNIX time is greater than or equal to the current newest backup UNIX time
    if [ $${backup[1]} -ge $${newestbackup[1]} ]
    then
        # If the current backup is newer then we set it as the newest backup
        newestbackup[0]=$${backup[0]}
        newestbackup[1]=$${backup[1]}
    fi
done

# Check if file DOES NOT end in .unf
if ! [[ $${newestbackup[0]} == *.unf ]]
then
    # If it does not... add .unf
    newestbackup[0]="$${newestbackup[0]}.unf"
fi

# Upload backup file to UniFi
# NOTE: The "X-Requested-With: XMLHttpRequest" is really important!
# We use jq to parse the JSON and grab the backup ID we will use next to perform the restore
backup_id=$(curl https://127.0.0.1:8443/upload/backup --form file=@$(find /tmp/unifi/backups/ -type f -name "$${newestbackup[0]}") --header "Content-Type: multipart/form-data" --header "X-Requested-With: XMLHttpRequest" --insecure | jq -r '.meta.backup_id')

# Restore backup
curl https://127.0.0.1:8443/api/cmd/backup --request POST --header "Content-Type: application/json" --data "{\"cmd\":\"restore\",\"backup_id\":\"$${backup_id}\"}" --insecure

# Copy ALL backups to UniFi
cp -r /tmp/unifi/backups/* /var/lib/unifi/backup/

# Remove UniFi tmp folder
rm -r /tmp/unifi

# Set file owner properly for UniFi backups
# This is (very!!) important to allow new backups to write to meta.json & autobackup_meta.json files
sudo chown -R unifi:unifi /var/lib/unifi/backup/

# ---------------------------------------------------------
# Configure UniFi
# ---------------------------------------------------------

echo "Configuring UniFi..."

# Set guest portal https / http ports
# NOTE: Must be over 1024 as UniFi does not run as root so cannot bind to priveleged ports (<1024)
sed -i "/^portal.https.port=/d" /var/lib/unifi/system.properties # Remove existing https port
echo "portal.https.port=${portal_https_port}" >> /var/lib/unifi/system.properties # Add https port
sed -i "/^portal.http.port=/d" /var/lib/unifi/system.properties # Remove existing http port
echo "portal.http.port=${portal_http_port}" >> /var/lib/unifi/system.properties # Add http port

# ---------------------------------------------------------
# UniFi Sync
# ---------------------------------------------------------

echo "Configuring UniFi Sync..."

# Create a script to sync the UniFi backup folder to an S3 bucket
echo "#!/bin/sh
while true
do
    sudo aws s3 sync /var/lib/unifi/backup s3://${bucket_name}/backups --only-show-errors --delete
    sleep 300 # Wait 5 mins
done" > /usr/local/bin/unifi-sync

# Make UniFi sync script executable
sudo chmod +x /usr/local/bin/unifi-sync

# Create systemd service for unifi-sync
echo "[Unit]
After=network.target

[Service]
ExecStart=/usr/local/bin/unifi-sync

[Install]
WantedBy=default.target" > /etc/systemd/system/unifi-sync.service

# Set required permissions for service
sudo chmod 664 /etc/systemd/system/unifi-sync.service

# Start the service
sudo systemctl daemon-reload
sudo systemctl enable unifi-sync

# ---------------------------------------------------------
# Start UniFi & UniFi Sync
# ---------------------------------------------------------

echo "Starting UniFi and syncing backups..."

# Start UniFi
sudo service unifi start

# Run UniFi sync script
unifi-sync