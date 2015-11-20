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

Configuration ClusterRoles
{
    import-dscResource -modulename PsDesiredStateConfiguration

    WindowsFeature ADPS
    {
        Name= "RSAT-AD-PowerShell"
        Ensure='Present'
        IncludeAllSubFeature = $true
    }

    WindowsFeature FailoverFeature
    {
        Name= "Failover-clustering"
        Ensure='Present'
        IncludeAllSubFeature = $true
        DependsOn = "[WindowsFeature]ADPS"
    }
    WindowsFeature RSATClusteringPowerShell
    {
        Ensure = "Present"
        Name   = "RSAT-Clustering-PowerShell"   
        DependsOn = "[WindowsFeature]FailoverFeature"
    }

    WindowsFeature RSATClusteringCmdInterface
    {
        Ensure = "Present"
        Name   = "RSAT-Clustering-CmdInterface"
        DependsOn = "[WindowsFeature]RSATClusteringPowerShell"
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


configuration sqlServerPreReq
{
    import-dscResource -modulename psDesiredStateConfiguration

        File copySource
        {
            Type = 'Directory'
            DestinationPath=$Node.DotNetSxS
            SourcePath=$Node.DotNetSxSShare
            Recurse = $true
            Ensure = "Present"
            Credential = $Node.DomainAdministratorCredential
        }
        WindowsFeature installdotNet35
        {            
            Ensure = "Present"
            Name = "Net-Framework-Core"
            Source = $Node.DotNetSxS
        }
}

configuration sqlServerPostReq
{
    import-dscResource -moduleName xNetworking

    xFireWall enableRemoteAccessOnSQLBrowser
    {

        Name = "SqlBrowser"
        Ensure = "Present"
        Access = "Allow"
        State ="Enabled"
        ApplicationPath = Join-Path ${env:ProgramFiles(x86)} -ChildPath "Microsoft SQL Server\90\Shared\sqlbrowser.exe"
        Profile = "Any"

    }

    xFireWall enableRemoteAccessOnSQLEngine
    {
        Name = "SqlServer"
        Ensure = "Present"
        Access = "Allow"
        State ="Enabled"
        ApplicationPath = Join-Path $env:ProgramFiles -ChildPath "Microsoft SQL Server\MSSQL11.$($Node.SqlInstanceName)\MSSQL\Binn\sqlservr.exe"
        Profile = "Any"
    }
}

configuration SetUpHASQLGA
{
    import-DscResource -moduleName xSqlPs
    import-DscResource -moduleName xFailOverCluster
    import-DscResource -moduleName xActiveDirectory


    Node $AllNodes.Where{$_.Role -eq "ReplicaSqlClusterNode" }.NodeName
    {
   # assign sattic IPs    
       AssignStaticIpAndDNS ipAndDNS
       {
       }

   # install cluster roles and prereq
       ClusterRoles clusterSetup
       {
         DependsOn = "[AssignStaticIpAndDNS]ipAndDNS"
       }

       xWaitForADDomain DscForestWait
       {
            DomainName = $Node.DomainName
            DomainUserCredential = $Node.DomainAdministratorCredential
            RetryCount = 10
            RetryIntervalSec = 300

            DependsOn = "[ClusterRoles]clusterSetup"
        }
    # join domain
       JoinDomainAndAddUser joinDomain
       {
         DependsOn="[xWaitForADDomain]DscForestWait"
       }

    # Pre-Req for SQL server
       sqlServerPreReq  sqlPreRep
       {
            DependsOn="[JoinDomainAndAddUser]joinDomain"
       }

    # Install SQL Server
        xSqlServerInstall installSqlServer
        {
            InstanceName = $Node.SqlInstanceName

            SourcePath = $Node.SqlInstallSharePath
            SourcePathCredential = $Node.installCred
            
            Features= $Node.SqlInstallFeatures
            SqlAdministratorCredential = $Node.SQLsaCred

            DependsOn = "[sqlServerPreReq]sqlPreRep"
        }

    # post-req for sql Server
        sqlServerPostReq sqlPostReq
        {
            DependsOn="[xSqlServerInstall]installSqlServer"
        }

    # config SQL Server to HAG

        # config SQL 

        xWaitForCluster waitForCluster
        {
            Name = $Node.ClusterName
            RetryIntervalSec = 10
            RetryCount = 600

            DependsOn = "[sqlServerPostReq]sqlPostReq"
        }

        xCluster createOrJoinCluster
        {
            Name = $Node.ClusterName
            StaticIPAddress = $Node.ClusterIPAddress
            DomainAdministratorCredential = $Node.DomainAdministratorCredential

            DependsOn = "[xWaitForCluster]waitForCluster"
        }

        xSqlHAService config
        {
            InstanceName = $Node.SqlServerInstance
            SqlAdministratorCredential = $Node.SQLsaCred
            ServiceCredential = $Node.SQLsaCred

            DependsOn = "[xCluster]createOrJoinCluster"
        }
           
        xSqlHAEndPoint configEndPoint
        {
            InstanceName = $Node.SqlServerInstance
            AllowedUser = $Node.sqlServiceCred.UserName
            Name = $Node.EndPointName

            DependsOn = "[xSqlHAService]config"
        }


        xWaitForSqlHAGroup waitForHAG
        {
            Name = $Node.AvailabilityGroup
            ClusterName = $Node.ClusterName
            RetryIntervalSec = 10
            RetryCount = 10

            InstanceName = $Node.SqlServerInstance

            DomainCredential = $Node.DomainAdministratorCredential
            SqlAdministratorCredential = $Node.SQLsaCred

            DependsOn = "[xSqlHAEndPoint]configEndPoint"
        }

        xSqlHAGroup createOrJoinHAG
        {
            Name = $Node.AvailabilityGroup
            Database = $Node.Database
            ClusterName = $Node.ClusterName
            DatabaseBackupPath = $Node.BackupShare

            InstanceName = $Node.SqlServerInstance
            EndpointName = $Node.EndPointURL

            DomainCredential = $Node.DomainAdministratorCredential
            SqlAdministratorCredential = $Node.SQLsaCred
            
            DependsOn = "[xSqlHAEndPoint]configEndPoint"
        } 
        
        LocalConfigurationManager 
        { 
            #CertificateId = $node.Thumbprint 
            RebootNodeIfNeeded = $true
        } 

    }
    Node $AllNodes.Where{$_.Role -eq "PrimarySqlClusterNode" }.NodeName
    {
 
    # assign sattic IPs    
       AssignStaticIpAndDNS ipAndDNS
       {
       }

    # install cluster roles and prereq
       ClusterRoles clusterSetup
       {
         DependsOn = "[AssignStaticIpAndDNS]ipAndDNS"
       }

       xWaitForADDomain DscForestWait
       {
            DomainName = $Node.DomainName
            DomainUserCredential = $Node.DomainAdministratorCredential
            RetryCount = 10
            RetryIntervalSec = 300

            DependsOn = "[ClusterRoles]clusterSetup"
        }
    # join domain
       JoinDomainAndAddUser joinDomain
       {
         DependsOn="[xWaitForADDomain]DscForestWait"
       }

    # Pre-Req for SQL server
       sqlServerPreReq  sqlPreRep
       {
            DependsOn="[JoinDomainAndAddUser]joinDomain"
       }
       
    # Install SQL Server

        
        xSqlServerInstall installSqlServer
        {
            InstanceName = $Node.SqlInstanceName

            SourcePath = $Node.SqlInstallSharePath
            SourcePathCredential = $Node.installCred
            
            Features= $Node.SqlInstallFeatures
            SqlAdministratorCredential = $Node.SQLsaCred

            DependsOn = "[sqlServerPreReq]sqlPreRep"
        }

    # post-req for sql Server
        sqlServerPostReq sqlPostReq
        {
            DependsOn="[xSqlServerInstall]installSqlServer"
        }
 
    # config SQL Server to HAG

        xCluster createOrJoinCluster
        {
            Name = $Node.ClusterName
            StaticIPAddress = $Node.ClusterIPAddress
            DomainAdministratorCredential = $Node.DomainAdministratorCredential

            DependsOn = "[sqlServerPostReq]sqlPostReq"
        }

        xSqlHAService config
        {
            InstanceName = $Node.SqlServerInstance
            SqlAdministratorCredential = $Node.SQLsaCred
            ServiceCredential = $Node.SQLsaCred

            DependsOn = "[xCluster]createOrJoinCluster"
        }
           
        xSqlHAEndPoint configEndPoint
        {
            InstanceName = $Node.SqlServerInstance
            AllowedUser = $Node.sqlServiceCred.UserName
            Name = $Node.EndPointName

            DependsOn = "[xSqlHAService]config"
        }
  
        xSqlHAGroup createOrJoinHAG
        {
            Name = $Node.AvailabilityGroup
            Database = $Node.Database
            ClusterName = $Node.ClusterName
            DatabaseBackupPath = $Node.BackupShare

            InstanceName = $Node.SqlServerInstance
            EndpointName = $Node.EndPointURL

            DomainCredential = $Node.DomainAdministratorCredential
            SqlAdministratorCredential = $Node.SQLsaCred
            
            DependsOn = "[xSqlHAEndPoint]configEndPoint"
        } 
        
    }

}

[DscLocalConfigurationManager()]
configuration SetUpHASQLGA
{
    Node $AllNodes.NodeName
    {
        Settings
        {
            #CertificateId = $node.Thumbprint 
            RebootNodeIfNeeded = $true            
        }

        ReportServerWeb PullServer1
        {
            ServerURL = $Node.PullServerUrl
            AllowUnsecureConnection = $true
        }
    }
}