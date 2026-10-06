# x-repo — firmar el repositorio `[x]`

Estado actual: el repositorio se publica **firmado** y el ISO live y el destino
instalado confían en la clave del proyecto (`SigLevel = Required`; la clave
vive en `/etc/pacman.d/x-repo.pub` y la importan + firman localmente
`x-keyring.service` (live, después de `pacman-init.service`) e `install.sh`
(destino)). El host de build (`x/pacman.conf`,
usado por `mkarchiso`) usa `SigLevel = Never` para `[x]` porque el keyring del
host puede no tener la clave del proyecto. Es un procedimiento local/offline:
no requiere CI.

## 0. Crear la clave (una sola vez, secreta offline)

```bash
gpg --full-generate-key                 # RSA 4096 o ed25519, expiración larga
KEYID="$(gpg --list-keys --with-colons <mail> | awk -F: '/^fpr/{print $10; exit}')"
export X_REPO_SIGN_KEY="$KEYID"
```

Guardá la clave secreta en un medio offline o token. Solo se publica la parte
pública.

## 1. Firmar los paquetes

- Paquetes PKGBUILD: `makepkg --sign --key "$X_REPO_SIGN_KEY"` (o dejá que
  `build-packages.sh` lo haga: pasa el flag cuando la variable está seteada).
- Paquetes `.xp`: `xpkg sign` (ver `equislinux/xpkg`, `docs/SIGNING.md`).

Ambos producen un `.sig` detached junto al paquete.

## 2. Regenerar la base con firmas y exportar el keyring

```bash
X_REPO_SIGN_KEY="$KEYID" ./build-packages.sh --index-only
```

Con `X_REPO_SIGN_KEY` seteada, el script corre `repo-add -s -k`, firma
`SHA256SUMS` y exporta `trustedkeys.gpg` + `signing.pub` en
`public/repo/x86_64/`. Sin la variable, sigue publicando sin firmar y avisa.

## 3. Lado consumidor (sistemas instalados)

`/etc/pacman.conf`:

```ini
[x]
SigLevel = Required DatabaseOptional
Server = https://equislinux.github.io/x-repo/repo/x86_64
```

Bootstrap del keyring (antes de pasar a `Required`):

```bash
sudo pacman-key --init
sudo pacman-key --add signing.pub
sudo pacman-key --lsign-key "$KEYID"
```

Para `xpm`: keyring binario en `/etc/xpm/gnupg/trustedkeys.gpg` y
`sig_level = "required"` (documentado en `equislinux/xpm`).

## 4. Integración en ISO/destino (hecho)

El ISO embarca `airootfs/etc/pacman.d/x-repo.pub`. El keyring live vive en un
tmpfs que `pacman-init.service` recrea, así que `x-keyring.service` vuelve a
agregar y firmar localmente la clave después de él en cada boot; `install.sh`
repite los pasos de forma idempotente (keyrings live y del destino) antes de
`pacstrap`, que verifica la base `[x]` firmada contra el keyring live. El
destino recibe su propio keyring (`--gpgdir /mnt/etc/pacman.d/gnupg`) y
`SigLevel = Required`. Tras rotar la clave, re-corré
`x/tests/e2e-autoinstall.py` para revalidar la instalación desatendida contra
el repositorio firmado.

## 5. Rotación

- Publicá la clave nueva junto a la vieja, re-firmá la base y mantené ambas en
  el keyring al menos un ciclo de release.
- Nunca borres firmas viejas antes de que los clientes tengan la clave nueva.
- Anunciá el cambio de fingerprint en el changelog.

## 6. Cambiar la clave (planificado o emergencia)

Las claves no son para siempre; el cambio es una operación normal si se
planifica:

1. **Al crearla**: guardá un backup offline de la clave secreta **y un
   certificado de revocación** (`gpg --gen-revoke "$KEYID" > revoke.asc`,
   aparte). Perder la clave *sin* certificado de revocación es el único
   escenario realmente complicado.
2. **Cambio planificado**: generá la clave nueva, **firmala con la vieja**
   (prueba continuidad para los clientes que confían en la anterior),
   publicá ambas en `trustedkeys.gpg`, re-firmá DB/paquetes con la nueva y
   mantené la vieja en el keyring al menos un ciclo antes de sacarla.
3. **Compromiso**: publicá el certificado de revocación de la vieja, publicá
   la nueva, re-firmá todo y distribuí el keyring como en (2). Los
   consumidores en `Optional` no se ven afectados; los de `Required`
   necesitan el keyring nuevo antes del primer paquete firmado con la nueva.
4. **Pérdida (sin compromiso)**: igual que el cambio planificado; las firmas
   viejas siguen válidas, solo no podés firmar updates nuevos hasta
   distribuir la clave nueva.

Como las firmas se publican pero `[x]` sigue en `Optional` durante el
desarrollo, un cambio de clave no rompe a nadie. Pasá a `Required` recién
cuando el camino de distribución del keyring (ISO + paquete `x-keyring`
actualizable) esté listo.
