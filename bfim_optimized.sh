#!/usr/bin/env bash

# Created by n0w4n

# This bash script enables basic file integrity monitoring
# It uses tree to create a baseline and than gives the possibility to verify the baseline
# If it finds a discrepancy, it will try to locate the change
# With this FIM it is possible to check the following events:
# 1.) If a folder is added, removed or altered
# 2.) If a file is added, removed or altered

# This is the path where all the needed files of FIM will be stored
# It is advicable to not use /root as this is a folder you will want to keep an eye for
# The path given will be excluded from the scans
base_path="/var/bfim"

function color () {
        # This part defines the colors in the output

        NORMAL="\e[0m"
        RED="\e[31m"
        GREEN="\e[33m"
}

function logo () {
        echo ""
        echo "==================================================================="
        echo "               BFIM ~ BASH FILE INTEGRITY MONITOR                  "
        echo "               created by n0w4n                                    "
        echo "==================================================================="
        echo ""
}

function dependancy () {
        # for this script to run properly, it needs the following commands:
        # tree, diff

        if ! hash tree 2>/dev/null
        then
                echo "[-] The program 'tree' is not in PATH!"
                read -p '[-] Do you want to install it (Y/n)? ' installtree
                if [[ ! -z $installtree ]]; then
                        if [[ ! $installtree =~ [YyNn] ]]; then
                                echo -e "[$RED!$NORMAL] That is not a valid option!"
                                dependancy
                        elif [[ $installtree =~ [Yy] ]]; then
                                sudo apt install tree -y
                        elif [[ $installtree =~ [Nn] ]]; then
                                echo -e "[$RED!$NORMAL] This program cannot run without the 'tree' program!!!"
                                echo "[-] Exiting"
                                echo ""
                                exit 0
                        fi
                else
                        sudo apt install tree -y
                fi
        fi

        if ! hash diff 2>/dev/null
        then
                echo "[-] The program 'diff' is not in PATH!"
                read -p '[-] Do you want to install it (Y/n)? ' installdiff
                if [[ ! -z $installdiff ]]; then        
                        if [[ ! $installdiff =~ [YyNn] ]]; then
                                echo -e "[$RED!$NORMAL] That is not a valid option!"
                                dependancy
                        elif [[ $installdiff =~ [Yy] ]]; then
                                sudo apt install diffutils -y
                        elif [[ $installdiff =~ [Nn] ]]; then
                                echo -e "[$RED!$NORMAL] This program cannot run without the 'diff' program!!!"
                                echo "[-] Exiting"
                                echo ""
                                exit 0
                        fi
                else
                        sudo apt install diffutils -y
                fi
        fi

        if ! hash ts 2>/dev/null
        then
                echo "[-] The program 'ts' is not in PATH!"
                read -p '[-] Do you want to install it (Y/n)? ' installmoreutils
                if [[ ! -z $installmoreutils ]]; then
                        if [[ ! $installmoreutils =~ [YyNn] ]]; then
                                echo -e "[$RED!$NORMAL] That is not a valid option!"
                                dependancy
                        elif [[ $installmoreutils =~ [Yy] ]]; then
                                sudo apt install moreutils -y
                        elif [[ $installmoreutils =~ [Nn] ]]; then
                                echo -e "[$RED!$NORMAL] This program cannot run without the 'ts' program!!!"
                                echo "[-] Exiting"
                                echo ""
                                exit 0
                        fi
                else
                        sudo apt install moreutils -y
                fi
        fi

        # This program should run as root so the files cannot be tempered by lower privileged users
        if [[ $EUID -ne 0 ]]; then 
                echo -e "[$RED!$NORMAL] Please run FIM as root!!!"
                  exit 0
        fi
}

function main () {
        # The help menu which gives the options for the program

        if [[ $# -eq 0 ]]; then
                echo -e "[$RED!$NORMAL] Don't run this program without an argument"
                echo -e "[$RED!$NORMAL] Option '--help' for help menu"
                echo ""
                exit 1
        else
                if [[ $1 == "-h" ]] || [[ $1 == "--help" ]]; then
                        echo "Options for FIM"
                        echo "---------------"
                        echo ""
                        echo "--help    Show this help menu"
                        echo "--create  Create a new baseline | the old baseline will be deleted"
                        echo "--check   Check if there are files added or removed"
                        echo "--clone   Clone the files and folders from the whitelist.list file"
                        echo "--compare Compare found suspicious files with cloned files"
                        echo "--backup  Create a backup of the current baseline"
                        echo "--restore Restore a backup baseline as current baseline"
                        echo ""
                elif [[ $1 == "--create" ]]; then
                        baseline
                elif [[ $1 == "--check" ]]; then
                        check
                elif [[ $1 == "--clone" ]]; then
                        clone
                elif [[ $1 == "--compare" ]]; then
                        compare
                elif [[ $1 == "--backup" ]]; then
                        backup
                elif [[ $1 == "--restore" ]]; then
                        restore
                fi
        fi
}

function folder_check () {
        # This program needs a list of folders to create a baseline and check the integrity of the file system

        # Create a folder to store the files in
        # This folder will always be excluded from the scans

        if [[ ! -d $base_path/ ]]; then
                mkdir -p $base_path/
                mkdir -p $base_path/tmp
                mkdir -p $base_path/clone
                mkdir -p $base_path/quarantaine
                mkdir -p $base_path/logs
                if [[ ! -f $base_path/logs/bfim.log ]]; then
                        touch $base_path/logs/bfim.log
                fi
                if [[ ! $? -eq 0 ]]; then
                        echo -e "[$RED!$NORMAL] Unable to create folder $base_path/!!!"
                        echo "-------------------------------------------------------------------"
                        echo "[-] Exiting"
                        echo ""
                        exit 0
                fi
                # Set permission to the folder for root only
                chmod 600 $base_path/
                chmod 600 $base_path/*
                chmod -R 600 $base_path/tmp
                chmod -R 400 $base_path/quarantaine
                chmod -R 400 $base_path/logs
        fi

        # In case of an intended or unintended removal of the list of folders, this part will recreate the file with the folders
        if [[ ! -f $base_path/folders.list ]]; then
                echo "/bin" > $base_path/folders.list
                echo "/sbin" >> $base_path/folders.list
                echo "/usr" >> $base_path/folders.list
                echo "/opt" >> $base_path/folders.list
                echo "/lib" >> $base_path/folders.list
                echo "/lib64" >> $base_path/folders.list
                echo "/etc" >> $base_path/folders.list
                echo "/root" >> $base_path/folders.list
                echo "/tmp" >> $base_path/folders.list
                # If the /home folder has an user which is used heavily, use grep -v <folder> to exclude it from check
                # Else it will generate a lot of false-positives
                ls -lah /home | grep drw | tail -n +3 | grep -v monitor | awk '{print "/home/"$9}' >> $base_path/folders.list
                # /var folder contains folders with rapidly changing files
                # If alteration is needed, adjust the grep -v <folder> command to exclude a folder from the search
                ls -lah /var | grep drw | grep -v log | grep -v bfim | grep -v lib | tail -n +3 | awk '{print "/var/"$9}' >> $base_path/folders.list
        fi

        # Creates the whitelist.list file
        # This file is used for targeting the files/folders which needs to be cloned
        if [[ ! -f $base_path/whitelist.list ]]; then
                echo "/var/www" > $base_path/whitelist.list
                echo "/etc" >> $base_path/whitelist.list
                echo "/usr/bin" >> $base_path/whitelist.list
                echo "/bin" >> $base_path/whitelist.list
                # Choosing which folder (user) to exclude from backup is possible with altering or adding the grep -v <folder> options
                ls -lah /home | grep drw | tail -n +3 | grep -v monitor | awk '{print "/home/"$9}' >> $base_path/whitelist.list
        fi
}

function baseline () {
        # This script will create a md5 checksum from the output of tree /
        # For this it needs a baseline

        # The /var folder contains a /log folder which needs to be excluded from the baseline
        # Because it will change rapidly and will be the reason that there will be many false-positives in the scan
        # This command will include all the folders from /var (except for /log) into the folders list

        # Runs function folder-check
        folder_check
        clone

        if [[ -f $base_path/baseline ]]; then
                echo -e "[$RED!$NORMAL] Baseline found!!!" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                read -p '[-] Create a new baseline (y/N)? ' newbaseline
                if [[ ! -z $newbaseline ]]; then
                        if [[ ! $newbaseline =~ [yYnN] ]]; then
                                echo -e "[$RED!$NORMAL] That is not a valid option!!!"
                                logo
                                main $1
                        elif [[ $newbaseline =~ [nN] ]]; then
                                echo "[-] Keeping baseline..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                echo "[-] Exiting" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                echo "" | tee -a $base_path/logs/bfim.log
                                exit 0
                        elif [[ $newbaseline =~ [yY] ]]; then
                                echo "[-] Creating a backup of the current baseline..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                # Better be save then sorry
                                time_baseline=`ls -l $base_path/baseline | tr '[:upper:]' '[:lower:]' | awk '{print $7"-"$6"-2019-"$8}' | sed 's/://'`
                                cp --preserve=all $base_path/baseline $base_path/baseline_$time_baseline
                                echo "[-] Removing the old baseline..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                rm -f $base_path/baseline
                                echo "[-] Creating a new baseline..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'

                                for ITEMS in $(cat $base_path/folders.list);
                                do
                                        tree -lfsugiF --dirsfirst --sort=name $ITEMS >> $base_path/baseline
                                done

                                # Tree will recursively run through folders
                                # This tree command will limit itself to the root folder without going to /proc/, /var/log/
                                # Because these folders will create false-positives
                                tree -lfsugiF --dirsfirst --sort=name -L 1 / >> $base_path/baseline

                                # Set permission for root only
                                chmod 600 $base_path/*

                                echo "[-] Baseline is created and stored in $base_path/baseline" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                clone
                        fi
                else
                        echo "[-] Keeping baseline..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "[-] Exiting" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "" | tee -a $base_path/logs/bfim.log
                        exit 0
                fi
        else
                echo "[-] Creating a baseline..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'

                for ITEMS in $(cat $base_path/folders.list);
                do
                        tree -lfsugiF --dirsfirst --sort=name $ITEMS >> $base_path/baseline
                done

                # Tree will recursively run through folders
                # This tree command will limit itself to the root folder without going to /proc/, /var/log/
                # Because these folders will create false-positives
                tree -lfsugiF --dirsfirst --sort=name -L 1 / >> $base_path/baseline

                # Set permission for root only
                chmod 600 $base_path/*

                echo "[-] Baseline is created and stored in $base_path/baseline" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "[-] Exiting" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "" | tee -a $base_path/logs/bfim.log
        fi
}

function check () {
        # This script will create a md5 checksum of the entire filesystem
        # The folders var and proc will be excluded

        # Runs function folder-check
        folder_check

        rm -f $base_path/check

        echo "[-] Checking for baseline..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'

        if [[ ! -f $base_path/baseline ]]; then
                echo -e "[$RED!$NORMAL] No baseline detected!!!" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "[-] Create a baseline first (fim -b)..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "[-] Exiting" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "" | tee -a $base_path/logs/bfim.log
                exit 0
        else
                echo "[-] Baseline found..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "[-] Creating a checksum for verification..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'

                for ITEMS in $(cat $base_path/folders.list);
                do
                        tree -lfsugiF --dirsfirst --sort=name $ITEMS >> $base_path/check
                done

                # Tree will recursively run through folders by default
                # This tree command will limit itself to the root folder without going to /proc/, /var/log/
                # Because these folders will create false-positives
                tree -lfsugiF --dirsfirst --sort=name -L 1 / >> $base_path/check

                # Set permission for root only
                chmod 600 $base_path/*

                # Creates variables with the md5 checksums of the tree output in memory
                hash_baseline=`md5sum $base_path/baseline | awk '{print $1}'`
                hash_check=`md5sum $base_path/check | awk '{print $1}'`

                # This part is comparing the checksum from the baseline with the checksum from the check
                # If it does not match it will give as output the file(s) and/or folder(s) that create a mismatch
                if [[ ! $hash_baseline == $hash_check ]]; then
                        echo -e "[$RED!$NORMAL] Suspicious activity is detected!!!" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        identification-files
                else
                        echo "[-] The checksums are identical..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "[-] No suspicious activity is detected!" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "[-] Exiting" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "" | tee -a $base_path/logs/bfim.log
                fi
        fi
}

function identification-files () {
        # This part will check for changes between the baseline and the check
        # It will show all its findings in a small report

        # Runs function folder-check
        folder_check

        # Remove earlier created tmp files
        rm -f $base_path/tmp/*.tmp

        echo "[-] Trying to find the suspicious activity..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
        echo "" | tee -a $base_path/logs/bfim.log

        # Variable to set suspicious flag
        suspicious_flag=0

        # List all found files
        file_names_tmp=`diff $base_path/baseline $base_path/check | grep -v '^[0-9]' | grep -v directory | grep -v directories | rev | grep -v '^\/' | rev | sed 's/</Result_baseline/' | sed 's/>/Result_check/' | sed 's/\[//' | sed 's/\]//' | column -t | uniq | grep -v '^\-\-\-' | awk '{print $5}' | sort | uniq`

        # List only the unique files (added or removed)
        file_names_uniq=`diff $base_path/baseline $base_path/check | grep -v '^[0-9]' | grep -v directory | grep -v directories | rev | grep -v '^\/' | rev | sed 's/</Result_baseline/' | sed 's/>/Result_check/' | sed 's/\[//' | sed 's/\]//' | column -t | uniq | grep -v '^\-\-\-' | awk '{print $5}' | sort | uniq -u`

        # List the modified files
        file_names_notuniq=`diff $base_path/baseline $base_path/check | grep -v '^[0-9]' | grep -v directory | grep -v directories | rev | grep -v '^\/' | rev | sed 's/</Result_baseline/' | sed 's/>/Result_check/' | sed 's/\[//' | sed 's/\]//' | column -t | uniq | grep -v '^\-\-\-' | awk '{print $5}' | sort | uniq -d`

        # Set counter for number of modified files
        if [[ ! -z $file_names_notuniq ]]; then
                modified_count=`echo "$file_names_notuniq" | grep -c '^'`

                # Report for modified files
                if [[ $modified_count -eq 1 ]]; then
                        if [[ ! -z $file_names_notuniq ]]; then
                                echo "[-] File modified on the system:" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                for i in $file_names_notuniq;
                                do
                                        echo "    > $i" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                done
                                echo "" | tee -a $base_path/logs/bfim.log
                        fi
                else
                        if [[ ! -z $file_names_notuniq ]]; then
                                echo "[-] Files modified on the system:" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                for i in $file_names_notuniq;
                                do
                                        echo "    > $i" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                done
                                echo "" | tee -a $base_path/logs/bfim.log
                        fi
                fi
        else
                echo "[-] No files modified on the system..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo ""
        fi

        # Check for files removed from the system
        if [[ ! -z $file_names_uniq ]]; then
                for FILES in $file_names_uniq;
                do
                        cat $base_path/baseline | grep -F $FILES | awk '{print $4}' >> $base_path/tmp/file_removed.tmp
                done

                file_removed=`cat $base_path/tmp/file_removed.tmp`

                # Set counter for number of found files
                if [[ ! -z $file_removed ]]; then
                        removed_count=`echo "$file_removed" | grep -c '^'`

                        # Report for removed files
                        if [[ $removed_count -eq 1 ]]; then
                                if [[ ! -z $file_removed ]]; then
                                        echo "[-] File removed from the system:" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        for i in $file_removed;
                                        do
                                                echo "    > $i" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        done
                                        echo "" | tee -a $base_path/logs/bfim.log
                                fi
                        else
                                if [[ ! -z $file_removed ]]; then
                                        echo "[-] Files removed from the system:" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        for i in $file_removed;
                                        do
                                                echo "    > $i" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        done
                                        echo "" | tee -a $base_path/logs/bfim.log
                                fi
                        fi
                else
                        echo "[-] No files removed from the system..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "" | tee -a $base_path/logs/bfim.log
                fi
        else
                echo "[-] No files removed from the system..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "" | tee -a $base_path/logs/bfim.log
        fi

        if [[ ! -z $file_names_uniq ]]; then

                # Check for files added to the system
                for FILES in $file_names_uniq;
                do
                        cat $base_path/check | grep -F $FILES | awk '{print $4}' >> $base_path/tmp/file_added.tmp
                done

                file_added=`cat $base_path/tmp/file_added.tmp`

                # Set counter for number of found files
                if [[ ! -z $file_added ]]; then
                        added_count=`echo "$file_added" | grep -c '^'`

                        # Set suspicious_flag to 1
                        suspicious_flag=1

                        # Report for added files
                        if [[ $added_count -eq 1 ]]; then
                                if [[ ! -z $file_added ]]; then
                                        echo "[-] Suspicious file added to the system:" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        for i in $file_added;
                                        do
                                                echo "    > $i" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        done
                                fi
                        else
                                if [[ ! -z $file_added ]]; then
                                        echo "[-] Suspicious files added to the system:" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        for i in $file_added;
                                        do
                                                echo "    > $i" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        done
                                fi
                        fi
                else
                        echo "[-] No files added to the system..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                fi
        else
                echo "[-] No files added to the system..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
        fi

        # Change permission on tmp folder (and files)
        chmod -R 600 $base_path/tmp

        # Check suspicious_flag is 1
        if [[ $suspicious_flag -eq 1 ]]; then
                echo "-------------------------------------------------------------------"
                read -p '[-] Move the suspicious files to quarantaine folder (Y/n)? ' questionquarantaine

                if [[ ! -z $questionquarantaine ]]; then
                        if [[ ! $questionquarantaine =~ [YyNn] ]]; then
                                echo -e "[$RED!$NORMAL] That is not a valid option!!!"
                                sleep 3
                                clear
                                logo
                                identification-files
                        else
                                if [[ $questionquarantaine =~ [Yy] ]]; then
                                        echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "[-] Choose method of moving files..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "" | tee -a $base_path/logs/bfim.log
                                        echo "[1] Move all the files at once" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "[2] Choose which file needs to be moved" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo ""
                                        read -p '[-] Choose option 1 or 2: ' questionoption
                                        if [[ ! $questionoption =~ [12] ]]; then
                                                echo -e "[$RED!$NORMAL] That is not a valid option!!!" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                                sleep 2
                                                clear
                                                logo
                                                identification-files
                                        else
                                                if [[ $questionoption == 1 ]]; then
                                                        batch-quarantaine
                                                else
                                                        quarantaine
                                                fi
                                        fi
                                fi
                        fi
                else
                        echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "[-] Choose method of moving files..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "" | tee -a $base_path/logs/bfim.log
                        echo "[1] Move all the files at once" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "[2] Choose which file needs to be moved" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo ""
                        read -p '[-] Choose option 1 or 2: ' questionoption
                        if [[ ! $questionoption =~ [12] ]]; then
                                echo -e "[$RED!$NORMAL] That is not a valid option!!!" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                sleep 2
                                clear
                                logo
                                identification-files
                        else
                                if [[ $questionoption == 1 ]]; then
                                        batch-quarantaine
                                else
                                        quarantaine
                                fi
                        fi
                fi
                echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "[-] Exiting" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "" | tee -a $base_path/logs/bfim.log
                exit 0
        else
                echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "[-] Exiting" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "" | tee -a $base_path/logs/bfim.log
                exit 0
        fi
}

function backup () {
        # This part will create a backup of the current baseline for reverting the baseline

        # Runs function folder-check
        folder_check

        echo "[-] Checking for a baseline..."

        # Check is there is a current baseline
        if [[ -f $base_path/baseline ]]; then
                echo "[-] Baseline found..."
                echo "-------------------------------------------------------------------"
                echo "[-] Making a backup of the current baseline..."
                time_baseline=`ls -l $base_path/baseline | tr '[:upper:]' '[:lower:]' | awk '{print $7"-"$6"-2019-"$8}' | sed 's/://'`
                cp --preserve=all $base_path/baseline $base_path/baseline_$time_baseline
                echo "[-] Backup of current baseline = $base_path/baseline_$time_baseline"
                echo "-------------------------------------------------------------------"
                echo "[-] Exiting"
                echo ""
        else
                echo -e "[$RED!$NORMAL] There is no current baseline found!!!"
                echo "-------------------------------------------------------------------"
                echo "[-] Exiting"
                echo ""
        fi
}

function clone () {
        # This part creates a copy of all the files which this script is monitoring
        # The purpose of this past is for a Blueteam challenge where the system is targeted
        # and the blueteam needs to see what is changed and why.

        # Whitelist for copying files and folders
        whitelist=`cat $base_path/whitelist.list`

        echo "[-] Copying all files from the whitelist into $base_path/clone..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
        echo ""

        for FILES in $whitelist;
        do
                rsync -arRpXogt --info=progress2 $FILES $base_path/clone
        done

        echo "-------------------------------------------------------------------"
}

function compare () {
        # This part will compare any found files that was modified
        # And compares it with a copied version in the clone folder

        folder_check

        # Variable to set modify flag to zero
        modifyFlag=0

        if [[ ! -d $base_path/clone ]]; then
                echo "[!] No copied files found to compare!!!"
                echo "-------------------------------------------------------------------"
                echo "[-] Exiting"
                exit 0
        else
                # List the modified files
                file_names_modified=`diff $base_path/baseline $base_path/check | grep -v '^[0-9]' | grep -v directory | grep -v directories | rev | grep -v '^\/' | rev | sed 's/</Result_baseline/' | sed 's/>/Result_check/' | sed 's/\[//' | sed 's/\]//' | column -t | uniq | grep -v '^\-\-\-' | awk '{print $5}' | sort | uniq -d`

                if [[ ! -z $file_names_modified ]]; then
                        echo "[-] Changes were made to the following file..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "" | tee -a $base_path/logs/bfim.log
                        # compare files with diff (change command to parse output more efficient)
                        for FILES in $file_names_modified;
                        do
                                if [[ ! -f $base_path/clone$FILES ]]; then
                                        echo "$FILES" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "There is no backup file to compare $FILES with" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "" | tee -a $base_path/logs/bfim.log
                                else
                                        echo "$FILES" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        difference=`diff "$base_path/clone$FILES" "$FILES" | grep -v '^[0-9]' | sed 's/</This line was removed:/' | sed 's/>/This line was added:/' 2>/dev/null`
                                        echo "$difference" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "" | tee -a $base_path/logs/bfim.log
                                fi
                        done
                else
                        echo -e "[$RED!$NORMAL] No files to compare!!!" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                fi
        fi

        # Check if there are modified files
        if [[ ! -z $file_names_modified ]]; then
                # Ask if modified files needs to be restored from the /clone folder
                echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                read -p "[-] Restore the integrity of the modified files (Y/n)? " questionrestore
                if [[ ! -z $questionrestore ]]; then
                        if [[ ! $questionrestore =~ [yYnN] ]]; then
                                echo -e "[$RED!$NORMAL] That is not a valid option!!!"
                                sleep 2
                                clear 
                                logo
                                compare
                        else
                                if [[ $questionrestore =~ [yY] ]]; then
                                        echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "" | tee -a $base_path/logs/bfim.log
                                        restore-files
                                else
                                        echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "[-] Exiting" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "" | tee -a $base_path/logs/bfim.log
                                        exit
                                fi
                        fi
                else
                        echo "-------------------------------------------------------------------" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "" | tee -a $base_path/logs/bfim.log
                        restore-files
                fi
        else
                echo "-------------------------------------------------------------------"
                echo "[-] Exiting" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "" | tee -a $base_path/logs/bfim.log
        fi
}

function restore () {
        # This part will ask for an input (name of a backup file of the baseline)
        # Given input will be restored as current baseline

        # Runs function folder-check
        folder_check

        echo "[-] Checking for a backup file of a baseline..."

        backup_check=`ls -lah $base_path/ | grep 'baseline_[0-9]' | awk '{print $9}'`

        # Check is there is a current baseline
        if [[ ! -z $backup_check ]]; then
                echo "[-] Backup file of a baseline found..."
                echo "-------------------------------------------------------------------"
                echo "[-] Listing all the backup files..."
                echo ""
                # Creates a numbered list of all the baseline files to restore
                ls -lah $base_path/ | grep 'baseline_[0-9]' | awk '{print $9}' | awk '{print NR".)", $0}'
                echo ""
                # Asks for a number as input
                read -p '[-] Give number of file to restore: ' restorefile
                # Variable to set range of number of backups
                range=`ls -lah $base_path/ | grep 'baseline_[0-9]' | awk '{print $9}' | awk '{print NR".)", $0}' | cut -d "." -f1`
                if [[ ! $restorefile =~ [$range] ]]; then
                        echo -e "[$RED!$NORMAL] That is not a valid number!!!"
                        echo "[-] Please give the number of the file to restore..."
                        sleep 2
                        clear
                        logo
                        restore
                else
                        # Parses output of command into variable
                        restorefile1=`ls -lah $base_path | grep 'baseline_[0-9]' | awk '{print $9}' | awk '{print NR".)", $0}' | egrep "^$restorefile" | awk '{print $2}'`
                        # Copy chosen backup file to new baseline file
                        cp --preserve=all $base_path/$restorefile1 $base_path/baseline
                        if [[ $? -eq 0 ]]; then
                                echo "-------------------------------------------------------------------"
                                echo "[-] Restoring $restorefile1 as new baseline..."
                                echo "[-] Baseline is restored..."
                                echo "-------------------------------------------------------------------"
                                echo "[-] Exiting"
                                echo ""
                        else
                                echo -e "[$RED!$NORMAL] That is not a valid file name!!!"
                                echo "-------------------------------------------------------------------"
                                echo "[-] Exiting"
                                echo ""
                                sleep 2
                                clear
                                logo
                                restore
                        fi
                fi
        else
                echo -e "[$RED!$NORMAL] No backup file was found!!!"
                echo "-------------------------------------------------------------------"
                echo "[-] Exiting"
                echo ""
        fi
}

function batch-quarantaine () {
        # This part will put all found files that are added after baseline in quarantaine folder
        # It also changes ownership of the file

        folder_check

        # Set var to contain all found files that have been added
        #s_files=`diff $base_path/baseline $base_path/check | grep -v /$ | grep -v '^[0-9]' | grep -v '\-\-\-' | grep -v directory | grep -v directories | sed 's/</Result_baseline/' | sed 's/>/Result_check/' | sed 's/\[//' | sed 's/\]//' | column -t | awk '{print $5}' | uniq`

        echo "[-] Placing suspicious files in quarantaine..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
        echo "[-] Changing ownership of files..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
        echo "[-] Changing permissions of files..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'

        # Moving suspicious files to quarantaine folder
        for FILES in $file_added;
        do
                mv $FILES $base_path/quarantaine 2>/dev/null
        done

        # Changing ownership
        chown -R root:root $base_path/quarantaine/
        # Changing permissions
        chmod -R 400 $base_path/quarantaine/

        echo "-------------------------------------------------------------------"
        echo "[-] Exiting" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
        echo "" | tee -a $base_path/logs/bfim.log
        exit 0        
}

function quarantaine () {
        # This part will put all found files that are added after baseline in quarantaine folder
        # It also changes ownership of the file

        folder_check

        echo "[-] Choose which file to move..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
        echo "" | tee -a $base_path/logs/bfim.log

        for FILES in $file_added;
        do
                read -p "$FILES <-- move (Y/n)? " movequestion
                if [[ ! -z $movequestion ]]; then
                        if [[ ! $movequestion =~ [YyNn] ]]; then
                                echo "[!] That is not a valid option!!!" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                sleep 2
                                clear
                                logo
                                quarantaine
                        else
                                # Moving suspicious files to quarantaine folder
                                if [[ $movequestion =~ [Yy] ]]; then
                                        mv $FILES $base_path/quarantaine 2>/dev/null
                                        echo "[-] Placing $FILES in quarantaine..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "" | tee -a $base_path/logs/bfim.log
                                else
                                        echo "[-] Skipping $FILES..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "" | tee -a $base_path/logs/bfim.log
                                fi
                        fi
                else
                        mv $FILES $base_path/quarantaine 2>/dev/null
                        echo "[-] Placing $FILES in quarantaine..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                        echo "" | tee -a $base_path/logs/bfim.log
                fi
        done

        # Changing ownership
        chown -R root:root $base_path/quarantaine/
        # Changing permissions
        chmod -R 400 $base_path/quarantaine/

        echo "-------------------------------------------------------------------"
        echo "[-] Exiting" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
        echo "" | tee -a $base_path/logs/bfim.log
        exit 0        
}

function restore-files () {
        # This part is to restore modified files and replace them with the copied versions in the /clone folder
        # If there is no copy then the files are opted to be removed

        folder_check

        # Update the locate database to include the copied files in the /clone folder
        updatedb

        # Create variable with list of modified files
        file_names_modified=`diff $base_path/baseline $base_path/check | grep -v '^[0-9]' | grep -v directory | grep -v directories | rev | grep -v '^\/' | rev | sed 's/</Result_baseline/' | sed 's/>/Result_check/' | sed 's/\[//' | sed 's/\]//' | column -t | uniq | grep -v '^\-\-\-' | awk '{print $5}' | sort | uniq -d`

        if [[ -z $file_names_modified ]]; then
                echo "[!] No copied files found to restore!!!" | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "-------------------------------------------------------------------" | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                echo "[-] Exiting" | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                exit 0
        else
                for FILES in $file_names_modified;
                do
                        read -p "$FILES <-- restore (Y/n)? " restorequestion

                        if [[ ! -z $restorequestion ]]; then
                                if [[ ! $restorequestion =~ [YyNn] ]]; then
                                        echo "[!] That is not a valid option!!!" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        sleep 2
                                        clear
                                        logo
                                        restore-files
                                else
                                        if [[ $restorequestion =~ [yY] ]]; then
                                                if [[ ! -f $base_path/clone/$FILES ]]; then
                                                        echo "[-] There is no copied version of $FILES to restore..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                                        echo "" | tee -a $base_path/logs/bfim.log
                                                else
                                                        cp --preserve=all $base_path/clone/$FILES $FILES
                                                        echo "[-] Restoring the integrity of $FILES..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                                        echo "" | tee -a $base_path/logs/bfim.log
                                                fi
                                        else
                                                echo "[-] Skipping $FILES..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                                echo "" | tee -a $base_path/logs/bfim.log 
                                        fi
                                fi
                        else
                                if [[ ! -f $base_path/clone/$FILES ]]; then
                                        echo "[-] There is no copied version of $FILES to restore..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "" | tee -a $base_path/logs/bfim.log
                                else
                                        cp --preserve=all $base_path/clone/$FILES $FILES
                                        echo "[-] Restoring the integrity of $FILES..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
                                        echo "" | tee -a $base_path/logs/bfim.log
                                fi
                        fi
                done
        fi

        echo "-------------------------------------------------------------------" | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
        echo "[-] Files are restored..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'
        echo "[-] Creating new checkfile..." | ts '[%Y-%m-%d %H:%M:%S]' | tee -a $base_path/logs/bfim.log | cut -d "]" -f2- | sed 's/^ //'

        # Create a new checkfile because the initial files have been restored
        # If not it will give false positives
        rm -f $base_path/check

        for ITEMS in $(cat $base_path/folders.list);
        do
                tree -lfsugiF --dirsfirst --sort=name $ITEMS >> $base_path/check
        done

        # Tree will recursively run through folders by default
        # This tree command will limit itself to the root folder without going to /proc/, /var/log/
        # Because these folders will create false-positives
        tree -lfsugiF --dirsfirst --sort=name -L 1 / >> $base_path/check

        # Set permission for root only
        chmod 600 $base_path/*

        echo "-------------------------------------------------------------------" | tee -a $base_path/logs/bfim.log
        echo "[-] Exiting" | tee -a $base_path/logs/bfim.log
}

clear
color
logo
dependancy
main $1