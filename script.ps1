﻿[CmdletBinding(SupportsShouldProcess=$True)]
Param(
    [Parameter(Mandatory=$true)][array]$ExpireInDays,
    [array]$TestRecipient,
    [string]$SearchBase = ((Get-ADDomain).DistinguishedName),
    [System.IO.FileInfo]$Layout = "$PSScriptRoot\layout.html"
)

# Password policies
$defaultDomainPasswordPolicy = Get-ADDefaultDomainPasswordPolicy
Write-Verbose -Message "Get default domain password policy on $($defaultDomainPasswordPolicy.DistinguishedName)"
$defaultMaxPasswordAge = [math]::Round($defaultDomainPasswordPolicy.MaxPasswordAge.TotalDays,0)
Write-Verbose -Message "Max password age on default domain password policy is $defaultMaxPasswordAge day(s)"
$fineGrainedPasswordPolicy = Get-ADFineGrainedPasswordPolicy -Filter *
Write-Verbose -Message "Get all fine-grained password policies: $($fineGrainedPasswordPolicy.Name -join ', ')"

# Get all users
Write-Verbose -Message "Search for all users on `'$SearchBase`'..."
$properties = 'GivenName','DisplayName','PasswordNeverExpires','PasswordExpired','PasswordLastSet','LastLogonDate','EmailAddress','MemberOf','CanonicalName','Title','Department','Company','Country'
$users = Get-ADUser -Filter {(Enabled -eq $true) -and (PasswordNeverExpires -eq $false) -and (PasswordExpired -eq $false)} -Properties $properties -SearchBase $SearchBase |
    Where-Object {$_.PasswordLastSet -and $_.EmailAddress}
Write-Verbose -Message "$(($users | Measure-Object).Count) users found!"

# Add the password age
Write-Verbose -Message "Add new properties with default values"
$users | ForEach-Object {
    $passwordAge = (New-TimeSpan -Start $_.PasswordLastSet -End (Get-Date)).TotalDays
    $passwordAge = [math]::Round($passwordAge,0)
    $_ | Add-Member -MemberType "NoteProperty" -Name "PasswordAge" -Value $passwordAge -Force
    $_ | Add-Member -MemberType "NoteProperty" -Name "MaxPasswordAge" -Value $defaultMaxPasswordAge -Force
    $_ | Add-Member -MemberType "NoteProperty" -Name "PasswordPolicy" -Value $defaultDomainPasswordPolicy -Force
    $_ | Add-Member -MemberType "NoteProperty" -Name "Template" -Value "default" -Force
    Remove-Variable passwordAge
}

# Fine grained password policy
Write-Verbose -Message "New properties updated for users exposed to fine-grained password policies"
$fineGrainedPasswordPolicy | Sort-Object -Property Precedence -Descending | Foreach-Object {
    $passwordPolicy = $_
    $maxPasswordAge = [math]::Round($_.MaxPasswordAge.TotalDays,0)
    $_.AppliesTo | Foreach-Object {
        $appliesToObject = $_
        $users | Where-Object {$_.MemberOf -contains $appliesToObject -or $_.DistinguishedName -eq $appliesToObject} | ForEach-Object {
            $_.MaxPasswordAge = $maxPasswordAge
            $_.PasswordPolicy = $passwordPolicy
        }
        Remove-Variable appliesToObject
    }
    Remove-Variable passwordPolicy,maxPasswordAge
}

# Formating the object
$users = $users | Where-Object {$_.MaxPasswordAge -ne 0} | Sort-Object PasswordAge | Select-Object GivenName,Name,EmailAddress,PasswordAge,MaxPasswordAge,PasswordLastSet,LastLogonDate,
        @{N="PasswordExpirationDate";E={($_.PasswordLastSet).AddDays($_.MaxPasswordAge)} },
        @{N="DaysBeforeExpiration";E={$_.MaxPasswordAge-$_.PasswordAge}},
        Title,Department,Company,Country,CanonicalName,DistinguishedName,PasswordPolicy,Template

# Filter out users
Write-Verbose -Message "Excluding users with password that won't expires in the next $(($ExpireInDays | Sort-Object -Descending) -join ', ') day(s)"
$users = $users | Where-Object {$_.DaysBeforeExpiration -in $ExpireInDays}
Write-Verbose -Message "Remaining users after filtering: $(($users | Measure-Object).Count)"

# Associate user with a template
$data = Get-Content -Path "$PSScriptRoot\data.json" | ConvertFrom-Json
Write-Verbose -Message "Associating users with localized message templates"
$data = $data | Sort-Object -Property Priority -Descending
$data | Where-Object {$_.Template -ne 'default'} | ForEach-Object {
    $template = $_.Template
    $filter   = $_.Filter
    $users | Where-Object {Invoke-Expression $filter} | ForEach-Object { $_.Template = $template }
    Remove-Variable template,filter
}

# Displaying all information
$users |
    Select-Object Name,EmailAddress,DaysBeforeExpiration,template,passwordPolicy |
    Sort-Object DaysBeforeExpiration | Format-Table

# Send emails
$templates = Get-ChildItem -Path "$PSScriptRoot\templates"
$users | ForEach-Object {

    $user = $_
    $file = $templates | Where-Object {$_.BaseName -eq $user.Template}

    # Get subject
    $subject = ($data | Where-Object {$_.Template -eq $user.Template}).Subject

    # Get mail content
    $content = Get-Content -Path $file.FullName -Raw | Out-String
    $content = $ExecutionContext.InvokeCommand.ExpandString($content)
    $content = ($content | ConvertFrom-Markdown).Html
    
    # Get mail layout
    $body = Get-Content -Path $Layout -Encoding UTF8 | Out-String
    $body = $body -replace '{{CONTENT}}',$content

    # Send email
    $mailParams = @{
        Body          = $body
        BodyAsHtml    = $true
        Encoding      = 'UTF8'
        From          = "noreply@domain.com"
        SmtpServer    = "smtp.domain.com"
        Subject       = $subject
        To            = $_.EmailAddress
        WarningAction = 'SilentlyContinue'
    }

    if ($TestRecipient) { $mailParams.To = $TestRecipient }

    Write-Verbose -Message "Sending email to $($mailParams.To) using the template $($file.Name)"
    Send-MailMessage @mailParams

    # Clear variables
    Remove-Variable user,subject,file,content,body
}