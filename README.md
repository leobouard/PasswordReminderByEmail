# PasswordReminderByEmail

Inform your users by email when their password is about to expire.

> Disclaimer: frequent password expiration isn't recommanded anymore by many security experts

## Feature

This script is only compatible with PowerShell 7+.

The most flexible password expiration reminder script that you'll find! The script will automatically adapt itself to your default domain password policy and fine-grained password policies.

The script support multiple translations and layouts for your emails.

### How to assign a translation to a user?

The `data.json` file is used to assign each user a translation (template) and the email subject. Here's an example to target France and Belgium to apply a French translation and a French email subject:

```json
{
    "Template":  "fr",
    "Subject":  "Expiration de votre mot de passe",
    "Filter":  "$_.CanonicalName -match '/FRANCE/|/BELGIQUE/'",
    "Priority":  10
}
```

The lowest priority is the one that will be used in case of conflict.

## Parameters

- `ExpireInDays`: An array of days. The script will filter out users whose passwords won't expire in the next specified number of days.
- `TestRecipient`: An array of test recipients to receive emails instead of users.
- `SearchBase`: The distinguished name of the organizational unit that you want to target. The default value is the current domain.
- `Layout`: The path to the layout email file. The default value is "layout.html" in the script's directory.
