Configuration AssignStaticIpAndDNS
{
    import-dscresource -modulename xNetworking
    xIPAddress setStaticIPAddress
    {
        IPAddress      = $Node.IPAddress
        InterfaceAlias = $Node.InterfaceAlias
        DefaultGateway = $Node.DefaultGateway
        SubnetMask     = $Node.SubnetMask
        AddressFamily  = $Node.AddressFamily
    }

    xDNSServerAddress setDNS
    {
        Address        = $Node.DnsAddress
        InterfaceAlias = $Node.InterfaceAlias
        AddressFamily  = $Node.AddressFamily

        DependsOn = "[xIPAddress]setStaticIPAddress"
    }
}

Configuration JoinDomainAndAddUser
{
    import-dscResource -moduleName PsDesiredStateConfiguration
    import-dscResource -moduleName xComputerManagement
    import-dscresource -moduleName xActiveDirectory

    xComputer ComputerNameAndWorkgroup
    {
        Name       = $Node.Name
        DomainName = $Node.DomainName
        Credential = $Node.DomainAdministratorCredential

    }

    Group AddLocalUserToAdminGroup
    {
        GroupName = "Administrators"
        Ensure = 'Present'
        MembersToInclude = $Node.DomainAdmin
        DependsOn= "[xComputer]ComputerNameAndWorkgroup"
        Credential = $Node.DomainAdministratorCredential
    }
}
configuration CreateDSCPullServer
{
    Import-DscResource -modulename psdesiredStateConfiguration
    Import-DscResource -moduleName xpsdesiredStateConfiguration
    
    Node $AllNodes.Where{$_.Role -eq "PullServer" }.NodeName
    {
        AssignStaticIpAndDNS ipAddress
        {
        }
        JoinDomainAndAddUser joinDomain
        {
            DependsOn = "[AssignStaticIpAndDNS]ipAddress"
        }
        # Install DSC Service
        WindowsFeature DSCServiceFeature
        {
            Ensure = "Present"
            Name = "DSC-Service"
            IncludeAllSubFeature = $true
            DependsOn = "[JoinDomainAndAddUser]joinDomain"
        }

        # setup pull server endpoint
        xDSCWebService PSDSCPullServerEndpoint
        {
            Ensure = "Present"
            EndpointName = $node.PSDSCPullServerEndpoint_EndPointName
            Port = $Node.PSDSCPullServerEndpoint_Port
            PhysicalPath = $node.PSDSCPullServerEndpoint_PhysicalPath
            ModulePath = $node.PSDSCPullServerEndpoint_ModulePath
            ConfigurationPath = $node.PSDSCPullServerEndpoint_ConfigurationPath
            State = "Started"
            CertificateThumbPrint = "AllowUnencryptedTraffic"
            DependsOn= "[WindowsFeature]DSCServiceFeature"

        }
        # setup compliance server endpoint
        xDSCWebService PSDSCComplianceServerEndpoint
        {
            Ensure = "Present"
            EndpointName = $node.PSDSCComplianceServerEndpoint_EndPointName
            Port = $Node.PSDSCComplianceServerEndpoint_Port
            PhysicalPath = $node.PSDSCComplianceServerEndpoint_PhysicalPath
            State = "Started"
            CertificateThumbPrint = "AllowUnencryptedTraffic"
            DependsOn= "[WindowsFeature]DSCServiceFeature"
            IsComplianceServer = $true

        }

        LocalConfigurationManager 
        { 
            #CertificateId = $node.Thumbprint 
            RebootNodeIfNeeded = $true
        } 
    }

}