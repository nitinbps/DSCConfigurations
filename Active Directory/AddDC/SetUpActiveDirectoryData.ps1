
$SecurePassword = ConvertTo-SecureString -String "123_aaa" -AsPlainText -Force
$LocalAdmincredential = New-Object System.Management.Automation.PSCredential (".\nitin", $SecurePassword)

$safeModePassword = ConvertTo-SecureString -String "Bull_dog1" -AsPlainText -Force
$safeModeRecoverPS = New-Object System.Management.Automation.PSCredential (".\nitin", $safeModePassword)

$sqlUserPassword = ConvertTo-SecureString -String "123_aaa" -AsPlainText -Force
$sqlUserCredential = New-Object System.Management.Automation.PSCredential ("sqlUser", $sqlUserPassword)

$pullServeUserPassword = ConvertTo-SecureString -String "123_aaa" -AsPlainText -Force
$pullServeUserCredential = New-Object System.Management.Automation.PSCredential ("pullserverUser", $sqlUserPassword)
$configurationData = @{
        AllNodes = @(
                @{
                    NodeName='*'
                    DomainName = "Nitin.Test.com"
                    LocalAdmin = "nitin"
                    LocalAdminFullName="Nitin Test Domain Controller User"
                    LocalAdminDescription="Nitin Test Domain Controller User"
                    LocalAdminPassword=$LocalAdmincredential
                    WorkGroupName = 'NitinPrivateLab'
                    SafeModePassword=$safeModeRecoverPS
                    sqlUser = "sqlUser"
                    sqlUserCredential=$sqlUserCredential
                    SqlBackupFolderName="E:\Sqlbackup"
                    SqlBackupShareName="Sqlbackup"
                    SourceShareFolderName="E:\SourceShare"
                    SourceShareName="SourceShare"
                    pullServerUser="pullserverUser"
                    pullServerCredential=$pullServeUserCredential

                },
               @{
                    # Primary Domain controller
                    NodeName="ActiveDirectory"

                    #networking stuff
                    IPAddress = "192.168.100.7"
                    InterfaceAlias = "Ethernet"            
                    DefaultGateway = "192.168.100.7"
                    SubnetMask     = 24
                    AddressFamily  = "IPv4"
                    DnsAddress="192.168.100.7"

                    NewNodeName="DCNIT01"
                    PSDscAllowPlainTextPassword = $true
                    Role="AD"
                    DomainAdministratorCredential=$LocalAdmincredential
                    PSDscAllowDomainUser = $true

               },
               @{
                    NodeName="localhost_Replica"
                    NewNodeName="DCNIT02"
                    PSDscAllowPlainTextPassword = $true
                    Role="AD Replica"
                    DomainAdministratorCredential=$LocalAdmincredential
                    PSDscAllowDomainUser = $true
               }
        )
}

$configurationData