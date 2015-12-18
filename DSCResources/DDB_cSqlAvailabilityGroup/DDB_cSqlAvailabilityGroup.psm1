#region helper functions
#--------------------------------------
# Helper Scripts
#--------------------------------------
function Get-SQLAvailabilityGroupData
{
    param (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrimarySQLInstance,
        
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SecondarySQLInstance
    )

    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SmoExtended')
    
    $SqlServerPrim = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($PrimarySQLInstance)
    $SqlServerSec = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($SecondarySQLInstance)

    Write-Verbose -Message 'Retrieving Availability Group Information'

    $availabilitygroups = @(
    $SqlServerPrim.AvailabilityGroups.name
    $SqlServerSec.AvailabilityGroups.name
    )

    $Listeners = @(
    $SqlServerPrim.AvailabilityGroups.availabilitygrouplisteners.Name
    $SqlServerSec.AvailabilityGroups.availabilitygrouplisteners.Name
    )

    return @{
     Availabilitygroup = $availabilitygroups | Sort-Object -Unique
     Listener = $Listeners | Sort-Object -Unique
    }
}

function Get-SQLDatabases
{
    param (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrimarySQLInstance,
        
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SecondarySQLInstance
    )

    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SmoExtended')

    $SqlServerPrim = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($PrimarySQLInstance)
    $SqlServerSec = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($SecondarySQLInstance)

    Write-Verbose -Message 'Retrieving SQL Databases'
    $databases = @(
    $SqlServerPrim.Databases.name | Where-Object {$_ -ne 'master' -and $_ -ne 'model' -and $_ -ne 'msdb' -and $_ -ne 'tempdb'}
    $SqlServerSec.Databases.name | Where-Object {$_ -ne 'master' -and $_ -ne 'model' -and $_ -ne 'msdb' -and $_ -ne 'tempdb'}
    )

    return $databases | Sort-Object -Unique    
}

function Remove-SQLAvailabilitygroup
{
    param (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrimarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupName,

        [string] $ListenerName
    )

    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SmoExtended')

    $SqlServerPrim = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($PrimarySQLInstance)
    if ($ListenerName)
    {
        Write-Warning "Removing Always-On Listener $ListenerName"
        $listenerobject = $SqlServerPrim.AvailabilityGroups.availabilitygrouplisteners | Where-Object {$_.name -eq $ListenerName}
        try
        {
        $listenerobject.drop()
        }
        catch{}
    }

    Write-Warning "Removing Always-On Availability Group $AvailabilityGroupName"
    $Availabilitygroupobject = $SqlServerPrim.AvailabilityGroups | Where-Object {$_.name -eq $AvailabilityGroupName}
    try
    {
        $Availabilitygroupobject.drop()
    }
    catch{}
}

function Remove-SQLInitialDatabase
{
    param (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrimarySQLInstance,
        
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SecondarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupDatabase
    )

    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SmoExtended')
    
    $SqlServerPrim = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($PrimarySQLInstance)
    $SqlServerSec = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($SecondarySQLInstance)

    Write-Verbose -Message "Removing Database: $AvailabilityGroupDatabase from $SecondarySQLInstance"
    $secdbobject = $SqlServerSec.Databases | Where-Object {$_.name -eq $AvailabilityGroupDatabase}
    try
    {
        $secdbobject.drop()
    }
    catch{}

    Start-Sleep -Seconds 5

    Write-Verbose -Message "Removing Database: $AvailabilityGroupDatabase from $PrimarySQLInstance"
    $primdbobject = $SqlServerPrim.Databases | Where-Object {$_.name -eq $AvailabilityGroupDatabase}
    try
    {
        $primdbobject.drop()
    }
    catch{}
}

function New-SQLInitialDatabase
{
    param (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrimarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupDatabase
    )

    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SmoExtended')
    
    $SqlServerPrim = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($PrimarySQLInstance)

    Write-Verbose -Message "Creating: Database: $AvailabilityGroupDatabase on SQL Instance: $PrimarySQLInstance"
    $AGDatabase = New-Object Microsoft.SqlServer.Management.Smo.Database($SqlServerPrim, $AvailabilityGroupDatabase)
    $AGDatabase.Create()
}

function New-SQLDatabaseBackup
{
    param (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrimarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupDatabase,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $BackupDirectory
    )

    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SmoExtended')
    
    $SqlServerPrim = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($PrimarySQLInstance)

    # backup the database (full database backup)
    Write-Verbose -Message 'Creating: Full Database Backup'
    $DbBackup = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Backup
    $DbBackup.Database = $AvailabilityGroupDatabase
    $DbBackup.Action = [Microsoft.SqlServer.Management.Smo.BackupActionType]::Database
    $DbBackup.Initialize = $True
    $DbBackup.Devices.AddDevice("$BackupDirectory\$($AvailabilityGroupDatabase)_AgSetup_full.bak", 
    [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
    $DbBackup.SqlBackup($SqlServerPrim)

    # backup the database (transaction log backup)
    Write-Verbose -Message 'Creating: Transaction Log Backup'
    $DbBackup = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Backup
    $DbBackup.Database = $AvailabilityGroupDatabase
    $DbBackup.Action = [Microsoft.SqlServer.Management.Smo.BackupActionType]::Log
    $DbBackup.Initialize = $True
    $DbBackup.Devices.AddDevice("$BackupDirectory\$($AvailabilityGroupDatabase)_AgSetup_log.trn", 
    [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
    $DbBackup.SqlBackup($SqlServerPrim)
}

function Restore-SQLDatabaseBackup
{
    param (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SecondarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupDatabase,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $BackupDirectory
    )

    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SmoExtended')
    
    $SqlServerSec = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($SecondarySQLInstance)

    $sqlsecdatafolder = $SqlServerSec.settings.DefaultFile
    $sqlseclogfolder = $SqlServerSec.settings.DefaultLog

    # restore the database (full database restore)
    Write-Verbose -Message 'Starting: Full Database Restore' -Verbose
    $DbRestore = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Restore
    $DbRestore.Database = $AvailabilityGroupDatabase
    $DbRestore.Action = [Microsoft.SqlServer.Management.Smo.RestoreActionType]::Database
    $DbRestore.Devices.AddDevice("$BackupDirectory\$($AvailabilityGroupDatabase)_AgSetup_full.bak", 
    [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
    $DbRestore.NoRecovery = $True
    foreach ($file in $DbRestore.ReadFileList($SqlServerSec))
    {
        $relocatefile = New-Object 'Microsoft.SqlServer.Management.Smo.RelocateFile'
        $relocatefile.LogicalFileName = $file.LogicalName
        if ($file.Type -eq 'D'){
            if ($datafilenumber -ge 1)
            {
                $suffix = "_$dataFileNumber"
            }
            else
            {
                $suffix = $null
            }
            $relocatefile.PhysicalFileName = "$sqlsecdatafolder\$AvailabilityGroupDatabase$suffix.mdf"
            $dataFileNumber++
        }
        else
        {
            $relocatefile.PhysicalFileName = "$sqlseclogfolder\$AvailabilityGroupDatabase.ldf"
        }
        $tmp = $DbRestore.RelocateFiles.Add($relocatefile)
    }
    $DbRestore.SqlRestore($SqlServerSec)

    # restore the database (transaction log restore)
    Write-Verbose -Message 'Starting: Transaction Log Restore' -Verbose
    $DbRestore = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Restore
    $DbRestore.Database = $AvailabilityGroupDatabase
    $DbRestore.Action = [Microsoft.SqlServer.Management.Smo.RestoreActionType]::Log
    $DbRestore.Devices.AddDevice("$BackupDirectory\$($AvailabilityGroupDatabase)_AgSetup_log.trn", 
    [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
    $DbRestore.NoRecovery = $True
    $DbRestore.SqlRestore($SqlServerSec)
}

function New-SQLAvailabilityGroup
{
    param (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrimarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SecondarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupDatabase,

        [Int32] $SQLEndpointPort = '5022',

        [string] $ListenerName,

        [Int32] $ListenerPort = '1433',

        [string] $ListenerIpAddress,

        [string] $ListenerSubnetMask,

        [ValidateSet("Automatic", "Manual")]
		[String] $ReplicaFailoverMode = "Manual",

        [ValidateSet("AsynchronousCommit", "SynchronousCommit")]
		[String] $ReplicaAvailabilityMode = "SynchronousCommit"
    )

    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $null = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SmoExtended')
    
    $SqlServerPrim = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($PrimarySQLInstance)
    $SqlServerSec = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList ($SecondarySQLInstance)

    # create replica group object
    $AvailabilityGroup = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityGroup -ArgumentList ($SqlServerPrim, $AvailabilityGroupName)

    # create the primary replica object
    Write-Verbose -Message "Creating: Replica Object for $PrimarySQLInstance" -Verbose
    $PrimaryReplica = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica -ArgumentList ($AvailabilityGroup, $PrimarySQLInstance)
    $PrimaryReplica.EndpointUrl = "TCP://$($SqlServerPrim.NetName):$SQLEndpointPort"
    $PrimaryReplica.FailoverMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaFailoverMode]::$ReplicaFailoverMode
    $PrimaryReplica.AvailabilityMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaAvailabilityMode]::$ReplicaAvailabilityMode
    $AvailabilityGroup.AvailabilityReplicas.Add($PrimaryReplica)

    # create the secondary replica object
    Write-Verbose -Message "Creating: Replica Object for $SecondarySQLInstance" -Verbose
    $SecondaryReplica = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityReplica -ArgumentList ($AvailabilityGroup, $SecondarySQLInstance)
    $SecondaryReplica.EndpointUrl = "TCP://$($SqlServerSec.NetName):$SQLEndpointPort"
    $SecondaryReplica.FailoverMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaFailoverMode]::$ReplicaFailoverMode
    $SecondaryReplica.AvailabilityMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaAvailabilityMode]::$ReplicaAvailabilityMode
    $AvailabilityGroup.AvailabilityReplicas.Add($SecondaryReplica)

    # create the availability group database object
    Write-Verbose -Message 'Creating: Availability group Database object' -Verbose
    $AvailabilityDb = New-Object -TypeName Microsoft.SqlServer.Management.Smo.AvailabilityDatabase -ArgumentList ($AvailabilityGroup, $AvailabilityGroupDatabase)
    $AvailabilityGroup.AvailabilityDatabases.Add($AvailabilityDb)

    if ($ListenerName)
    {
        # create availability group listener object
        Write-Verbose -Message "Creating: Availability group Listener $ListenerName" -Verbose
        $AgListener = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityGroupListener($AvailabilityGroup, $ListenerName)
        $AgListenerIp = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityGroupListenerIPAddress($AgListener)
        $AgListener.PortNumber = $ListenerPort
        $AgListenerIp.IsDHCP = $false
        $AgListenerIp.IPAddress = $ListenerIpAddress
        $AgListenerIp.SubnetMask = $ListenerSubnetMask
        $AgListener.AvailabilityGroupListenerIPAddresses.Add($AgListenerIp)
        $AvailabilityGroup.AvailabilityGroupListeners.Add($AgListener)
    }

    # Create the availability group
    Write-Verbose -Message 'Creating: Availability group' -Verbose
    $SqlServerPrim.AvailabilityGroups.Add($AvailabilityGroup)
    $AvailabilityGroup.Create()

    # On the secondary Instance join the Replica to the Availability Group and join the database to the Availability Group
    Write-Verbose -Message "Joining: $SecondarySQLInstance to the Availability group" -Verbose
    $SqlServerSec.JoinAvailabilityGroup($AvailabilityGroupName)
    $SqlServerSec.AvailabilityGroups[$AvailabilityGroupName].AvailabilityDatabases[$AvailabilityGroupDatabase].JoinAvailablityGroup()
}

function Add-SQLListener
{
    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrimarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ListenerName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Int32] $ListenerPort = '1433',

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ListenerIpAddress = '192.168.10.25',

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ListenerSubnetMask = '255.255.255.0'
    )

    Write-Verbose -Message "Creating SQL Listener $ListenerName for Availability Group $AvailabilityGroupName"
    Invoke-Sqlcmd -Query "ALTER AVAILABILITY GROUP [$AvailabilityGroupName]
    ADD LISTENER N'$ListenerName' (
    WITH IP
    ((N'$ListenerIpAddress', N'$ListenerSubnetMask')
    )
    , PORT=$ListenerPort);" -ServerInstance $PrimarySQLInstance
}

#endregion

#------------------------------
# The Get-TargetResource cmdlet
#------------------------------
FUNCTION Get-TargetResource
{  
    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrimarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SecondarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupDatabase,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $BackupDirectory,

        [Int32] $SQLEndpointPort = 5022,
        
        [string] $ListenerName,
        
        [Int32] $ListenerPort = 1433,

        [string] $ListenerIpAddress,

        [string] $ListenerSubnetMask,

        [bool] $Force = $false,

        [ValidateSet("Automatic", "Manual")]
		[String] $ReplicaFailoverMode = "Manual",

        [ValidateSet("AsynchronousCommit", "SynchronousCommit")]
		[String] $ReplicaAvailabilityMode = "SynchronousCommit"
    )

    $AGData = Get-SQLAvailabilityGroupData -PrimarySQLInstance $PrimarySQLInstance -SecondarySQLInstance $SecondarySQLInstance
    $DBData = Get-SQLDatabases -PrimarySQLInstance $PrimarySQLInstance -SecondarySQLInstance $SecondarySQLInstance

    $result = @{
        AvailabilityGroup = $AGData.Availabilitygroup
        Listener = $AGData.Listener
        Databases = $DBData
        Force = $Force
    }

    return $result
}

#------------------------------
# The Set-TargetResource cmdlet
#------------------------------
FUNCTION Set-TargetResource
{  
    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrimarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SecondarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupDatabase,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $BackupDirectory,

        [Int32] $SQLEndpointPort = 5022,
        
        [string] $ListenerName,
        
        [Int32] $ListenerPort = 1433,

        [string] $ListenerIpAddress,

        [string] $ListenerSubnetMask,

        [bool] $Force = $false,

        [ValidateSet("Automatic", "Manual")]
		[String] $ReplicaFailoverMode = "Manual",

        [ValidateSet("AsynchronousCommit", "SynchronousCommit")]
		[String] $ReplicaAvailabilityMode = "SynchronousCommit"
    )
    
    if ($Force)
    {
        Write-Warning 'Force flag was set! Initiating Cleanup!'
        Remove-SqlAvailabilityGroup -PrimarySQLInstance $PrimarySQLInstance -AvailabilityGroupName $AvailabilityGroupName -ListenerName $ListenerName
        Remove-SQLInitialDatabase -PrimarySQLInstance $PrimarySQLInstance -SecondarySQLInstance $SecondarySQLInstance -AvailabilityGroupDatabase $AvailabilityGroupDatabase
    }

    $testset = Get-TargetResource @PSBoundParameters
    if (!$testset.Databases -contains $AvailabilityGroupDatabase)
    {
        Write-Verbose -Message "Database $AvailabilityGroupDatabase was NOT found"
        New-SQLInitialDatabase -PrimarySQLInstance $PrimarySQLInstance -AvailabilityGroupDatabase $AvailabilityGroupDatabase
        New-SQLDatabaseBackup -PrimarySQLInstance $PrimarySQLInstance -AvailabilityGroupDatabase $AvailabilityGroupDatabase -BackupDirectory $BackupDirectory
        Restore-SQLDatabaseBackup -SecondarySQLInstance $SecondarySQLInstance -AvailabilityGroupDatabase $AvailabilityGroupDatabase -BackupDirectory $BackupDirectory
    }
    else
    {
        Write-Verbose -Message "Database $AvailabilityGroupDatabase WAS found"
    }

    $testset = Get-TargetResource @PSBoundParameters
    if (!$testset.AvailabilityGroup -contains $AvailabilityGroupName)
    {
        Write-Verbose -Message "AvailabilityGroup $AvailabilityGroupName was NOT found"
        New-SQLAvailabilityGroup -PrimarySQLInstance $PrimarySQLInstance -SecondarySQLInstance $SecondarySQLInstance -AvailabilityGroupName $AvailabilityGroupName -AvailabilityGroupDatabase $AvailabilityGroupDatabase -SQLEndpointPort $SQLEndpointPort -ListenerName $ListenerName -ListenerPort $ListenerPort -ListenerIpAddress $ListenerIpAddress -ListenerSubnetMask $ListenerSubnetMask -ReplicaFailoverMode $ReplicaFailoverMode -ReplicaAvailabilityMode $ReplicaAvailabilityMode
    }
    else
    {
        Write-Verbose -Message "AvailabilityGroup $AvailabilityGroupName WAS found"
    }

    if ($ListenerName)
    {
        $testset = Get-TargetResource @PSBoundParameters
        if (!$testset.Listener -contains $ListenerName)
        {
            Write-Verbose -Message "Listener $ListenerName was NOT found"
            Add-SQLListener -PrimarySQLInstance $PrimarySQLInstance -AvailabilityGroupName $AvailabilityGroupName -ListenerName $ListenerName -ListenerPort $ListenerPort -ListenerIpAddress $ListenerIpAddress -ListenerSubnetMask $ListenerSubnetMask
        }
        else
        {
            Write-Verbose -Message "Listener $ListenerName WAS found"
        }
    }
}

#------------------------------
# The Test-TargetResource cmdlet
#------------------------------
FUNCTION Test-TargetResource
{ 
    param(
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $PrimarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SecondarySQLInstance,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupName,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $AvailabilityGroupDatabase,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $BackupDirectory,

        [Int32] $SQLEndpointPort = 5022,
        
        [string] $ListenerName,
        
        [Int32] $ListenerPort = 1433,

        [string] $ListenerIpAddress,

        [string] $ListenerSubnetMask,

        [bool] $Force = $false,

        [ValidateSet("Automatic", "Manual")]
		[String] $ReplicaFailoverMode = "Manual",

        [ValidateSet("AsynchronousCommit", "SynchronousCommit")]
		[String] $ReplicaAvailabilityMode = "SynchronousCommit"
    )
    
    $result = $true

    $testset = Get-TargetResource @PSBoundParameters

    if (!$testset.Databases -contains $AvailabilityGroupDatabase)
    {
        Write-Verbose -Message "Database $AvailabilityGroupDatabase was NOT found"
        $result = $false
    }

    if (!$testset.AvailabilityGroup -contains $AvailabilityGroupName)
    {
        Write-Verbose -Message "Database $AvailabilityGroupDatabase was NOT found"
        $result = $false
    }

    if ($ListenerName)
    {
        if (!$testset.Listener -contains $ListenerName)
        {
            Write-Verbose -Message "Listener $ListenerName was NOT found"
            $result = $false
        }
    }

    return [bool]$result

}