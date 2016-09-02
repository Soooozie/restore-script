#restore-script 

This script was designed to help easily recreate a website. 
Designed for LAMP stack setup. 
Basic firewalld settings and basic mysql settings. 
Installs s3 to backup data from storage services that use s3. 
Installs wp-cli for easy wordpress management. 
Sets up automatic site backups and automatic wordpress updating with wp-cli via crontab. 
All variables in the script are called at the top of the script by sourcing the variables in a 
separate file which in this case is referred to as vars.sh but can be whatever you would like.

That's it folks!! 

