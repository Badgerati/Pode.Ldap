function Get-PodeLdapDomainName
{
    if (Test-IsUnix) {
        return (dnsdomainname)
    }
    else {
        $domain = $env:USERDNSDOMAIN
        if ([string]::IsNullOrWhiteSpace($domain)) {
            $domain = (Get-CimInstance -Class Win32_ComputerSystem).Domain
        }

        return $domain
    }
}

function Split-PodeLdapDomainControllerName
{
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Name
    )

    $parts = @($Name -split '\.' | ForEach-Object {
        "DC=$($_)"
    })

    return ($parts -join ',').ToLowerInvariant()
}

function Open-PodeLdapConnection
{
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Server,

        [Parameter()]
        [string]
        $Domain,

        [Parameter()]
        [string]
        $Username,

        [Parameter()]
        [string]
        $Password,

        [switch]
        $OpenLDAP
    )

    $result = $true
    $connection = $null

    # validate the user's AD creds
    if ((Test-IsWindows) -and !$OpenLDAP) {
        $ad = (New-Object System.DirectoryServices.DirectoryEntry "LDAP://$($Server)", "$($Username)", "$($Password)")
        if (Test-IsEmpty $ad.distinguishedName) {
            $result = $false
        }
        else {
            $connection = @{
                Entry = $ad
            }
        }
    }
    else {
        $dcName = Split-PodeLdapDomainControllerName -Name $Server
        $query = "(&(objectCategory=person)(samaccountname=$($Username)))"
        $hostname = "LDAP://$($Server)"
        $user = "$($Domain)\$($Username)"

        (ldapsearch -x -LLL -H "$($hostname)" -D "$($user)" -w "$($Password)" -b "$($dcName)" "$($query)" dn) | Out-Null
        if (!$? -or ($LASTEXITCODE -ne 0)) {
            $result = $false
        }
        else {
            $connection = @{
                Hostname = $hostname
                Username = $user
                DCName = $dcName
                Password = $Password
            }
        }
    }

    return @{
        Success = $result
        Connection = $connection
    }
}

function Get-PodeLdapUser
{
    param(
        [Parameter(Mandatory=$true)]
        $Connection,

        [Parameter(Mandatory=$true)]
        [string]
        $Username,

        [switch]
        $OpenLDAP
    )

    $query = "(&(objectCategory=person)(samaccountname=$($Username)))"

    # generate query to find user
    if ((Test-IsWindows) -and !$OpenLDAP) {
        $Connection.Searcher = New-Object System.DirectoryServices.DirectorySearcher $Connection.Entry
        $Connection.Searcher.filter = $query

        $result = $Connection.Searcher.FindOne().Properties
        if (Test-IsEmpty $result) {
            return $null
        }

        $user = @{
            Name = $result.name
        }
    }
    else {
        $result = (ldapsearch -x -LLL -H "$($Connection.Hostname)" -D "$($Connection.Username)" -w "$($Connection.Password)" -b "$($Connection.DCName)" "$($query)" name)
        if (!$? -or ($LASTEXITCODE -ne 0)) {
            return $null
        }

        $user = @{
            Name = ($result | ForEach-Object { if ($_ -imatch '^name\:\s+(?<name>.+)$') { $Matches['name'] } })
        }
    }

    return $user
}

function Get-PodeLdapGroups
{
    param (
        [Parameter(Mandatory=$true)]
        $Connection,

        [Parameter(Mandatory=$true)]
        [string]
        $CategoryName,

        [Parameter(Mandatory=$true)]
        [ValidateSet('group', 'person')]
        [string]
        $CategoryType,

        [Parameter()]
        [hashtable]
        $GroupsFound = $null,

        [switch]
        $OpenLDAP
    )

    # setup found groups
    if ($null -eq $GroupsFound) {
        $GroupsFound = @{}
    }

    # create the query
    $query = "(&(objectCategory=$($CategoryType))(samaccountname=$($CategoryName)))"
    $groups = @{}

    # get the groups
    if ((Test-IsWindows) -and !$OpenLDAP) {
        $Connection.Searcher.filter = $query
        $members = $Connection.Searcher.FindOne().Properties.memberof
    }
    else {
        $result = (ldapsearch -x -LLL -H "$($Connection.Hostname)" -D "$($Connection.Username)" -w "$($Connection.Password)" -b "$($Connection.DCName)" "$($query)" memberOf)
        $members = ($result | ForEach-Object { if ($_ -imatch '^memberOf\:\s+(?<member>.+)$') { $Matches['member'] } })
    }

    # filter the members
    foreach ($member in $members) {
        if ($member -imatch '^CN=(?<group>.+?),') {
            $g = $Matches['group']
            $groups[$g] = ($member -imatch '=builtin,')
        }
    }

    # check the status of the groups
    foreach ($group in $groups.Keys) {
        # don't bother if we've already looked up the group
        if ($GroupsFound.ContainsKey($group)) {
            continue
        }

        # add group to checked groups
        $GroupsFound[$group] = $true

        # don't bother if it's inbuilt
        if ($groups[$group]) {
            continue
        }

        # get the groups
        Get-PodeLdapGroups -Connection $Connection -CategoryName $group -CategoryType 'group' -GroupsFound $GroupsFound -OpenLDAP:$OpenLDAP
    }

    if ($CategoryType -ieq 'person') {
        return $GroupsFound.Keys
    }
}