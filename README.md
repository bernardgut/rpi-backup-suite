# rs-backup-suite

rs-backup-suite is a set of shell scripts for setting up a custom NAS on a computer in the network. It uses [rsync](http://rsync.samba.org/) and [rsnapshot](http://www.rsnapshot.org/).

## How it works
rs-backup-suite is designed for push backups, which means the client pushes its files to the server. This is ideal for computers which are not always on such as most desktop PCs.

It is also a user-centric backup system. That means each user creates his own backup on the NAS instead of root backing up the whole machine at once (although this is possible). That also means that each user has a UNIX account on the NAS. The NAS username is usually `<hostname>-<local user name>` (e.g. `mymachine-johndoe`).

On the client machine(s) each user can create a file called `.rs-backup-include` (name is configurable) inside his home directory which includes the list of files that should be considered by the backup. Additionally root can maintain a similar file located at `/usr/local/etc/rs-backup/include-files` for the system files.

## Setup (please read this carefully before performing any actions!)
rs-backup-suite is split into two parts: a client part for pushing the backup to the NAS and a server part which runs on the NAS itself.

### Server
For the server part simply copy the contents of the `server` directory to your root directory and all the necessary files will be in place. Make sure that you copy the file permissions as well! Furthermore make sure that `/usr/local/bin` and `/usr/local/sbin` are in your `$PATH` environment variable as root. Finally rename the file `/usr/local/etc/server-config.example` to `/usr/local/etc/server-config`.

#### Tweaking the configuration file
The configuration file is `/usr/local/etc/server-config`. There you can configure the following directives:

* `BACKUP_ROOT`: The directory under which the home directories of the backup users are stored. The default is `/bkp`
* `FILES_DIR`: The directory under which the actual backups are kept (relative to the backup user's home directory). The default is `files`.
* `SET_QUOTA`: Whether to set disk quota for the users or not (for Ext3/4 file systems). Default is `false`.
* `QUOTA_SOFT_LIMIT`, `QUOTA_HARD_LIMIT`, `QUOTA_INODE_SOFT_LIMIT`, `QUOTA_INODE_HARD_LIMIT`: The individual limits for disk quota. Ignored, if `SET_QUOTA` is `false`.

**WARNING:** Adjust these settings *before* you create backup users, because they won't be re-applied for already existing users!

#### Adding a backup user
A backup user is an unprivileged UNIX account on the server. Normally each user on each client has one corresponding backup user which he uses to log into the NAS. A backup user can be created by running

    rs-add-user hostname username [ssh-public-key-file]

on the server where `hostname` is the name of the client host and `username` is the name of the user on that machine for whom this account is made. Of course you can use any other names for `hostname` and `username` as well, but it's generally a good idea to stick to this naming convention. The resulting UNIX username will be the combination of both.

**TIP:** You need `realpath` command for this script to be successfull. This command is non-standard in the current BASH. If you don't have it, get it with your current package manager. i.e. `apt-get install realpath`

The optional third parameter specifies the path to the SSH public key file which the user will use to log into the NAS. If you don't specify it, the user won't be able to log in at all. But you can add one later at any time by running

    rs-add-ssh-key hostname username ssh-public-key-file

`hostname` and `username` are the same as above and mandatory for identifying the user that should get the new key.

**TIP:** If you don't remember the parameters for all these commands, simply run them without any and you'll get simple usage instructions.

#### Making the chroot work
rs-backup-suite can chroot backup users into the backup home base directory. For this to work you need to add a few folders to your `/bkp` directory:
    
    mkdir -p "/bkp/"{"bin","lib","usr/bin","usr/lib","usr/local/bin","/usr/share/perl5","dev"}
    
Then also add the following to your `/etc/fstab` and run `mount -a` afterwards:

    # Chroot
    /bin                    /bkp/bin                none    bind             0       0
    /lib                    /bkp/lib                none    bind             0       0
    /usr/bin                /bkp/usr/bin            none    bind             0       0
    /usr/lib                /bkp/usr/lib            none    bind             0       0
    /usr/local/bin          /bkp/usr/local/bin      none    bind             0       0
    /usr/share/perl5        /bkp/usr/share/perl5    none    bind             0       0
    /dev                    /bkp/dev                none    bind             0       0

**NOTE:** In Ubuntu the Perl modules are located at `/usr/share/perl` instead of `/usr/share/perl5`. Change that accordingly when adding the directories to `/bkp` and creating the mount points.

On a 64-bit system you may need to add this to your `/etc/fstab`:

    /lib64                  /bkp/lib64              none    bind             0       0

Then add this to the end of your `/etc/ssh/sshd_config`:
    
    Match Group backup 
        ChrootDirectory /bkp/

and restart OpenSSH. Your backup users are now chrooted into `/bkp`.

**NOTE:** When using a chroot environment and you change anything in your user configuration (e.g. the username) you need to run `rs-update-passwd` or your user might not be able to log in anymore.

#### Changing the rotation options/backup levels
To change how many increments of which level are kept, edit the file `/bkp/etc/rsnapshot.global.conf`. This is the global configuration file for rsnapshot which will be included in each user-specific configuration. There you can tweak the names and numbers for all backup levels.

If you add or remove any backup levels, make sure you also update the cron scripts. By default three cron scripts are installed: `/etc/cron.daily/rs-backup-rotate`, `/etc/cron.weekly/rs-backup-rotate` and `/etc/cron.monthly/rs-backup-rotate`.

### Client
To set up the client you simply need to copy the contents of the `client` directory to your root folder on the client machines (again make sure you copy the file permissions, too). Then rename the file `/usr/local/etc/rs-backup/client-config.example` to `/usr/local/etc/rs-backup/client-config`. Finally edit it as root and replace the value of `REMOTE_HOST` with the hostname or IP address of your NAS.

On the client machines the script `/usr/local/bin/rs-backup-run` is used for performing the backups. This script can either be run as root or as an unprivileged user. The behavior differs in both cases:

* If run as root, all files and folder specified in `/usr/local/etc/rs-backup/include-files` will be backed up. The backup user used for logging into the NAS is `hostname-root` by default (where `hostname` is the hostname of the current machine). Additionally the home directories of all users will be scanned. If a home directory contains a file called `.rs-backup-include` all files and folders specified inside that file will be backed up under this user's privileges. The username used for logging into the NAS is `hostname-username` (where `hostname` is again substituted for the hostname of the current machine and `username` for the user whose home directory is being backed up).
* If run as a normal user, only the files that are specified in your own `.rs-backup-include` will be backed up.

#### Changing the default configuration
As you already know, all the client configuration options are defined in `/usr/local/etc/rs-backup/client-config`. You can edit the file as you wish. All parameters are documented clearly by comments. Most of these configuration options can also be overridden at runtime by passing command line arguments to `rs-backup-run`. For a list and a description of all possible command line arguments run

    rs-backup-run --help

## Backup strategies
The intended use case for rs-backup-suite is as follows: you set up the server part on your NAS. Then you create a backup user for each user on each client machine.

In the next step you edit the crontab for root on each client and add a job for running `/usr/local/bin/rs-backup-run` at certain times. You can of course also create a shell script that calls `rs-backup-run` and put it in `/etc/cron.daily` to perform a global backup once a day.

After everything is set up that way you create the file `/usr/local/etc/rs-backup/include-file` and write to it a list of files and folders you want to back up as root (e.g. you can specify `/etc/***` to backup the whole `/etc` directory and all its subdirectories). Furthermore each user creates a file called `.rs-backup-include` inside his home directory that serves the same purpose for his own home directory instead of the global system. Such a file could look like this:

    - /home/johndoe/.cache/***
    /home
    /home/johndoe/***

Lines that start with a `-` are treated as excludes, all other lines as includes. The three asterisks mean “Include this directory and everything below”. For more information about these globbing patterns read the FILTER RULES section of the rsync(1) man page.

**NOTE:** To include a directory you need to mark all parent directories for inclusion, too. For instance to include `/home/johndoe` you also need to include `/home` as shown above. But don't confuse `/home` with `/home/`! `/home` without the trailing slash only selects the (empty) directory itself, not its contents.

## Restoring files from the NAS
To restore files from the NAS server simply run:

    rsync -a -e ssh backupuser@remotehost::pull/source/path /destination/path

Replace `backupuser` with the proper backup user (e.g. `mymachine-johndoe`) and `remotehost` with the hostname of the NAS. `/source/path` is the file name on the remote side (e.g. `/daily.2/home/johndoe/foobar`) and `/destination/path` is the local destination file name.

You can also log into the NAS using SFTP or SSHFS. This is probably more convenient for browsing available files.

Be aware that both access methods are strictly read-only! Write access is only granted via rsync through the `push` module:

    rsync -a -e ssh backupuser@remotehost::push/destination/path /source/path

## Side note
Because rs-backup-suite uses rsync for the client-server communication you don't necessarily need both parts. As long as you have a working rsync server on your NAS you can use the client script to push files to it. On the other hand you can use the rs-backup-suite server part with any other rsync client, as well.
