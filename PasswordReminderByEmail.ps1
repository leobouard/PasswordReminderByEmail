param(
    [Parameter(Mandatory=$true)][int[]]$ExpireInDays = (15,10,5,3,2,1),
    [array]$TestRecipient,
    [string]$SearchBase = ((Get-ADDomain).DistinguishedName),
    [string]$Layout = "$PSScriptRoot\layout.html",
    [int]$LogHistory = 30
)

# Start transcript
$start = Get-Date
Start-Transcript -Path "$PSScriptRoot\logs\PasswordReminderByEmail_$($SearchBase)_$(Get-Date -Format 'yyyy-MM-dd_HHmmss').txt" -UseMinimalHeader

# Remove old log files
Write-Verbose -Message "Removing logs files older than $LogHistory day(s) ago"
Get-ChildItem -Path "$PSScriptRoot\logs" -Recurse | Where-Object {
    $_.BaseName -like 'PasswordReminderByEmail_*' -and 
    $_.Extension -eq '.txt' -and 
    $_.LastWriteTime -lt (Get-Date).AddDays(-$LogHistory)
} | Remove-Item -Force -Confirm:$false -Verbose

# Password policies
$defaultDomainPasswordPolicy = Get-ADDefaultDomainPasswordPolicy
Write-Verbose -Message "Get default domain password policy on $($defaultDomainPasswordPolicy.DistinguishedName)"
$defaultMaxPasswordAge = [math]::Round($defaultDomainPasswordPolicy.MaxPasswordAge.TotalDays,0)
Write-Verbose -Message "Max password age on default domain password policy is $defaultMaxPasswordAge day(s)"
$fineGrainedPasswordPolicy = Get-ADFineGrainedPasswordPolicy -Filter *
Write-Verbose -Message "Get all fine-grained password policies: $($fineGrainedPasswordPolicy.Name -join ', ')"

# Get all users
Write-Verbose -Message "Search for all users on `'$SearchBase`'..."
$ldapFilter = '(&(objectClass=User)(!(userAccountControl:1.2.840.113556.1.4.803:=2))(pwdLastSet=*)(!(userAccountControl:1.2.840.113556.1.4.803:=65536)(mail=*)))'
$users = Get-ADUser -LDAPFilter $ldapFilter -Properties * -SearchBase $SearchBase
Write-Verbose -Message "$(($users | Measure-Object).Count) users found!"

# Add the password age
Write-Verbose -Message 'Add new properties with default values'
$users | ForEach-Object {
    $passwordAge = (New-TimeSpan -Start $_.PasswordLastSet -End (Get-Date)).TotalDays
    $passwordAge = [math]::Round($passwordAge,0)
    $_ | Add-Member -MemberType NoteProperty -Name PasswordAge -Value $passwordAge -Force
    $_ | Add-Member -MemberType NoteProperty -Name MaxPasswordAge -Value $defaultMaxPasswordAge -Force
    $_ | Add-Member -MemberType NoteProperty -Name PasswordPolicy -Value $defaultDomainPasswordPolicy -Force
    $_ | Add-Member -MemberType NoteProperty -Name Template -Value default -Force
    Remove-Variable passwordAge
}

# Fine grained password policy
Write-Verbose -Message "New properties updated for users exposed to fine-grained password policies"
$fineGrainedPasswordPolicy | Sort-Object -Property Precedence -Descending | Foreach-Object {
    Write-Verbose -Message "Processing $($_.Name)"
    $passwordPolicy = $_
    $maxPasswordAge = [math]::Round($_.MaxPasswordAge.TotalDays,0)
    $_.AppliesTo | Foreach-Object {
        $targetObject = Get-ADObject $_
        if ($targetObject.ObjectClass -eq 'group') {
            $members = Get-ADGroupMember $targetObject -Recursive
        }
        else {
            $members = $targetObject
        }
        $users | Where-Object {$_.DistinguishedName -in $members.DistinguishedName -or $_.DistinguishedName -eq $targetObject.DistinguishedName} | ForEach-Object {
            $_.MaxPasswordAge = $maxPasswordAge
            $_.PasswordPolicy = $passwordPolicy
        }
        Remove-Variable targetObject,members
    }
    Remove-Variable passwordPolicy,maxPasswordAge
}

# Formating the object
$users = $users | Where-Object {$_.MaxPasswordAge -ne 0} | Sort-Object PasswordAge | Select-Object *,
    @{N='PasswordExpirationDate';E={($_.PasswordLastSet).AddDays($_.MaxPasswordAge)}},
    @{N='DaysBeforeExpiration';E={$_.MaxPasswordAge-$_.PasswordAge}}

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
$users | Select-Object Name,DaysBeforeExpiration,template,passwordPolicy | Sort-Object DaysBeforeExpiration | Format-Table

# Send emails
$templates = Get-ChildItem -Path "$PSScriptRoot\templates"
$users | ForEach-Object {

    $user = $_
    $file = $templates | Where-Object {$_.BaseName -eq $user.Template}

    # Get subject
    $subject = ($data | Where-Object {$_.Template -eq $user.Template}).Subject
    $subject = $ExecutionContext.InvokeCommand.ExpandString($subject)

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
        From          = 'noreply@domain.com'
        SmtpServer    = 'smtp.domain.com'
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

$stopwatch = [int](New-TimeSpan -Start $start).TotalSeconds
Write-Verbose -Message "The script has completed in $stopwatch seconds"

# End transcript
Stop-Transcript