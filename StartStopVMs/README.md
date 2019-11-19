## Start and Stop VMs

# **Description**

This script starts or shuts down the virtual machines stored in a csv file which in turn is stored in the blob storage for the automation account to access it.
The script uses the default automation connection to connect to the subscription of the automation account and then starts/stops the virtual machines in order. It supports two operations:
- If the Start operation is chosen, it starts the machines starting from the top of the csv
- If the Stop operation is chosen, it starts the machines starting from the bottom of the csv
This script only works within the subscription. 

VMs are turned on one by one, assuming dependencies.
   
The origin .csv file has 2 columns: ResourceGroup and VMName. Example csv file is provided in this folder.
