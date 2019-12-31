Start-PodeServer -Threads 2 {

    # listen on localhost:8090
    Add-PodeEndpoint -Address * -Port 8090 -Protocol Http

    # import the LDAP module
    Import-PodeModule -Path '../src/Pode.Ldap.psd1' -Now

    # enable logging
    New-PodeLoggingMethod -Terminal | Enable-PodeErrorLogging

    # enable ldap auth - you will need a -Domain if using on linux
    New-PodeAuthType -Form | Add-PodeLdapAuth -Name 'Login' # -Domain '<domain>'

    # set the view engine
    Set-PodeViewEngine -Type Pode

    # setup session details
    Enable-PodeSessionMiddleware -Secret 'schwifty' -Duration 120 -Extend



    # home page:
    # redirects to login page if not authenticated
    $auth_check = Get-PodeAuthMiddleware -Name 'Login' -FailureUrl '/login'

    Add-PodeRoute -Method Get -Path '/' -Middleware $auth_check -ScriptBlock {
        param($e)

        $e.Session.Data.Views++

        Write-PodeViewResponse -Path 'home' -Data @{
            'Username' = $e.Auth.User.Name;
            'Views' = $e.Session.Data.Views;
        }
    }


    # login page:
    # the login flag set below checks if there is already an authenticated session cookie. If there is, then
    # the user is redirected to the home page. If there is no session then the login page will load without
    # checking user authetication (to prevent a 401 status)
    $auth_login = Get-PodeAuthMiddleware -Name 'Login' -AutoLogin -SuccessUrl '/'

    Add-PodeRoute -Method Get -Path '/login' -Middleware $auth_login -ScriptBlock {
        Write-PodeViewResponse -Path 'login' -FlashMessages
    }


    # login check:
    # this is the endpoint the <form>'s action will invoke. If the user validates then they are set against
    # the session as authenticated, and redirect to the home page. If they fail, then the login page reloads
    Add-PodeRoute -Method Post -Path '/login' -Middleware (Get-PodeAuthMiddleware `
        -Name 'Login' `
        -FailureUrl '/login' `
        -SuccessUrl '/' `
        -EnableFlash)


    # logout check:
    # when the logout button is click, this endpoint is invoked. The logout flag set below informs this call
    # to purge the currently authenticated session, and then redirect back to the login page
    Add-PodeRoute -Method Post -Path '/logout' -Middleware (Get-PodeAuthMiddleware `
        -Name 'Login' `
        -FailureUrl '/login' `
        -Logout)
}