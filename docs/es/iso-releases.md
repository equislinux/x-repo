# Publicar una ISO live

`scripts/publish-iso.sh` publica una ISO ya construida en SourceForge y
actualiza el índice de releases de la web en un solo paso:

1. resuelve la ISO más nueva en `x/out/x-*.iso` (o `--iso PATH`);
2. calcula el SHA-256 y las firmas gpg detached (clave del proyecto vía
   `../../keys/env.sh` / `X_REPO_SIGN_KEY`);
3. genera `README.md` desde `scripts/iso-README.template.md`;
4. sube por rsync a
   `xscriptor@frs.sourceforge.net:/home/frs/project/xlnux/iso` y borra las
   versiones anteriores `x-*.iso`;
5. actualiza `web/data/releases.json` (`releases[0]`).

Después hay que pushear el repo web para desplegar el sitio. Hay una URL
estable que siempre apunta a la última release:
<https://equislinux.github.io/web/download/latest/>.

```bash
source ../../keys/env.sh       # GNUPGHOME + X_REPO_SIGN_KEY
scripts/publish-iso.sh         # subida + actualización de enlaces
scripts/publish-iso.sh --verify # además espera y hashea la descarga pública
```

Opciones: `--iso PATH`, `--web-dir DIR`, `--dry-run`, `--no-upload`,
`--verify`. Entorno: `SF_USER` (por defecto `xscriptor`), `SF_KEY`
(`~/.ssh/id_ed25519_sourceforge`), `SF_PATH`
(`/home/frs/project/xlnux/iso`), `X_ISO_DATE`.

La cuenta de SourceForge necesita la clave SSH registrada y permiso de
escritura en el proyecto `equislinux`. El material de firma vive en `keys/` del
workspace y en `~/.ssh` — nunca dentro de un repositorio git.
