function Get-PodeLdapAuthMethod
{
    return {
        param($username, $password, $options)

        # validate and retrieve the AD user
        $noGroups = $options.NoGroups
        $openLdap = $options.OpenLDAP

        $result = (Test-PodeLdapUser `
            -Server $options.Server `
            -Domain $options.Domain `
            -Username $username `
            -Password $password `
            -NoGroups:$noGroups `
            -OpenLDAP:$openLdap)

        # if there's a message, fail and return the message
        if (![string]::IsNullOrWhiteSpace($result.Message)) {
            return $result
        }

        # if there's no user, then, err, oops
        if ($null -eq $result.User) {
            return @{ Message = 'An unexpected error occured' }
        }

        # if there are no groups/users supplied, return the user
        if ((Test-IsEmpty $options.Users) -and (Test-IsEmpty $options.Groups)){
            return $result
        }

        # before checking supplied groups, is the user in the supplied list of authorised users?
        if (!(Test-IsEmpty $options.Users) -and (@($options.Users) -icontains $result.User.Username)) {
            return $result
        }

        # if there are groups supplied, check the user is a member of one
        if (!(Test-IsEmpty $options.Groups)) {
            foreach ($group in $options.Groups) {
                if (@($result.User.Groups) -icontains $group) {
                    return $result
                }
            }
        }

        # else, they shall not pass!
        return @{ Message = 'You are not authorised to access this website' }
    }
}

function Test-PodeLdapUser
{
    param (
        [Parameter()]
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
        $NoGroups,

        [switch]
        $OpenLDAP
    )

    try
    {
        # validate the user's AD creds
        $result = (Open-PodeLdapConnection -Server $Server -Domain $Domain -Username $Username -Password $Password -OpenLDAP:$OpenLDAP)
        if (!$result.Success) {
            return @{ Message = 'Invalid credentials supplied' }
        }

        # get the connection
        $connection = $result.Connection

        # get the user
        $user = (Get-PodeLdapUser -Connection $connection -Username $Username -OpenLDAP:$OpenLDAP)
        if ($null -eq $user) {
            return @{ Message = 'User not found in Active Directory' }
        }

        # get the users groups
        $groups =@()
        if (!$NoGroups) {
            $groups = (Get-PodeLdapGroups -Connection $connection -CategoryName $Username -CategoryType 'person' -OpenLDAP:$OpenLDAP)
        }

        # return the user
        return @{
            User = @{
                Username = $Username
                Name = $user.name
                Server = $Server
                Domain = $Domain
                Groups = $groups
            }
        }
    }
    finally {
        if ((Test-IsWindows) -and !$OpenLDAP -and ($null -ne $connection)) {
            Close-PodeDisposable -Disposable $connection.Searcher
            Close-PodeDisposable -Disposable $connection.Entry -Close
        }
    }
}