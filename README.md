# cSQLServer

The **cSQLServer** This is a custom module build by combining the MS Released xSQLServer and xSqlPs, then adding some additional resources.
This resource is fully compatible for building a SQL Stand-Alone with Always On, and SQL Cluster with Always On.

## Contributing
Please check out common DSC Resources [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).

## Resources

* **cSQLServerSetup** installs a standalone SQL Server instance
* **cSQLServerFirewall** configures firewall settings to allow remote access to a SQL Server instance.
* **cSQLServerRSSecureConnectionLevel** sets the secure connection level for SQL Server Reporting Services.
* **cSQLServerFailoverClusterSetup** installs SQL Server failover cluster instances.
* **cSQLServerRSConfig** configures SQL Server Reporting Services to use a database engine in another instance.
* **cSqlHAService** enables SQL high availability (HA) service on a given SQL instance. 
* **cSqlHAEndpoint** configures the given instance of SQL high availability service to a port (default 5022) with given name, and assigns users that are allowed to communicate through the SQL endpoint. 
* **cSqlAvailabilityGroup**configures an SQL AvailabilityGroup group with or without listener. If the AvailabilityGroup group or listener does not exist it will create one with the given name on given SQL instance and add the given database(s) to the SQL instance. If the database does not exist it will create one, make a backup, restores it on the other instance and adds it to the Availability Group.
* **cWaitforSqlHAService** waits for an SQL HA service to be ready by checking if HA is enabled in a given interval till either the HA service is enabled or the number of retries reached its maximum.  

### cSQLServerSetup

* **SourcePath**: (Required) UNC path to the root of the source files for installation.
* **SourceFolder**: Folder within the source path containing the source files for installation.
* **SetupCredential**: (Required) Credential to be used to perform the installation.
* **Features**: (Key) SQL features to be installed.
* **InstanceName**: (Key) SQL instance to be installed.
* **InstanceID**: SQL instance ID, if different from InstanceName.
* **PID**: Product key for licensed installations.
* **UpdateEnabled**: Enabled updates during installation.
* **UpdateSource**: Source of updates to be applied during installation.
* **SQMReporting**: Enable customer experience reporting.
* **ErrorReporting**: Enable error reporting.
* **InstallSharedDir**: Installation path for shared SQL files.
* **InstallSharedWOWDir**: Installation path for x86 shared SQL files.
* **InstanceDir**: Installation path for SQL instance files.
* **SQLSvcAccount**: Service account for the SQL service.
* **SQLSvcAccountUsername**: Output user name for the SQL service.
* **AgtSvcAccount**: Service account for the SQL Agent service.
* **AgtSvcAccountUsername**: Output user name for the SQL Agent service.
* **SQLCollation**: Collation for SQL.
* **SQLSysAdminAccounts**: Array of accounts to be made SQL administrators.
* **SecurityMode**: SQL security mode.
* **SAPwd**: SA password, if SecurityMode=SQL.
* **InstallSQLDataDir**: Root path for SQL database files.
* **SQLUserDBDir**: Path for SQL database files.
* **SQLUserDBLogDir**: Path for SQL log files.
* **SQLTempDBDir**: Path for SQL TempDB files.
* **SQLTempDBLogDir**: Path for SQL TempDB log files.
* **SQLBackupDir**: Path for SQL backup files.
* **FTSvcAccount**: Service account for the Full Text service.
* **FTSvcAccountUsername**: Output username for the Full Text service.
* **RSSvcAccount**: Service account for Reporting Services service.
* **RSSvcAccountUsername**: Output username for the Reporting Services service.
* **ASSvcAccount**: Service account for Analysus Services service.
* **ASSvcAccountUsername**: Output username for the Analysis Services service.
* **ASCollation**: Collation for Analysis Services.
* **ASSysAdminAccounts**: Array of accounts to be made Analysis Services admins.
* **ASDataDir**: Path for Analysis Services data files.
* **ASLogDir**: Path for Analysis Services log files.
* **ASBackupDir**: Path for Analysis Services backup files.
* **ASTempDir**: Path for Analysis Services temp files.
* **ASConfigDir**: Path for Analysis Services config.
* **ISSvcAccount**: Service account for Integration Services service.
* **ISSvcAccountUsername**: Output user name for the Integration Services service.

### cSQLServerFirewall

* **Ensure**: (Key) Ensures that SQL firewall rules are **Present** or **Absent** on the machine.
* **SourcePath**: (Required) UNC path to the root of the source files for installation.
* **SourceFolder**: Folder within the source path containing the source files for installation.
* **Features**: (Key) SQL features to enable firewall rules for.
* **InstanceName**: (Key) SQL instance to enable firewall rules for.
* **DatabaseEngineFirewall**: Is the firewall rule for the Database Engine enabled?
* **BrowserFirewall**: Is the firewall rule for the Browser enabled?
* **ReportingServicesFirewall**: Is the firewall rule for Reporting Services enabled?
* **AnalysisServicesFirewall**: Is the firewall rule for Analysis Services enabled?
* **IntegrationServicesFirewall**: Is the firewall rule for the Integration Services enabled?

### cSQLServerRSSecureConnectionLevel

* **InstanceName**: (Key) SQL instance to set secure connection level for.
* **SecureConnectionLevel**: (Key) SQL Server Reporting Service secure connection level.
* **Credential**: (Required) Credential with administrative permissions to the SQL instance.

### cSQLServerFailoverClusterSetup

* **Action**: (Key) { Prepare | Complete }
* **SourcePath**: (Required) UNC path to the root of the source files for installation.
* **SourceFolder**: Folder within the source path containing the source files for installation.
* **Credential**: (Required) Credential to be used to perform the installation.
* **Features**: (Required) SQL features to be installed.
* **InstanceName**: (Key) SQL instance to be installed.
* **InstanceID**: SQL instance ID, if different from InstanceName.
* **PID**: Product key for licensed installations.
* **UpdateEnabled**: Enabled updates during installation.
* **UpdateSource**: Source of updates to be applied during installation.
* **SQMReporting**: Enable customer experience reporting.
* **ErrorReporting**: Enable error reporting.
* **FailoverClusterGroup**: Name of the resource group to be used for the SQL Server failover cluster.
* **FailoverClusterNetworkName**: (Required) Network name for the SQL Server failover cluster.
* **FailoverClusterIPAddress**: IPv4 address for the SQL Server failover cluster.
* **InstallSharedDir**: Installation path for shared SQL files.
* **InstallSharedWOWDir**: Installation path for x86 shared SQL files.
* **InstanceDir**: Installation path for SQL instance files.
* **SQLSvcAccount**: Service account for the SQL service.
* **SQLSvcAccountUsername**: Output user name for the SQL service.
* **AgtSvcAccount**: Service account for the SQL Agent service.
* **AgtSvcAccountUsername**: Output user name for the SQL Agent service.
* **SQLCollation**: Collation for SQL.
* **SQLSysAdminAccounts**: Array of accounts to be made SQL administrators.
* **SecurityMode**: SQL security mode.
* **SAPwd**: SA password, if SecurityMode=SQL.
* **InstallSQLDataDir**: Root path for SQL database files.
* **SQLUserDBDir**: Path for SQL database files.
* **SQLUserDBLogDir**: Path for SQL log files.
* **SQLTempDBDir**: Path for SQL TempDB files.
* **SQLTempDBLogDir**: Path for SQL TempDB log files.
* **SQLBackupDir**: Path for SQL backup files.
* **ASSvcAccount**: Service account for Analysis Services service.
* **ASSvcAccountUsername**: Output user name for the Analysis Services service.
* **ASCollation**: Collation for Analysis Services.
* **ASSysAdminAccounts**: Array of accounts to be made Analysis Services admins.
* **ASDataDir**: Path for Analysis Services data files.
* **ASLogDir**: Path for Analysis Services log files.
* **ASBackupDir**: Path for Analysis Services backup files.
* **ASTempDir**: Path for Analysis Services temp files.
* **ASConfigDir**: Path for Analysis Services config.
* **ISSvcAccount**: Service account for Integration Services service.
* **ISSvcAccountUsername**: Output user name for the Integration Services service.
* **ISFileSystemFolder**: File system folder for Integration Services.

### cSQLServerRSConfig

* **InstanceName**: (Key) Name of the SQL Server Reporting Services instance to be configured.
* **RSSQLServer**: (Required) Name of the SQL Server to host the Reporting Service database.
* **RSSQLInstanceName**: (Required) Name of the SQL Server instance to host the Reporting Service database.
* **SQLAdminCredential**: (Required) Credential to be used to perform the configuration.
* **IsInitialized**: Output is the Reporting Services instance initialized.

### cSqlHAService

* **InstanceName**: The name of the SQL instance.
* **SqlAdministratorCredential**: Credential of the SQL Administrator account, this can be SA or a domain credential.
* **ServiceCredential**: Domain credential used to run SQL Service.
* **SQLServerName**: SQL Server or Cluster DNS name

### cSqlHAEndpoint

* **InstanceName**: The name of the SQL instance.
* **AllowedUser**: Unique name for HA database mirroring endpoint of the SQL instance.
* **Name**: Unique name for HA database mirroring endpoint of the sql instance.
* **PortNumber**: The single port number (####) on which the SQL HA to listen to.
* **SQLServerName**: SQL Server or Cluster DNS name

### cSqlAvailabilityGroup

* **Name**: Name of the SQL HA Availability Group
* **PrimarySQLInstance**: SQL Primary Instance
* **SecondarySQLInstance**: SQL Secondary Instance
* **AvailabilityGroupDatabase**: Database used to building the Availability Group
* **BackupDirectory**: Database Backup Directory
* **SQLEndpointPort**: Endpoint Port number
* **ListenerName**: SQL Listener name
* **ListenerPort**: SQL Listener portnumber
* **ListenerIpAddress**: SQL Listener IP Address
* **ListenerSubnetMask**: SQL Listener Subnet Mask
* **ReplicaFailoverMode**: Sets the Replica Failover Mode, default "Manual", options "Automatic", "Manual"
* **ReplicaAvailabilityMode**: Sets the Replica Availability Mode, default "SynchronousCommit, options "AsynchronousCommit", "SynchronousCommit"
* **Force**: Force recover switch, if at any time the database (at both locations), listener or availability group is not available or is faulty, it will remove them and reapply them properly. Only recommended for testing or lab environments!


### cWaitforSqlHAService

* **Name**: The name of SQL High Availability Group.
* **ClusterName**: The name of Windows failover cluster for the availability group.
* **RetryIntervalSec**: Interval to check the HA group existency.
* **RetryCount**: Maximum number of retries to check HA group existency.
* **InstanceName**: The name of SQL instance.
* **DomainCredential**: Domain credential could get list of cluster nodes.
* **SqlAdministratorCredential**: SQL Server Administrator credential .

## Versions

### 2.0.3.1
* Added force switch to cSqlAvailabilityGroup as "cleanup and fix" function to enforce a proper state. Only recommended for testing or lab environments!
* Minor bugfixes in scripts, added verbose to some additional parts.

### 2.0.3.0
* New Resource: cSQLAvailabilityGroup

### 2.0.2.0
* New Resource: cWaitforSqlHAService

### 2.0.1.0
* New Resource: cSQLHAService

### 2.0.0.0
* Merged xSQLServer 1.3.0.0 and xSqlPs 1.1.3.1 and removed all SQL HA Parts that were using OSQL.
* cSQLHAEndpoint edited to use invoke-sqlcmd
* Added SQL Filestreaming as an option for cSQLServerSetup and cSQLServerFailoverClusterSetup
* Added additional minor fixes to the install resources.

## Examples

Examples for use of this resource can be found in the Examples folder