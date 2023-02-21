# AppControl_scripts

This repo contains scripts that leverage the VMware App Control API to perform specific tasks.

# AppCHashImport.ps1
This script will allow you to import a CSV of hashes or file names to the App Control server and define if those hashes/file names are to be approved or banned.
The example hashlist.csv provides an example of the required CSV format.
NOTE: This script does not validate the input CSV format so I recommend downloading hashlist.csv and editing as needed.

You can import a hash or file name and name that rule individually as well as provide a description for that rule.  This overcomes the limitation of the App Control UI that will only allow you to import a list of hashes and will apply the same Rule Name and Description to all hashes.

You will need to provide the App Control server URI and an API Token that has sufficient permissions (Required permissions: ‘View files’, ‘Manage files’).

NOTE: This script only creates new File Rules, it does not modify existing File Rules or delete File Rules.  If you import an existing hash you may receive an error.

This script is provided as is and does not include support from VMware or its employees.
