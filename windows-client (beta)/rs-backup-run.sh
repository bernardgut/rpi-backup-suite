#Cygwin Wrapper script. Necessary for output in cmd
#!/bin/sh
echo "Windows rs-suite backup script - Bernard Gutermann ©28.12.2013" 
echo "https://github.com/bernardgut/rs-backup-suite"

cd /cygdrive/c/Users/bny-dkp.bny-dkp-PC
./rs-backup-run -v -p 

#rsync --rsh="ssh" --archive --acls --chmod=ugo=rwX --delete --delete-excluded --include-from="/cygdrive/c/Users/bny-dkp.bny-dkp-PC/.rs-backup-include" --exclude="*" --dry-run --progress / echo ${a,,}
