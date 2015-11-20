Dependencies: xActiveDirectory and xComputerManagement module

1) Copy attached *.ps1 in C:\temp folder on a machine with server SKU.
2) ipmo SetUpActiveDirectory.ps1
3)  CreateDomain -configurationData (./SetUpActiveDirectoryData.ps1).
4) Machine will configure itself rebooting multiple times (wait for ~30-40 minutes before DSC thinks it is done).

Known issue: Even though the configuration is reporting as failed at the end, AD is setup correctly.