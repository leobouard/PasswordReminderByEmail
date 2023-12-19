# Caducidad de la contraseña

Hola $($user.GivenName),

La contraseña de tu cuenta caducará en $($user.DaysBeforeExpiration) día(s).

Para asegurar el acceso continuo a tu cuenta, por favor cambia tu contraseña antes de $((Get-Date $user.PasswordExpirationDate).ToString("D", [System.Globalization.CultureInfo]::CreateSpecificCulture('es'))).

## ¿Cómo actualizar su contraseña?

Para actualizar su contraseña, puede: ...

## Recordatorio de la política de contraseñas

Su contraseña debe tener $($user.PasswordPolicy.MinPasswordLength) caracteres o más y cumplir al menos tres de los cuatro criterios siguientes:

- Letras minúsculas (a, b, c...)
- Letras mayúsculas (A, B, C...)
- Números (0, 1, 2...)
- Caracteres especiales (&, !, @...)
