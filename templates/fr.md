# Expiration du mot de passe

Bonjour $($user.GivenName),

Le mot de passe de votre compte expirera dans $($user.DaysBeforeExpiration) day(s).

Pour garantir un accès continu à votre compte, veuillez modifier votre mot de passe avant le $((Get-Date $user.PasswordExpirationDate).ToString("D", [System.Globalization.CultureInfo]::CreateSpecificCulture('fr'))).

## Comment mettre à jour votre mot de passe ?

Pour mettre à jour votre mot de passe, vous pouvez : ...

## Rappel de la politique en matière de mot de passe

Votre mot de passe doit être composé de $($user.PasswordPolicy.MinPasswordLength) caractères ou plus et répondre à au moins trois des quatre critères suivants :

- Lettres minuscules (a, b, c...)
- Lettres majuscules (A, B, C...)
- Chiffres (0, 1, 2...)
- Caractères spéciaux (&, !, @...)
