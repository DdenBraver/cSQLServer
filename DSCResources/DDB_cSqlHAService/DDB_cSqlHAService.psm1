#
# cSQLService: DSC resource to enable Sql High Availability (HA) service on the given sql instance.
#

function RestartSqlServer()
{
    $list = get-service | ? {$_.name -like "MSSQL$*" -or $_.name -like "SQLAgent$*"}
    foreach ($s in $list)
    {
        $tmp = Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
        sleep -Seconds 10 # wait for service to stop
        $tmp = Set-Service -Name $s.Name -StartupType Automatic -ErrorAction SilentlyContinue
        $tmp = Start-Service -Name $s.Name -ErrorAction SilentlyContinue
        sleep -Seconds 10 # wait for service to start
        if ((get-service -Name $s.Name -ErrorAction SilentlyContinue).status -eq "Stopped")
        { 
            Write-Warning -Message "service $($s.Name) still has the status stopped, this could be due to $env:computername not being the primary node"
        }
    }
}

function IsSQLLogin
{
     param
     (
         $Login,
         $Instancename,
         $SQLServerName
     )

    if ($Instancename -ne 'MSSQLSERVER')
    {
        $SQLServerName = $SQLServerName + '\' + $Instancename
    }

    $tmp = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $SQLServer = new-object ('Microsoft.SqlServer.Management.Smo.Server') $SQLServerName
	$query = ($SQLServer.Logins | Where-Object {$_.name -like "*$login*"}).DenyWindowsLogin
    if ($query.count -gt 0)
    {
        return ($query[0] -eq $false)
    }
    else 
    {
        return ($query -eq $false)
    }
}

function IsSrvRoleMember
{
     param
     (
         $Login,
         $Instancename,
         $SQLServerName
     )

     if ($Instancename -ne 'MSSQLSERVER')
     {
        $SQLServerName = $SQLServerName + '\' + $Instancename
     }

    $tmp = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $SQLServer = new-object ('Microsoft.SqlServer.Management.Smo.Server') $SQLServerName
	$query = ($SQLServer.Logins | Where-Object {$_.name -like "*$login*"})
    if ($query.count -gt 0)
    {
        $query = $query.Listmembers()
    }
    return ($query -contains 'sysadmin')
}

function IsHAEnabled
{
     param
     (
         $Instancename,
         $SQLServerName
     )

     if ($Instancename -ne 'MSSQLSERVER')
     {
        $SQLServerName = $SQLServerName + '\' + $Instancename
     }

	$tmp = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $SQLServer = new-object ('Microsoft.SqlServer.Management.Smo.Server') $SQLServerName
	[bool]$SQLServer.IsHadrEnabled
}

function Get-SqlServiceName 
{
     param
     (
         $InstanceName
     )

    $list = $InstanceName.Split('\')
    if ($list.Count -gt 1)
    {
        "MSSQL$" + $list[1]
    }
    else
    {
        'MSSQLSERVER'
    }
}

#
# The Get-TargetResource cmdlet.
#
function Get-TargetResource
{
    param
    (	
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $InstanceName,
	    
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $SqlAdministratorCredential, 
	    
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]$ServiceCredential,
        
        [string]$SQLServerName = 'localhost'
    )

    Write-Verbose -Message 'Get SQL Service configuration ...'

    $SAPassword = $SqlAdministratorCredential.GetNetworkCredential().Password
    $SAUser = $SqlAdministratorCredential.UserName
    $ServiceAccount = $ServiceCredential.UserName

    $bServiceAccountInSqlLogin = IsSQLLogin -Login $ServiceAccount -Instancename $InstanceName -SQLServerName $SQLServerName
    $bServiceAccountInSrvRole = IsSrvRoleMember -Login $ServiceCredential.UserName -Instancename $InstanceName -SQLServerName $SQLServerName
    $bSystemAccountInSrvRole = IsSrvRoleMember -Login 'NT AUTHORITY\SYSTEM' -Instancename $InstanceName -SQLServerName $SQLServerName
    $bHAEnabled = IsHAEnabled -Instancename $InstanceName -SQLServerName $SQLServerName

	return @{
        ServiceAccount = $ServiceAccount
        ServiceAccountInSqlLogin = $bServiceAccountInSqlLogin
        ServiceAccountInSrvRole = $bServiceAccountInSrvRole
        SystemAccountInSrvRole = $bSystemAccountInSrvRole
        HAEnabled = $bHAEnabled
    }
}

#
# The Set-TargetResource cmdlet.
#
function Set-TargetResource
{
    param
    (	
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $InstanceName,
	    
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $SqlAdministratorCredential, 
	    
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]$ServiceCredential,

        [string]$SQLServerName = 'localhost'
    )
    Write-Verbose -Message 'Loading SQL Assembly...'
    $tmp = [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
    $ServiceAccount = $ServiceCredential.UserName
    $ServicePassword = $ServiceCredential.GetNetworkCredential().Password

    Write-Verbose -Message 'Set SQL Service configuration...'

    if ($Instancename -ne 'MSSQLSERVER')
    {
        $SQLServerInstance = $SQLServerName + '\' + $Instancename
    }
    else
    {
        $SQLServerInstance = $SQLServerName
    }

    Write-Verbose -Message "SQL instance set to $SQLServerInstance..."

    $bCheck = IsSQLLogin -Login $ServiceAccount -Instancename $InstanceName -SQLServerName $SQLServerName
    if ($bCheck -ne $true)
    {
        Write-Verbose -Message "Create Login [$ServiceAccount] From Windows"
        $SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $SQLServerInstance, "$ServiceAccount"
        $SqlUser.LoginType = 'WindowsUser'
        $SqlUser.Create()
        $SqlUser.AddToRole('sysadmin')
    }
    else
    {
        Write-Verbose -Message "Login [$ServiceAccount] From Windows is set correctly"
    }

    $bCheck = IsSrvRoleMember -Login $ServiceCredential.UserName -Instancename $InstanceName -SQLServerName $SQLServerName
    if ($bCheck -ne $true)
    {
        Write-Verbose -Message "Adding Login [$ServiceAccount] to Sysadmins"
        $SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $SQLServerInstance, "$ServiceAccount"
        $SqlUser.AddToRole('sysadmin')
    }
    else
    {
        Write-Verbose -Message "Login [$ServiceAccount] is already a member of Sysadmins"
    }

    $bCheck = IsSrvRoleMember -Login 'NT AUTHORITY\SYSTEM' -Instancename $InstanceName -SQLServerName $SQLServerName
    if ($bCheck -ne $true)
    {
        Write-Verbose -Message "Adding Login [NT AUTHORITY\SYSTEM] to Sysadmins"
        $SqlUser = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Login -ArgumentList $SQLServerInstance, 'NT AUTHORITY\SYSTEM'
        $SqlUser.AddToRole('sysadmin')
    }
    else
    {
        Write-Verbose -Message "Login [NT AUTHORITY\SYSTEM] is already a member of Sysadmins"
    }
        
    Write-Verbose -Message "Restarting SQL Server services $servicename for permissioning"
    $tmp = RestartSqlServer

    $bCheck = IsHAEnabled -Instancename $InstanceName -SQLServerName $SQLServerName
    if ($bCheck -ne $true)
    {
        Write-Verbose -Message "Enabling SQLHADR for $SQLServerInstance"
        $tmp = Enable-SqlAlwaysOn -ServerInstance $SQLServerInstance -Force
        Write-Verbose -Message "Restarting SQL Server services $servicename for SQL Always On"
        $tmp = RestartSqlServer
        sleep -seconds 10 # wait for service to become available
    }
    else
    {
        Write-Verbose -Message "SQLHADR for $SQLServerInstance has already been enabled"
    }
}

#
# The Test-TargetResource cmdlet.
#
function Test-TargetResource
{
    param
    (	
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $InstanceName,
	    
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential] $SqlAdministratorCredential, 
	    
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]$ServiceCredential,

        [string]$SQLServerName = 'localhost'
    )

    Write-Verbose -Message 'Test SQL Service configuration ...'

    $ServiceAccount = $ServiceCredential.UserName

    $ret = IsSQLLogin -Login $ServiceAccount -Instancename $InstanceName -SQLServerName $SQLServerName
    if ($ret -eq $false)
    {
        Write-Verbose -Message "$ServiceAccount is NOT in SqlServer login"
        return $false
    }
    else
    {
        Write-Verbose -Message "Login [$ServiceAccount] From Windows is set correctly"
    }

    $ret = IsSrvRoleMember -Login $ServiceAccount -Instancename $InstanceName -SQLServerName $SQLServerName
    if ($ret -eq $false)
    {
        Write-Verbose -Message "$ServiceAccount is NOT in admin role"
        return $false
    }
    else
    {
        Write-Verbose -Message "Login [$ServiceAccount] is already a member of Sysadmins"
    }

    $ret = IsSrvRoleMember -Login 'NT AUTHORITY\SYSTEM' -Instancename $InstanceName -SQLServerName $SQLServerName
    if ($ret -eq $false)
    {
        Write-Verbose -Message 'NT AUTHORITY\SYSTEM is NOT in admin role'
        return $false
    }
    else
    {
        Write-Verbose -Message "Login [NT AUTHORITY\SYSTEM] is already a member of Sysadmins"
    }

    $ret = IsHAEnabled -Instancename $InstanceName -SQLServerName $SQLServerName
    if ($ret -eq $false)
    {
        Write-Verbose -Message "$InstanceName does NOT enable SQL HA."
        return $false
    }
    else
    {
        Write-Verbose -Message "SQLHADR for $InstanceName has already been enabled"
    }

    return $ret
}

Export-ModuleMember -Function *-TargetResource