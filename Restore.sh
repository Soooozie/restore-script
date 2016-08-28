#!/bin/bash

clear

source ./vars.sh

yum update -y

#install packages
yum install httpd \
            mariadb-server  \
            mariadb php \
            php-mysql \
            php-gd \
            python-dateutil -y

#start apache
systemctl start httpd.service

#set apache to start when server is booted
systemctl enable httpd.service

#start mariadb service
systemctl start mariadb

#set mariadb to start when server is booted
systemctl enable mariadb.service

###############################################################
#firewalld settings
#set firewall for apache on port 80
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --reload

#set firewall permissions for mariadb
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --add-port 3306/tcp --permanent

#reload firewall to apply changes
firewall-cmd --reload
###############################################################

#restart apache to apply changes
systemctl restart httpd.service

cd ~

#create .my.cnf for passwordless database login
echo "[client]" >> .my.cnf
echo "user = root" >> .my.cnf

#random password generation
RAND_PASS=$(date +%s | sha256sum | base64 | head -c 32)

#set mysql root password
mysqladmin -u root password "$RAND_PASS"

#place new password in .my.cnf for passwordless login
echo "password = $RAND_PASS" >> .my.cnf

#######################################################################
#automating mysql_secure_installation items
mysql -e "DROP USER ''@'localhost';"
mysql -e "DROP USER ''@'$(hostname)';"
mysql -e "DROP DATABASE test;"
mysql -e "FLUSH PRIVILEGES;"
######################################################################

#Install s3cmd for backups to dreamObjects
mkdir ~/bin
curl -O -L https://github.com/s3tools/s3cmd/archive/v1.6.1.tar.gz

#untar the file
tar xzf v1.6.1.tar.gz

#change into the directory that was created upon unzipping
cd s3cmd-1.6.1

#copy s3cmd and S3 directories into the bin folder initially created for s3cmd
cp -R s3cmd S3 ~/bin

cd ~

#add bin directory to your path so you can execute the script
echo "export PATH=$HOME/bin:$PATH" >> ~/.bashrc

#execute bash profile to take effect of changes
. ~/.bashrc


#######################################################################
#create the .s3cfg file and enter some information - assuming dreamobjects
echo "[default]" >> .s3cfg
echo "access_key = $ACCESS_KEY" >> .s3cfg
echo "secret_key = $SECRET_KEY" >> .s3cfg
echo "host_base = objects-us-west-1.dream.io" >> .s3cfg
echo "host_bucket = %(bucket)s.objects-us-west-1.dream.io" >> .s3cfg
echo "enable_multipart = True" >> .s3cfg
echo "multipart_chunk_size_mb = 15" >> .s3cfg
echo "use_https = True" >> .s3cfg
#########################################################################

#install wp-cli
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

#make file executable
chmod +x wp-cli.phar

#move the file to a folder so that you can execute it from anywhere
mv wp-cli.phar /usr/local/bin/wp

#Backup website using s3cmd
#wildcard to retrieve whatever object is in the bucket
s3cmd get $BUCKET_NAME/*.tar

#untar the file
tar xf *.tar

#untar and unzip backup.tgz
tar zxf *.tgz

#unzip db_backup.sql.gz
gunzip *.sql.gz

#create the database to import your files to
mysql -e "CREATE DATABASE $DATABASE_NAME;"

#import database backup into mysql
mysql $DATABASE_NAME < db_backup.sql

#mysql section - create database and user - set privileges for user
mysql -e "CREATE USER $USERNAME@'%' IDENTIFIED BY '$DATABASE_PASSWORD';"
mysql -e "GRANT ALL PRIVILEGES ON $DATABASE_NAME.* TO $USERNAME@'%' IDENTIFIED BY '$DATABASE_PASSWORD';"
mysql -e "FLUSH PRIVILEGES;"

#su backups
#cd ~

#####################################################################
#create backups file - refer to backup script for details
echo "TEMP_DIR=$(mktemp -d)" >> backup.sh
echo "DEST=$TEMP_DIR" >> backup.sh
echo "ARCHIVE_FILE="backup.tgz"" >> backup.sh
echo "tar -czf $DEST/$ARCHIVE_FILE $DOCROOT ${DB_CONFIG[*]} ${WEB_SERVER_CONFIG[*]}" >> backup.sh
echo "NOW=$(date +%s)" >> backup.sh
echo "FILENAME="db_backup"" >> backup.sh
echo "BACKUP_FOLDER="$DEST"" >> backup.sh
echo "FULLPATHBACKUPFILE="$BACKUP_FOLDER/$FILENAME"" >> backup.sh
echo "mysqldump $DATABASE_NAME | gzip > $BACKUP_FOLDER/$FILENAME.sql.gz" >> backup.sh
echo "cd $DEST" >> backup.sh
echo "tar -cf backup_complete_$NOW.tar $ARCHIVE_FILE $FILENAME.sql.gz" >> backup.sh
echo "rm $DEST/$ARCHIVE_FILE" >> backup.sh
echo "rm $DEST/$FILENAME.sql.gz" >> backup.sh
echo "cd ~" >> backup.sh
echo "s3cmd put $DEST/backup_complete_$NOW.tar $BUCKET_NAME" >> backup.sh
echo " rm -r $DEST" >> backup.sh
######################################################################

cp -rf $BACKUP_FROM_BUCKET_DOCROOT /var/www/
cp -rf $BACKUP_FROM_BUCKET_DB_CONFIG_1 /etc/
cp -rf $BACKUP_FROM_BUCKET_DB_CONFIG_2 /etc/
cp -rf $BACKUP_FROM_BUCKET_WSC_1 /etc/httpd/
cp -rf $BACKUP_FROM_BUCKET_WSC_2 /etc/httpd/
cp -rf $BACKUP_FROM_BUCKET_WSC_3 /etc/httpd/

systemctl restart httpd

#Automate backups
echo "*  12  *  *  fri root backup.sh" >> /etc/crontab


######################################################################
#create wp update file - see WP Update Script for details
echo "cd $WORDPRESS_LOCATION" >> wp-update.sh
echo "wp core update" >> wp-update.sh
echo "wp plugin update --all" >> wp-update.sh
######################################################################


#Automate wp updates
echo "*  0  *  *  * root wp-update.sh" >> /etc/crontab
