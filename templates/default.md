# Password expiration

Hello $($user.GivenName),

Your account password is set to expire in $($user.DaysBeforeExpiration) day(s).

To ensure continued access to your account, please change your password before $((Get-Date $user.PasswordExpirationDate).ToString("D", [System.Globalization.CultureInfo]::CreateSpecificCulture('en'))).

## How to update your password?

To update your password, you can: ...

## Reminder of password policy

Your password must be $($user.PasswordPolicy.MinPasswordLength) characters or longer and meet at least three of the following four criteria:

- Lower-case letters (a, b, c...)
- Upper-case letters (A, B, C...)
- Numbers (0, 1, 2...)
- Special characters (&, !, @...)
