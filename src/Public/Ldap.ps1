function Add-PodeLdapAuth
{
    [CmdletBinding(DefaultParameterSetName='Groups')]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $Name,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]
        $Type,

        [Parameter()]
        [string]
        $Server,

        [Parameter()]
        [string]
        $Domain,

        [Parameter(ParameterSetName='Groups')]
        [string[]]
        $Groups,

        [Parameter()]
        [string[]]
        $Users,

        [Parameter(ParameterSetName='NoGroups')]
        [switch]
        $NoGroups,

        [switch]
        $OpenLDAP
    )

    # set server same if not passed
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = Get-PodeLdapDomainName

        if ([string]::IsNullOrWhiteSpace($Server)) {
            throw 'No domain server name has been supplied for Pode LDAP authentication'
        }
    }

    # if unix and no domain name, fail
    if ((Test-IsUnix) -and [string]::IsNullOrWhiteSpace($Domain)) {
        throw 'A user domain name is required on unix platforms. This is the domain used for the format "<domain>/<username>"'
    }

    # get the ldap auth method
    $_method = Get-PodeLdapAuthMethod

    # add the auth type
    Add-PodeAuth -Name $Name -Type $Type -ScriptBlock $_method -ArgumentList @{
        Server = $Server
        Domain = $Domain
        Users = $Users
        Groups = $Groups
        NoGroups = $NoGroups
        OpenLDAP = $OpenLDAP
    }
}