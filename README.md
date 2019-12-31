# Pode LDAP

This is an extension module for the [Pode](https://github.com/Badgerati/Pode) web server (v1.3.0+). It will allow cross-platform LDAP/AD authentication to be used on routes.

On windows, this works similar to the way Pode's current LDAP authentication works. On Unix it uses OpenLDAP, so you *will* need OpenLDAP installed. You can also use the OpenLDAP functionality on Windows as well should you need to.

## Install

> Note: on Unix this module has a dependency on OpenLDAP

You can either install this module globally:

```powershell
Install-Module -Name Pode.Ldap
```

or you can let Pode install it for you locally, by adding the following into your `package.json`:

```json
"modules": {
    "pode.ldap": "latest"
}
```

## Usage

This module only exposes a single function: `Add-PodeLdapAuth`. This can be used like Pode's `Add-PodeAuth` function.

### Basics

On Windows, the simplest way to enable web-form authentication to use LDAP is:

```powershell
Import-PodeModule -Name Pode.Ldap -Now
New-PodeAuthType -Form | Add-PodeLdapAuth -Name 'Login'

# to force OpenLDAP on Windows, simply flag it as so
New-PodeAuthType -Form | Add-PodeLdapAuth -Name 'Login' -OpenLDAP
```

And on Unix, as follows:

```powershell
Import-PodeModule -Name Pode.Ldap -Now
New-PodeAuthType -Form | Add-PodeLdapAuth -Name 'Login' -Domain 'Test'
```

This `-Domain` on Unix is required to be prepended on the user's name.

### Domain Controller

By default this module will attempt to source the Domain Controller for you; by either using `dnsdomainname` on Unix, or by using `$env:USERDNSDOMAIN` on Windows.

if you want to override this, you can supply a custom Server name as follows:

```powershell
Import-PodeModule -Name Pode.Ldap -Now
New-PodeAuthType -Form | Add-PodeLdapAuth -Name 'Login' -Server 'env.company.com'
```

### Users and Groups

If a user's credentials are valid on the Domain Controller then the authentication succeeds. But you can supply an array of allowed Groups, or an array of allowed Users - using the `-Groups` and `-Users` parameters respectively.

For example, the following will only allow users in the `DevOps` group:

```powershell
Import-PodeModule -Name Pode.Ldap -Now
New-PodeAuthType -Form | Add-PodeLdapAuth -Name 'Login' -Groups @('DevOps')
```

If you don't care about user groups, you can specify `-NoGroups` to improve performance slightly.
