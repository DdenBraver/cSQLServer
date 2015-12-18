#requires -Version 5

#################################################################
# To use this example script, you require the following
#
# - DSC Modules cSQL and cFailover cluster
# - Domain Controller with domain name "DOMAIN"
# - 2 Domain Joined servers
# - Domain user: svc_mssql (member of mssql_administrators)
# - Domain group: mssql_administrators
# - SQL installation directory
# - Windows Image Source (for .net installation)
# - Correct the Configdata with your own input
#################################################################


$DomainAdministratorCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('DOMAIN\Administrator', (ConvertTo-SecureString -String 'Password01!' -AsPlainText -Force))
$InstallerServiceAccount = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('DOMAIN\Administrator', (ConvertTo-SecureString -String 'Password01!' -AsPlainText -Force))
$SQLServiceAccount = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('DOMAIN\svc_mssql', (ConvertTo-SecureString -String 'Password01!' -AsPlainText -Force))
$SQLSAAccount = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('SA', (ConvertTo-SecureString -String 'Password01!' -AsPlainText -Force))


Configuration SQL_SA_AO
{
    Import-DscResource -Module @{
        ModuleName    = 'cSQLServer'
        ModuleVersion = '2.0.2.1'
    }
    Import-DscResource -Module @{
        ModuleName    = 'cFailoverCluster'
        ModuleVersion = '1.2.1.6'
    }
    Import-DscResource -Module PSDesiredStateConfiguration
    
    Node $AllNodes.NodeName
    {
        # Set LCM to reboot if needed
        LocalConfigurationManager
        {
            DebugMode          = 'All'
            ActionAfterReboot  = 'StopConfiguration'
            ConfigurationMode  = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
        WindowsFeature 'NETFrameworkCore'
        {
            Ensure = 'Present'
            Name   = 'NET-Framework-Core'
            Source = $node.windowssource
        }
        WindowsFeature 'FailoverClustering'
        {
            Ensure               = 'Present'
            Name                 = 'Failover-Clustering'
            IncludeAllSubFeature = $true
            Source               = $node.windowssource
        }
        WindowsFeature 'RSATClusteringPowerShell'
        {
            Ensure = 'Present'
            Name   = 'RSAT-Clustering-PowerShell'
            Source = $node.windowssource
        }

        foreach($SQLServer in $node.SQLServers)
        {
            if ($node.ClusterNode -eq 'Primary')
            {
                $SQLInstanceName = $SQLServer.InstanceName
                $SQLServiceAccount  = $SQLServer.Serviceaccount
            
                cCluster 'SQLCluster1'
                {
                    DependsOn = @(
                        '[WindowsFeature]FailoverClustering', 
                        '[WindowsFeature]RSATClusteringPowerShell'
                    )
                    Name                          = $node.FailoverClusterNetworkName
                    StaticIPAddress               = $node.FailoverClusterIPAddress
                    DomainAdministratorCredential = $node.InstallerServiceAccount
                }
                WaitForAll 'SQLCluster1'
                {
                    ResourceName     = '[cCluster]SQLCluster1'
                    NodeName         = $node.AdditionalClusterNodes
                    RetryIntervalSec = 5
                    RetryCount       = 720
                }
                cSqlServerSetup SQLServer2014
                {
                    DependsOn           = '[WindowsFeature]NETFrameworkCore'
                    SourcePath          = $node.SQLSourcePath
                    SourceFolder        = $node.SQLSourceFolder
                    SetupCredential     = $node.InstallerServiceAccount
                    InstanceName        = $SQLInstanceName
                    Features            = $node.SQLFeatures
                    SQLSysAdminAccounts = $node.AdminAccount
                    SQLSvcAccount       = $SQLServiceAccount
                    SecurityMode        = 'SQL'
                    SAPwd               = $node.SAPassword
                    UpdateSource        = $node.SQLUpdateSource
                    InstallSharedDir    = 'C:\Program Files\Microsoft SQL Server'
                    InstallSharedWOWDir = 'C:\Program Files (x86)\Microsoft SQL Server'
                    InstanceDir         = 'C:\Microsoft SQL Server'
                    InstallSQLDataDir   = 'C:\Microsoft SQL Server'
                    SQLUserDBDir        = 'C:\Microsoft SQL Server\Data'
                    SQLUserDBLogDir     = 'C:\Microsoft SQL Server\Data'
                    SQLTempDBDir        = 'C:\Microsoft SQL Server\Data'
                    SQLTempDBLogDir     = 'C:\Microsoft SQL Server\Data'
                    SQLBackupDir        = 'C:\Microsoft SQL Server\Data'
                    ASDataDir           = 'C:\Microsoft SQL Server\OLAP\Data'
                    ASLogDir            = 'C:\Microsoft SQL Server\OLAP\Log'
                    ASBackupDir         = 'C:\Microsoft SQL Server\OLAP\Backup'
                    ASTempDir           = 'C:\Microsoft SQL Server\OLAP\Temp'
                    ASConfigDir         = 'C:\Microsoft SQL Server\OLAP\Config'
                    Filestreamlevel     = $node.filestreamlevel
                }
                cSqlServerFirewall SQLServer2014
                {
                    DependsOn    = ('[cSqlServerSetup]SQLServer2014')
                    SourcePath   = $node.SQLSourcePath
                    SourceFolder = $node.SQLSourceFolder
                    InstanceName = $SQLInstanceName
                    Features = $node.SQLFeatures
                }
                cSqlHAService ('EnableSQLHA' + $SQLInstanceName)
                {
                    InstanceName               = $SQLInstanceName
                    ServiceCredential          = $SQLServiceAccount
                    SQLAdministratorCredential = $node.SQLAdministratorCredential
                    SQLServerName              = $node.NodeName
                    PsDscRunAsCredential       = $node.DomainAdministratorCredential
                    DependsOn                  = '[cSqlServerSetup]SQLServer2014'
                }
                WaitForAll ('ClusterHA' + $SQLInstanceName)
                {
                    NodeName         = $node.AdditionalClusterNodes
                    ResourceName     = '[cSqlHAService]EnableSQLHA' + $SQLInstanceName
                    RetryIntervalSec = 5
                    RetryCount       = 720
                }
                cSqlHAEndPoint ('ConfigureEndpoint' + $SQLInstanceName)
                {
                    InstanceName         = $SQLInstanceName
                    AllowedUser          = $SQLServiceAccount.Username
                    Name                 = $node.SQLEndpointName
                    PortNumber           = $node.SQLEndpointPort
                    SQLServerName        = $node.NodeName
                    DependsOn            = '[cSqlHAService]EnableSQLHA' + $SQLInstanceName
                    PsDscRunAsCredential = $node.DomainAdministratorCredential
                }
                WaitForAll ('cSqlHAEndPoint' + $SQLInstanceName)
                {
                    NodeName         = $node.AdditionalClusterNodes
                    ResourceName     = '[cSqlHAEndPoint]ConfigureEndpoint' + $SQLInstanceName
                    RetryIntervalSec = 5
                    RetryCount       = 720
                }
                cSqlAvailabilityGroup "$($node.AvailabilityGroupName)"
                {
                    AvailabilityGroupName     = $node.AvailabilityGroupName
                    PrimarySQLInstance        = $node.PrimarySQLInstance
                    SecondarySQLInstance      = $node.SecondarySQLInstance
                    AvailabilityGroupDatabase = $node.AvailabilityGroupDatabase
                    BackupDirectory           = $node.BackupDirectory
                    ListenerName              = $node.ListenerName
                    ListenerIpAddress         = $node.ListenerIpAddress
                    ListenerSubnetMask        = $node.ListenerSubnetMask
                    Force                     = $true
                    PsDscRunAsCredential      = $node.DomainAdministratorCredential
                    ReplicaFailoverMode       = $node.ReplicaFailoverMode
                }
            }
            else
            {
                $SQLInstanceName = $SQLServer.InstanceName
                $SQLServiceAccount  = $SQLServer.Serviceaccount
            
                WaitForAll 'SQLCluster1'
                {
                    ResourceName     = '[cCluster]SQLCluster1'
                    NodeName         = $node.PrimaryClusterNode
                    RetryIntervalSec = 5
                    RetryCount       = 720
                }
                cWaitForCluster 'SQLCluster1'
                {
                    DependsOn        = '[WaitForAll]SQLCluster1'
                    Name             = $node.FailoverClusterNetworkName
                    RetryIntervalSec = 10
                    RetryCount       = 60
                }
                cCluster 'SQLCluster1'
                {
                    DependsOn                     = '[cWaitForCluster]SQLCluster1'
                    Name                          = $node.FailoverClusterNetworkName
                    StaticIPAddress               = $node.FailoverClusterIPAddress
                    DomainAdministratorCredential = $node.InstallerServiceAccount
                }
                cSqlServerSetup SQLServer2014
                {
                    DependsOn           = '[WindowsFeature]NETFrameworkCore'
                    SourcePath          = $node.SQLSourcePath
                    SourceFolder        = $node.SQLSourceFolder
                    SetupCredential     = $node.InstallerServiceAccount
                    InstanceName        = $SQLInstanceName
                    Features            = $node.SQLFeatures
                    SQLSysAdminAccounts = $node.AdminAccount
                    SQLSvcAccount       = $SQLServiceAccount
                    SecurityMode        = 'SQL'
                    SAPwd               = $node.SAPassword
                    UpdateSource        = $node.SQLUpdateSource
                    InstallSharedDir    = 'C:\Program Files\Microsoft SQL Server'
                    InstallSharedWOWDir = 'C:\Program Files (x86)\Microsoft SQL Server'
                    InstanceDir         = 'C:\Microsoft SQL Server'
                    InstallSQLDataDir   = 'C:\Microsoft SQL Server'
                    SQLUserDBDir        = 'C:\Microsoft SQL Server\Data'
                    SQLUserDBLogDir     = 'C:\Microsoft SQL Server\Data'
                    SQLTempDBDir        = 'C:\Microsoft SQL Server\Data'
                    SQLTempDBLogDir     = 'C:\Microsoft SQL Server\Data'
                    SQLBackupDir        = 'C:\Microsoft SQL Server\Data'
                    ASDataDir           = 'C:\Microsoft SQL Server\OLAP\Data'
                    ASLogDir            = 'C:\Microsoft SQL Server\OLAP\Log'
                    ASBackupDir         = 'C:\Microsoft SQL Server\OLAP\Backup'
                    ASTempDir           = 'C:\Microsoft SQL Server\OLAP\Temp'
                    ASConfigDir         = 'C:\Microsoft SQL Server\OLAP\Config'
                    Filestreamlevel     = $node.filestreamlevel
                }
                cSqlServerFirewall SQLServer2014
                {
                    DependsOn    = ('[cSqlServerSetup]SQLServer2014')
                    SourcePath   = $node.SQLSourcePath
                    SourceFolder = $node.SQLSourceFolder
                    InstanceName = $SQLInstanceName
                    Features = $node.SQLFeatures
                }
                WaitForAll ('ClusterHA' + $SQLInstanceName)
                {
                    NodeName         = $node.PrimaryClusterNode
                    ResourceName     = '[cSqlHAService]EnableSQLHA' + $SQLInstanceName
                    RetryIntervalSec = 5
                    RetryCount       = 720
                }
                cSqlHAService ('EnableSQLHA' + $SQLInstanceName)
                {
                    InstanceName               = $SQLInstanceName
                    ServiceCredential          = $SQLServiceAccount
                    SQLAdministratorCredential = $node.SQLAdministratorCredential
                    SQLServerName              = $node.NodeName
                    PsDscRunAsCredential       = $node.DomainAdministratorCredential
                    DependsOn                  = '[cSqlServerSetup]SQLServer2014'
                }
                cSqlHAEndPoint ('ConfigureEndpoint' + $SQLInstanceName)
                {
                    InstanceName         = $SQLInstanceName
                    AllowedUser          = $SQLServiceAccount.Username
                    Name                 = $node.SQLEndpointName
                    PortNumber           = $node.SQLEndpointPort
                    SQLServerName        = $node.NodeName
                    DependsOn            = '[cSqlHAService]EnableSQLHA' + $SQLInstanceName
                    PsDscRunAsCredential = $node.DomainAdministratorCredential
                }
            }
        }
    }
}

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName                      = '*'
            PSDscAllowPlainTextPassword   = $true
            Windowssource                 = '\\dc01\data\sxs'
            DomainAdministratorCredential = $DomainAdministratorCredential
            SQLAdministratorCredential    = $DomainAdministratorCredential
            InstallerServiceAccount       = $InstallerServiceAccount
            SQLSysadmins                  = @('Administrator', 'DOMAIN\MSSQL_Administrators')
            AdminAccount                  = 'DOMAIN\MSSQL_Administrators'
            FailoverClusterNetworkName    = 'Cluster'
            PrimaryClusterNode            = 'SQL1'
            AdditionalClusterNodes        = 'SQL2'
            AvailabilityGroupName         = 'Cluster-SAO1'
            AvailabilityGroupDatabase     = 'Cluster-SAO1-DB1'
            ListenerName                  = 'Cluster-SAOL1'
            ListenerIpAddress             = '192.168.10.11'
            ListenerSubnetMask            = '255.255.255.0'
            ReplicaFailoverMode           = 'Automatic'
            BackupDirectory               = '\\dc01\data\SQLBackup'
            PrimarySQLInstance            = 'SQL1\Instance1'
            SecondarySQLInstance          = 'SQL2\Instance1'
            FailoverClusterIPAddress      = '192.168.10.10'
            SQLEndpointName               = 'Cluster-SFCE1'
            SQLEndpointPort               = '5022'
            SQLSourcePath                 = '\\dc01\data'
            SQLSourceFolder               = '\SQLServer\2014'
            SQLFeatures                   = 'SQLENGINE,SSMS'
            SQLUpdateSource               = '.\MU'
            SAPassword                    = $SQLSAAccount
            filestreamlevel               = "3"
        }
        @{
            NodeName    = 'SQL1'
            ClusterNode = 'Primary'
            SQLServers  = @(
                @{
                    InstanceName   = 'Instance1'
                    Serviceaccount = $SQLServiceAccount
                }
            )
        }
        @{
            NodeName    = 'SQL2'
            ClusterNode = 'Additional'
            SQLServers  = @(
                @{
                    InstanceName   = 'Instance1'
                    Serviceaccount = $SQLServiceAccount
                }
            )
        }
    )
}

SQL_SA_AO -ConfigurationData $ConfigurationData -OutputPath 'C:\DSC\Staging\SQL_SA_AO'
$Computernames = 'SQL1', 'SQL2'
Set-DscLocalConfigurationManager -ComputerName $Computernames -Verbose -path 'C:\DSC\Staging\SQL_SA_AO'
Start-DscConfiguration -Path 'C:\DSC\Staging\SQL_SA_AO' -ComputerName $Computernames -Verbose -Wait -Force