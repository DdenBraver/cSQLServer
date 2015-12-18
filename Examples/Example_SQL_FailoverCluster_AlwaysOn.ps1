﻿#requires -Version 5

#################################################################
# To use this example script, you require the following
#
# - DSC Modules cSQL and cFailover cluster
# - Domain Controller with domain name "DOMAIN"
# - 4 Domain Joined servers
# - Domain user: svc_mssql (member of mssql_administrators)
# - Available shared storage for all 4 servers/nodes.
# - Create Volumes X/Y on the Primary node on the shared storage
# - SQL installation directory
# - Windows Image Source (for .net installation)
# - Correct the Configdata with your own input
#################################################################

$DomainAdministratorCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('DOMAIN\Administrator', (ConvertTo-SecureString -String 'Password01!' -AsPlainText -Force))
$InstallerServiceAccount = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('DOMAIN\Administrator', (ConvertTo-SecureString -String 'Password01!' -AsPlainText -Force))
$SQLServiceAccount = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ('DOMAIN\svc_mssql', (ConvertTo-SecureString -String 'Password01!' -AsPlainText -Force))

Configuration SQL_Cluster_Install
{
    Import-DscResource -Module @{ModuleName='cSQLServer';ModuleVersion='2.0.2.1'}
    Import-DscResource -Module @{ModuleName='cFailoverCluster';ModuleVersion='1.2.1.6'}
    Import-DscResource -Module PSDesiredStateConfiguration
    
    Node $AllNodes.NodeName
    {
        # Set LCM to reboot if needed
        LocalConfigurationManager
        {
            DebugMode = 'All'
            ActionAfterReboot = 'StopConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }
        WindowsFeature 'NET-Framework-Core'
        {
            Ensure = 'Present'
            Name = 'NET-Framework-Core'
            Source = $node.windowssource
        }
        WindowsFeature 'Failover-Clustering'
        {
            Ensure = 'Present'
            Name = 'Failover-Clustering'
            IncludeAllSubFeature = $true
            Source = $node.windowssource
        }
        WindowsFeature 'RSAT-Clustering-PowerShell'
        {
            Ensure = 'Present'
            Name = 'RSAT-Clustering-PowerShell'
            Source = $node.windowssource
        }

        if ($Node.ClusterNode -eq 'Primary')
        {
            cCluster 'SQLCluster1'
            {
                DependsOn = @(
                '[WindowsFeature]Failover-Clustering',
                '[WindowsFeature]RSAT-Clustering-PowerShell'
                )
                Name = $Node.FailoverClusterNetworkName
                StaticIPAddress = $Node.FailoverClusterIPAddress
                DomainAdministratorCredential = $Node.InstallerServiceAccount
            }
            WaitForAll 'SQLCluster1'
            {
                ResourceName = '[cCluster]SQLCluster1'
                NodeName = $Node.AdditionalClusterNodes
                RetryIntervalSec = 5
                RetryCount = 720
            }
        }
        else
        {
            WaitForAll 'SQLCluster1'
            {
                ResourceName = '[cCluster]SQLCluster1'
                NodeName = $Node.PrimaryClusterNode
                RetryIntervalSec = 5
                RetryCount = 720
            }

            cWaitForCluster 'SQLCluster1'
            {
                DependsOn = '[WaitForAll]SQLCluster1'
                Name = $Node.FailoverClusterNetworkName
                RetryIntervalSec = 10
                RetryCount = 60
            }

            cCluster 'SQLCluster1'
            {
                DependsOn = '[cWaitForCluster]SQLCluster1'
                Name = $Node.FailoverClusterNetworkName
                StaticIPAddress = $Node.FailoverClusterIPAddress
                DomainAdministratorCredential = $Node.InstallerServiceAccount
            }
        }

        Foreach ($Instance in $Node.SQLInstances)
        {
            cSQLServerFailoverClusterSetup ('PrepareMSSQLSERVER' + $Instance.Name)
            {
            DependsOn = @(
                '[WindowsFeature]NET-Framework-Core',
                '[WindowsFeature]Failover-Clustering',
                '[cCluster]SQLCluster1'
            )
            Action = 'Prepare'
            SourcePath = $Node.SQLSourcePath
            SourceFolder = $Node.SQLSourceFolder
            SetupCredential = $Node.InstallerServiceAccount
            Features = $Node.SQLFeatures
            InstanceName = $Instance.Name
            FailoverClusterNetworkName = $Instance.SQLFailoverClusterNetwork
            SQLSvcAccount = $Node.SQLServiceAccount
            FailoverClusterIPAddress = $Node.FailoverClusterIPAddress
            SQLUserDBDir = $Instance.SQLUserDBDir
            SQLUserDBLogDir = $Instance.SQLUserDBLogDir
            SQLTempDBDir = $Instance.SQLTempDBDir
            SQLTempDBLogDir = $Instance.SQLTempDBLogDir
            SQLBackupDir = $Instance.SQLBackupDir
            UpdateSource = $Node.SQLUpdateSource
            Filestreamlevel = "3"
            }
            cSqlServerFirewall ('FirewallMSSQLSERVER' + $Instance.Name)
            {
            DependsOn = '[cSQLServerFailoverClusterSetup]PrepareMSSQLSERVER' + $Instance.Name
            SourcePath = $Node.SQLSourcePath
            SourceFolder = $Node.SQLSourceFolder
            InstanceName = $Instance.Name
            Features = $Node.SQLFeatures
            }

            if($Node.ClusterNode -eq 'Primary')
            {
                WaitForAll ('Cluster' + $Instance.Name)
                {
                    NodeName = $Node.AdditionalClusterNodes
                    ResourceName = '[cSQLServerFailoverClusterSetup]PrepareMSSQLSERVER' + $Instance.Name
                    RetryIntervalSec = 5
                    RetryCount = 720
                }
                cSQLServerFailoverClusterSetup ('CompleteMSSQLSERVER' + $Instance.Name)
                {
                    DependsOn = @(
                    '[WaitForAll]Cluster' + $Instance.Name
                    )
                    Action = 'Complete'
                    SourcePath = $Node.SQLSourcePath
                    SourceFolder = $Node.SQLSourceFolder
                    SetupCredential = $Node.InstallerServiceAccount
                    Features = $Node.SQLFeatures
                    InstanceName = $Instance.Name
                    FailoverClusterNetworkName = $Instance.SQLFailoverClusterNetwork
                    InstallSQLDataDir = $Instance.InstallSQLDataDir
                    ISFileSystemFolder = $Instance.ISFileSystemFolder
                    FailoverClusterIPAddress = $Instance.SQLClusterIPAddress
                    FailoverClusterGroup = $Instance.FailoverClusterGroup
                    SQLSvcAccount = $Node.SQLServiceAccount
                    SQLSysAdminAccounts = $Node.AdminAccount
                    ASSysAdminAccounts = $Node.AdminAccount
                    UpdateSource = $Node.SQLUpdateSource
                }
                cSqlHAService ('EnableSQLHA' + $Instance.Name)
                {
                    InstanceName = $Instance.Name
                    ServiceCredential = $Node.SQLServiceAccount
                    SQLAdministratorCredential = $Node.SQLAdministratorCredential
                    SQLServerName = $Instance.SQLFailoverClusterNetwork
                    PsDscRunAsCredential = $Node.DomainAdministratorCredential
                    DependsOn = '[cSQLServerFailoverClusterSetup]CompleteMSSQLSERVER' + $Instance.Name
                }
                WaitForAll ('ClusterHA' + $Instance.Name)
                {
                    NodeName = $Node.AdditionalClusterNodes
                    ResourceName = '[cSqlHAService]EnableSQLHA' + $Instance.Name
                    RetryIntervalSec = 5
                    RetryCount = 720
                }
                cSqlHAEndPoint ('ConfigureEndpoint' + $Instance.Name)
                {
                    InstanceName = $Instance.Name
                    AllowedUser = $Node.SQLServiceAccount.Username
                    Name = $Node.SQLEndpointName
                    PortNumber = $Node.SQLEndpointPort
                    SQLServerName = $Instance.SQLFailoverClusterNetwork
                    DependsOn = '[cSqlHAService]EnableSQLHA' + $Instance.Name
                    PsDscRunAsCredential = $Node.DomainAdministratorCredential
                }
                cClusterPreferredOwner ('ClusterPreferredOwner' + $Instance.Name)
                {
                    Clustername = $node.FailoverClusterNetworkName
                    Nodes = $Instance.InstanceNodes
                    ClusterGroup = $($Instance.FailoverClusterGroup)
                    ClusterResources = "*$($Instance.Name)*","*$($Instance.SQLFailoverClusterNetwork)*"
                    Ensure = 'Present'
                    PsDscRunAsCredential = $Node.DomainAdministratorCredential
                    DependsOn = '[cSqlHAEndPoint]ConfigureEndpoint' + $Instance.Name
                }

            }
            else
            {
                WaitForAll ('CompleteMSSQLSERVER' + $Instance.Name)
                {
                    ResourceName = '[cSQLServerFailoverClusterSetup]CompleteMSSQLSERVER' + $Instance.Name
                    NodeName = $Node.PrimaryClusterNode
                    RetryIntervalSec = 5
                    RetryCount = 720
                }
                WaitForAll ('ClusterHA' + $Instance.Name)
                {
                    NodeName = $Node.PrimaryClusterNode
                    ResourceName = '[cSqlHAService]EnableSQLHA' + $Instance.Name
                    RetryIntervalSec = 5
                    RetryCount = 720
                }
                cSqlHAService ('EnableSQLHA' + $Instance.Name)
                {
                    InstanceName = $Instance.Name
                    ServiceCredential = $Node.SQLServiceAccount
                    SQLAdministratorCredential = $Node.SQLAdministratorCredential
                    SQLServerName = $Instance.SQLFailoverClusterNetwork
                    PsDscRunAsCredential = $Node.DomainAdministratorCredential
                    DependsOn = '[WaitForAll]CompleteMSSQLSERVER' + $Instance.Name
                }
            }
        }

        if($Node.ClusterNode -eq 'Primary')
        {
            $lastinstance = $Node.SQLInstances.name | Select-Object -last 1
            
            cSqlAvailabilityGroup "$($Node.AvailabilityGroupName)"
            {
               AvailabilityGroupName     = $Node.AvailabilityGroupName
               PrimarySQLInstance        = $Node.PrimarySQLInstance
               SecondarySQLInstance      = $Node.SecondarySQLInstance
               AvailabilityGroupDatabase = $Node.AvailabilityGroupDatabase
               BackupDirectory           = $Node.BackupDirectory
               ListenerName              = $Node.ListenerName
               ListenerIpAddress         = $Node.ListenerIpAddress
               ListenerSubnetMask        = $Node.ListenerSubnetMask
               Force                     = $true
               PsDscRunAsCredential      = $Node.DomainAdministratorCredential
            }
        }
    }
}

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = '*'
            PSDscAllowPlainTextPassword   = $true
            Windowssource                 = '\\dc01\Data\sxs'

            DomainAdministratorCredential = $DomainAdministratorCredential
            SQLAdministratorCredential    = $DomainAdministratorCredential
            InstallerServiceAccount       = $InstallerServiceAccount
            SQLServiceAccount             = $SQLServiceAccount
            AdminAccount                  = 'DOMAIN\Administrator'
            FailoverClusterNetworkName    = 'CLUSTER'
            PrimaryClusterNode            = 'SQL1'
            AdditionalClusterNodes        = 'SQL2','SQL3','SQL4'
            AvailabilityGroupName         = 'CLUSTER-SAO1'
            AvailabilityGroupDatabase     = 'CLUSTER-SAO1-DB1'
            ListenerName                  = 'CLUSTER-SAOL1'
            ListenerIpAddress             = '192.168.10.33'
            ListenerSubnetMask            = '255.255.255.0'
            BackupDirectory               = '\\dc01\Data\SQLBackup'
            PrimarySQLInstance            = 'CLUSTER-SFCI1\Instance1'
            SecondarySQLInstance          = 'CLUSTER-SFCI2\Instance2'
            SQLInstances                  = @(
                                                @{
                                                    Name                      = 'Instance1'
                                                    SQLFailoverClusterNetwork = 'CLUSTER-SFCI1'
                                                    FailoverClusterGroup      = 'CLUSTER-SFCG1'
                                                    InstanceNodes             = 'SQL1','SQL2'
                                                    SQLClusterIPAddress       = '192.168.10.31'
                                                    InstallSQLDataDir         = 'X:\SQL'
                                                    ISFileSystemFolder        = 'X:\SQL\Packages'
                                                    SQLUserDBDir              = 'X:\SQL\User\Database'
                                                    SQLUserDBLogDir           = 'X:\SQL\User\Log'
                                                    SQLTempDBDir              = 'X:\SQL\Temp\Database'
                                                    SQLTempDBLogDir           = 'X:\SQL\Temp\Log'
                                                    SQLBackupDir              = 'X:\SQL\Backup'
                                                }
                                                @{
                                                    Name                      = 'Instance2'
                                                    SQLFailoverClusterNetwork = 'CLUSTER-SFCI2'
                                                    FailoverClusterGroup      = 'CLUSTER-SFCG2'
                                                    InstanceNodes             = 'SQL3','SQL4'
                                                    SQLClusterIPAddress       = '192.168.10.32'
                                                    InstallSQLDataDir         = 'Y:\SQL'
                                                    ISFileSystemFolder        = 'Y:\SQL\Packages'
                                                    SQLUserDBDir              = 'Y:\SQL\User\Database'
                                                    SQLUserDBLogDir           = 'Y:\SQL\User\Log'
                                                    SQLTempDBDir              = 'Y:\SQL\Temp\Database'
                                                    SQLTempDBLogDir           = 'Y:\SQL\Temp\Log'
                                                    SQLBackupDir              = 'Y:\SQL\Backup'                                                    
                                                }
                                            )
            FailoverClusterIPAddress      = '192.168.10.30'
            SQLEndpointName               = 'CLUSTER-SFCE1'
            SQLEndpointPort               = '5022'
            SQLSourcePath                 = '\\dc01\Data'
            SQLSourceFolder               = '\SQLServer\2014'
            SQLFeatures                   = 'SQLENGINE,SSMS'
            SQLUpdateSource               = '.\MU'

        }
        @{
            NodeName = 'SQL1'
            ClusterNode = 'Primary'
        }
        @{
            NodeName = 'SQL2'
            ClusterNode = 'Additional'
        }
        @{
            NodeName = 'SQL3'
            ClusterNode = 'Additional'
        }
        @{
            NodeName = 'SQL4'
            ClusterNode = 'Additional'
        }
    )
}

SQL_Cluster_Install -ConfigurationData $ConfigurationData -OutputPath 'C:\DSC\Staging\SQL_Cluster_Install'
$Computernames = 'SQL1', 'SQL2', 'SQL3', 'SQL4'
#Start-DscConfiguration -Path 'C:\DSC\Staging\SQL_Cluster_Install' -ComputerName 'SQL1' -Verbose -Wait -Force
#Start-DscConfiguration -Path 'C:\DSC\Staging\SQL_Cluster_Install' -ComputerName 'SQL2' -Verbose -Wait -Force
#Start-DscConfiguration -Path 'C:\DSC\Staging\SQL_Cluster_Install' -ComputerName 'SQL3' -Verbose -Wait -Force
#Start-DscConfiguration -Path 'C:\DSC\Staging\SQL_Cluster_Install' -ComputerName 'SQL4' -Verbose -Wait -Force
Start-DscConfiguration -Path 'C:\DSC\Staging\SQL_Cluster_Install' -ComputerName $Computernames -Verbose -Wait -Force