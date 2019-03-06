#!/bin/bash

# This script will set up some files and changes some after the baseline is set.
# It is for demo purposes and will help with showing the features of BFIM.
# After the demo is done, the script will clean up the system and remove all files.
# More explanation is giving during the script as comments.

base_path="/var/bfim"

function logo () {
	echo "========================================================================="
	echo "              BFIM DEMO ~ BASH FOLDER INTEGRITY MONITOR DEMO             "
	echo "              created by n0w4n                                           "
	echo "========================================================================="
	echo ""
}

function phase1 () {
	echo "[-] This script will create a setting for demo purposes"
	echo "[-] So not really evil :)"
	echo "--------------------------------------------------------------------------"
	echo "[-] Creating some files..."
	touch /var/www/html/file1
	touch /var/www/html/file2
	touch /var/www/html/file4
	touch /var/www/html/file5
	touch /tmp/normalfile
	echo "--------------------------------------------------------------------------"
	echo "[-] Adding some legite strings to files..."
	echo "This file was all" > /var/www/html/file3
	echo "some normal text was here" > /var/www/html/file1
	echo "Some random string doing nothing" > /tmp/normalfile
	echo "--------------------------------------------------------------------------"
	echo "[-] Run BFIM and create a baseline..."
	echo "[-] By running this command all important files are copied"
	echo "    into a protected folder in case of tampering..."
	echo ""
	read -p "Press any to continue..."
	clear
	logo
	phase2
}

function phase2 () {
	echo "[-] Doing some evil things..."
	echo "[-] In this stage some files are tampered with..."
	echo "[-] Removing some information and replacing some information..."
	echo "This is an evil payload" >> /var/www/html/file3
	echo "This string is to kill the program" > /var/www/html/file1
	echo "Some more random strings added after the baseline" >> /tmp/normalfile
	echo "[-] Creating some evil files"
	for i in $(seq 1 10); do touch /var/www/html/evilfile$i.php; done
	echo "[-] Deleting some files"
	rm -f /var/www/html/file4
	rm -f /var/www/html/file5
	echo "--------------------------------------------------------------------------"
	echo "[-] Run BFIM and use --check flag..."
	echo "[-] By running this command there is a similar check as with the"
	echo "    baseline function, only now it compares the outcome with the"
	echo "    current baseline..."
	echo ""
	echo "[-] After the check is done it will give the result as output..."
	echo "[-] It will also present the option to put any suspicious file"
	echo "    into a quarantaine folder. When put into the ownership of the"
	echo "    files are stripped and the permissions will be set to 600..."
	echo ""
	read -p "Press any key to continue..."
	clear
	logo
	phase3
}

function phase3 () {
	echo "[-] Run BFIM and use --compare flag..."
	echo "[-] By runnig this command the modified files are checked against"
	echo "    the stored files in the clone folder..."
	echo "[-] If there are lines added or removed, the report will show"
	echo "    these changes..."
	echo ""
	read -p "Press any key to continue..."
	clear
	logo
	clean
}

function clean () {
	echo "[-] Cleaning up the demo settings..."
	echo "[-] This will clean up all the created files and will remove the"
	echo "    $base_path folder and all the files..."
	echo ""
	read -p "Press any key to continue..."
	rm -rf $base_path
	rm -f /var/www/html/file*
	rm -f /var/www/html/evilfile*
	rm -f /tmp/normalfile
	echo "--------------------------------------------------------------------------"
	echo "[-] And done..."
	echo ""
	exit 0
}

logo
phase1