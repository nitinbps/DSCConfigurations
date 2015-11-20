
$pullServerUserPassword = ConvertTo-SecureString -String "123_aaa" -AsPlainText -Force
$domainName = "Nitin.Test.com"
$pullServerUserName="pullserverUser"
$pullServerlUserCredential = New-Object System.Management.Automation.PSCredential ("$domainName\$pullServerUserName", $pullServerUserPassword)


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
                    DomainAdministratorCredential=$pullServerlUserCredential
                    DomainAdmin = "$domainName\$pullServerUserName"


                },
               @{
                    # Pull Server
                    NodeName="PullServer1"
                    Name="pullServer01"
                    PSDscAllowPlainTextPassword = $true
                    Role="PullServer"
                    PSDscAllowDomainUser = $true

                    #networking stuff
                    IPAddress = "192.168.100.31"

                    # PSDSCPullServerEndpoint configuration
                    PSDSCPullServerEndpoint_EndPointName="PSDSCPullServer"
                    PSDSCPullServerEndpoint_Port=8080
                    PSDSCPullServerEndpoint_PhysicalPath="C:\inetpub\wwwroot\PSDSCPullServer"
                    PSDSCPullServerEndpoint_ModulePath="C:\program Files\WindowsPowershell\DscService\Modules"
                    PSDSCPullServerEndpoint_ConfigurationPath="C:\program Files\WindowsPowershell\DscService\Configuration"

                    #PSDSCComplianceServerEndpoint configuration
                    PSDSCComplianceServerEndpoint_EndPointName="PSDSCComplianceServer"
                    PSDSCComplianceServerEndpoint_Port=9080
                    PSDSCComplianceServerEndpoint_PhysicalPath="C:\inetpub\wwwroot\PSDSCComplianceServer"

               }
        )
}

$configurationData