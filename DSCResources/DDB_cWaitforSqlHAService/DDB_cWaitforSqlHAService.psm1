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
    $SQLServer = New-Object ('Microsoft.SqlServer.Management.Smo.Server') $SQLServerName
    [bool]$SQLServer.IsHadrEnabled
}

function Get-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Instancename,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SQLServerName,

        [UInt64] $RetryIntervalSec = 10,

        [UInt32] $RetryCount = 10
    )

    $Query = IsHAEnabled -Instancename $Instancename -SQLServerName $SQLServerName

    $returnValue = @{
        InstanceName     = $Instancename
        SQLServerName    = $SQLServerName
        RetryIntervalSec = $RetryIntervalSec
        RetryCount       = $RetryCount
        HAEnabled        = $Query
    }
 
    $returnValue
}

function Set-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Instancename,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SQLServerName,

        [UInt64] $RetryIntervalSec = 10,

        [UInt32] $RetryCount = 10
    )

    $Result = $false
    
    $Query = IsHAEnabled -Instancename $Instancename -SQLServerName $SQLServerName     
    for ($count = 0; $count -lt $RetryCount; $count++)
    {
        if ($Query = $true)
        {
            Write-Verbose -Message "HA enabled found on $SQLServerName\$Instancename"
            break
        }
        else
        {
            Write-Verbose -Message "HA enabled has NOT been found on $SQLServerName\$Instancename. Will retry again after $RetryIntervalSec sec"
            Start-Sleep -Seconds $RetryIntervalSec
        }
    }
    if ($Query = $false)
    {
        throw "HA enabled has NOT been found on $SQLServerName\$Instancename after $count attempt with $RetryIntervalSec sec interval"
    }
}

function Test-TargetResource
{
    param
    (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Instancename,

        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SQLServerName,

        [UInt64] $RetryIntervalSec = 10,

        [UInt32] $RetryCount = 10
    )

    $Query = IsHAEnabled -Instancename $Instancename -SQLServerName $SQLServerName

    if ($Query = $true)
    {
        Write-Verbose -Message "HA is enabled on $SQLServerName\$Instancename"
        $true
    }
    else
    {
        Write-Verbose -Message "HA is NOT enabled on $SQLServerName\$Instancename"
        $false
    }
}

Export-ModuleMember -Function *-TargetResource