
$sqlUserPassword = ConvertTo-SecureString -String "123_aaa" -AsPlainText -Force
$domainName = "Nitin.Test.com"
$sqlUserCredential = New-Object System.Management.Automation.PSCredential ("$domainName\sqlUser", $sqlUserPassword)

$RealDomainAdministratorCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Nitin", $sqlUserPassword)

$sqlAdminAccountPassword = ConvertTo-SecureString -String "123_aaa" -AsPlainText -Force
$SQLsaCred = New-Object System.Management.Automation.PSCredential ("sa", $sqlUserPassword)
$ShareServerName = "DCNIT01"
$backupShareName = "Sqlbackup"
$sourceShareName= "SourceShare"
$SqlShareName = "Sql12SP1"

$configurationData = @{
        AllNodes = @(
                @{
                    NodeName='*'
                    
                    # Networking stuff
                    InterfaceAlias = "Ethernet"            
                    DefaultGateway = "192.168.100.7"
                    SubnetMask     = 24
                    AddressFamily  = "IPv4"
                    DnsAddress = "192.168.100.7"
                    DomainName = "Nitin.Test.com"
                    DomainAdministratorCredential=$sqlUserCredential
                    RealDomainAdministratorCredential=$RealDomainAdministratorCredential
                    DomainAdmin = "$domainName\sqluser"

                    #sql stuff


                    installCred = $sqlUserCredential
                    sqlServiceCred = $sqlUserCredential
                    ClusterName = "SqlC"
                    ClusterIPAddress = "192.168.100.10/24"

                    Database = "TestDB"
                    AvailabilityGroup = "TestAG"
                    BackupShare = "\\$ShareServerName\$backupShareName"

                    EndPointName = "TestEndPoint"

                    SqlInstallFeatures="SQLEngine,Replication,SSMS"

                    SqlInstanceName = "PowerPivot"


                    DotNetSxSShare = "\\$ShareServerName\$sourceShareName\SxS"
                    DotNetSxS = "C:\SXS"

                    SqlInstallSharePath = "\\$ShareServerName\$sourceShareName\$SqlShareName"
                    SqlAdministratorAccountName = "sa"
                    SQLsaCred = $SQLsaCred

                    #Reporting Stuff
                    PullServerUrl = "http://pullserver01:8080/PsDscPullServer/PsDscPullServer.svc"


                },
               @{
                    # Primary Sql Cluster Node
                    NodeName="HASQL_Primary1"

                    #networking stuff
                    IPAddress = "192.168.100.11"

                    Name="sql01"
                    PSDscAllowPlainTextPassword = $true
                    Role="PrimarySqlClusterNode"
                    PSDscAllowDomainUser = $true
                    EndPointURL = "sql01.Nitin.Test.com:5022"
                    SqlServerInstance = "sql01\PowerPivot"

               },
               @{
                    # Replica Sql Cluster Node
                    NodeName="HASQL_Replica1"

                    #networking stuff
                    IPAddress = "192.168.100.12"

                    Name="sql02"
                    PSDscAllowPlainTextPassword = $true
                    Role="ReplicaSqlClusterNode"
                    PSDscAllowDomainUser = $true
                    EndPointURL = "sql02.Nitin.Test.com:5022"
                    SqlServerInstance = "sql02\PowerPivot"

               },
               @{
                    # Replica Sql Cluster Node
                    NodeName="HASQL_Replica2"

                    #networking stuff
                    IPAddress = "192.168.100.13"

                    Name="sql03"
                    PSDscAllowPlainTextPassword = $true
                    Role="ReplicaSqlClusterNode"
                    PSDscAllowDomainUser = $true
                    EndPointURL = "sql03.Nitin.Test.com:5022"
                    SqlServerInstance = "sql03\PowerPivot"

               }
        )
}

$configurationData