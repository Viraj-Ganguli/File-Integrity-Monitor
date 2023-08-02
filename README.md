# File-Integrity-Monitor

This script is used for monitoring changes in a specific directory. The changes include the creation of new files, changes in existing files, and deletion of files. The changes are detected by calculating the SHA512 hashes of each file in the target directory and comparing them with previous hashes stored in a baseline file.

Usage

1. Run the script.
2.  When prompted, enter the path of the folder you want to monitor.
3. Next, you will be asked to either Collect New Baseline or Begin monitoring files with saved Baseline. Here are the options:

  A) Collect New Baseline: This will delete the existing baseline file if it exists and calculate the hashes of all files in the target directory, storing them in the baseline.txt file.
  
  B) Begin monitoring files with saved Baseline: This option will start continuously monitoring the target folder. It will notify you of any changes in the files within the directory. The changes could be in the form of the creation of a new file, changes to an existing file, or deletion of a file.
