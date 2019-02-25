#!/bin/bash

echo "//#####################\\"
echo "||                     ||"
echo "|| CERBERUS DEMO SETUP ||"
echo "||                     ||"
echo "\\#####################//"
echo ""
echo "[-] This script will create a setting for demo purposes"
echo "[-] So not really evil :)"
echo "-----------------------------------------------------------------"
echo "[-] Creating some files..."
touch file1
touch file2
touch file4
touch file5
echo "-----------------------------------------------------------------"
echo "[-] Adding some legite strings to files..."
echo "This file was all" > file3
echo "some normal text was here" > file1
echo "-----------------------------------------------------------------"
echo "[-] Run FIM and create a baseline..."
echo "[-] By running this command all important files are copied"
echo "    into a protected folder in case of tampering..."
echo ""
read -p "Press any to continue..."
echo "-----------------------------------------------------------------"
echo "[-] Doing some evil things..."
echo "[-] In this stage there some files are tampered with..."
echo "[-] Removing some information and replacing some information..."
echo "This is an evil payload" >> file3
echo "This string is to kill the program" > file1
echo "[-] Creating some evil files"
for i in $(seq 1 10); do touch evilfile$i.php; done
echo "[-] Deleting some files"
rm -f file4
rm -f file5
echo "-----------------------------------------------------------------"
echo "[-] Run FIM and use --check flag..."
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
echo "-----------------------------------------------------------------"
echo "[-] Run FIM and use --compare flag..."
echo "[-] By runnig this command the modified files are checked against"
echo "    the stored files in the clone folder..."
echo "[-] If there are lines added or removed, the report will show"
echo "    these changes..."
echo ""
read -p "Press any key to continue..."
echo "-----------------------------------------------------------------"
echo "[-] Cleaning up the demo settings..."
echo "[-] This will clean up all the created files and will remove the"
echo "    /var/fim folder and all the files..."
echo ""
read -p "Press any key to continue..."
rm -rf /var/fim
rm -f file*
rm -f evilfile*
echo "-----------------------------------------------------------------"
echo "[-] And done..."
echo ""
