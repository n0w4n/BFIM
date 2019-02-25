# BBFIM ~ Bash File Integrity Monitor

BFIM is created as part of an redteam/blueteam excercise.
Because there wasn't much information about given resources on the defending machines, 
I needed a BFIM that had almost no dependancies and was very lightweight.
BFIM can help with maintaining the integrity of your filesystem.
It is easy and fast to use and is flexible when adjusting is needed.

INSTALL
=======

There is no need for installing this program.
It only uses the tools available on the local system.
If the required tools are not available it will either give an error or 
offers to install the tool.

FUNCTIONS
=========

BFIM has the following functions:

--create
This will create a baseline of the files and folders, which are noted in the folders.list file.
This file needs to be adjusted if there is a need to add or remove folders.
If there is already a baseline set it will give a warning that it will remove the current
baseline and create a new one. 
As a safety precaution, it will create a backup of the current baseline before removing it.

--check
This will create a similar outcome as the baseline function.
The result of this check will be compared with the baseline.
Any kind of difference will be reported as files that are added, removed or modified.
The check function will also give the opportunity to put the added files into a quarantaine folder.
Here the files are stripped from their original ownership and permissions are changed to 400.

--clone
This function will create a folder with files and folders from the whitelist.list file.
In a later stage BFIM can compare these files with modified files found on the system.

--compare
This function will compare any modified file found with the original version of that file, 
which is cloned into the folder <fim folder>/clone.
The whitelist.list file is important for this function as it holds the folders needed to be cloned.
If this function tries to compare a found modified file and there is no original cloned file,
it will report that there is no cloned version found to compare with.

--backup
This function will create a backup of the current baseline.

--restore
This function will list all the backups of baselines and gives the choice which baseline backup needs 
to be restored as the current baseline.


TRUST
=====

Like all things from the internet: Don't trust it blindly!!!
This is a bash script with no intention of harming your system.
But a check never hurts. You use this program at your own risk.

