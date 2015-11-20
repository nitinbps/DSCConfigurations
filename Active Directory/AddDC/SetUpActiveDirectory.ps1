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

Configuration JoinWorkGroupAndAddUser
{
    import-dscResource -moduleName PsDesiredStateConfiguration
    import-dscResource -moduleName xComputerManagement

    xComputer ComputerNameAndWorkgroup
    {
        Name = $node.NewNodeName
        #WorkGroupName = $node.WorkGroupName

    }
    user LocalUser
    {
        UserName = $node.LocalAdmin
        Description = $node.LocalAdminDescription
        Ensure= 'Present'
        FullName = $node.LocalAdminFullName
        Password = $node.LocalAdminPassword
        PasswordNeverExpires = $true
        PasswordChangeRequired = $false
        DependsOn = "[xComputer]ComputerNameAndWorkgroup"
    }
#    Group AddLocalUserToAdminGroup
#    {
#        GroupName = "Administrators"
#        Ensure = 'Present'
#        MembersToInclude = $node.LocalAdmin
#        DependsOn= "[user]LocalUser"
#    }
}

Configuration ActiveDirectoryRoles
{
    import-dscResource -modulename PsDesiredStateConfiguration

    WindowsFeature ADDSInstall
    {
        Name= "AD-Domain-Services"
        Ensure='Present'
        IncludeAllSubFeature = $true
    }

    WindowsFeature RSATTools
    {
        Name= "RSAT-AD-Tools"
        Ensure='Present'
        IncludeAllSubFeature = $true
        DependsOn = "[WindowsFeature]ADDSInstall"
    }
    Service ADDS
    {
        Name = "ADWS"
        DependsOn = "[WindowsFeature]ADDSInstall", "[WindowsFeature]RSATTools"
        StartupType = 'Automatic'
        Ensure = "Present"
    }
}

Configuration ADPre
{
    JoinWorkGroupAndAddUser joinDomain
    {
    }
    AssignStaticIpAndDNS setIPAndDNS
    {
        DependsOn = "[JoinWorkGroupAndAddUser]joinDomain"
    }
    ActiveDirectoryRoles deployRoles
    {
        DependsOn = "[AssignStaticIpAndDNS]setIPAndDNS"
    }
    
}

configuration AddDomainControllerReplica
{
    import-dscresource -modulename xActiveDirectory
    
    Node $AllNodes.Where{$_.Role -eq 'AD Replica'}.NodeName
    {
        localConfigurationManager 
        {
            RebootNodeIfNeeded = $true
            ActionAfterReboot = 'StopConfiguration'

        }

        ADPre ADPreReq
        {
        }

        xADDomainController domainController
        {
            DomainName = $node.DomainName
            DomainAdministratorCredential = $node.DomainAdministratorCredential
            SafemodeAdministratorPassword = $node.SafeModePassword
            DependsOn = "[ADPre]ADPreReq"
        }

    }

}

configuration CreateNetworkShareForSql
{
    import-DscResource -modulename PsDesiredStateConfiguration
    import-DscResource -moduleName xSmbShare 

    # backup share for SQL
    File createBackupFolder
    {
        Ensure = "Present"
        DestinationPath = $Node.SqlBackupFolderName
        Type = "Directory"
    }


    xSmbShare setSqlBackupShare
    {
        Ensure = "Present"
        Name = $Node.SqlBackupShareName
        Path = $Node.SqlBackupFolderName
        FullAccess = $Node.sqlUser

        DependsOn = "[File]createBackupFolder"
    }

    # source Share

    File createSourceFolder
    {
        Ensure = "Present"
        DestinationPath = $Node.SourceShareFolderName
        Type = "Directory"
    }


    xSmbShare setSourceShare
    {
        Ensure = "Present"
        Name = $Node.SourceShareName
        Path = $Node.SourceShareFolderName
        FullAccess = $Node.sqlUser

        DependsOn = "[File]createBackupFolder"
    }
}
configuration CreateDomain
{
    import-dscResource -moduleName PsDesiredStateConfiguration
    import-dscResource -modulename xActiveDirectory

    Node $AllNodes.Where{$_.Role -eq 'AD'}.NodeName
    {
        localConfigurationManager 
        {
            RebootNodeIfNeeded = $true
            #ActionAfterReboot = 'StopConfiguration'

        }
        ADPre ADPreReq
        {
        }

        xADDomain SetupDomain
        {
            # Specifies the credential for the account used to install the domain controller
            DomainAdministratorCredential = $node.DomainAdministratorCredential
            DomainName = $node.DomainName
            SafemodeAdministratorPassword = $node.SafeModePassword
            #DomainNetbiosName = $node.DomainName.Split('.')[0]
            DependsOn = "[ADPre]ADPreReq"
        }

        # add user for sql server
        xAdUser sqlUser
        {
            DomainName = $node.DomainName
            DomainAdministratorCredential = $node.DomainAdministratorCredential
            Ensure = 'Present'
            UserName = $node.sqlUser
            Password = $node.sqlUserCredential
        }

        # Add user for pull server
        xAdUser pullServerUser
        {
            DomainName = $node.DomainName
            DomainAdministratorCredential = $node.DomainAdministratorCredential
            Ensure = 'Present'
            UserName = $node.pullServerUser
            Password = $node.pullServerCredential
        }
        CreateNetworkShareForSql sqlShare
        {
            dependsOn = "[xAdUser]sqlUser"
        }
    }

}


#CreateDomain -configurationData (./SetUpActiveDirectoryData.ps1)