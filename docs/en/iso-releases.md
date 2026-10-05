# Publishing a live ISO

`scripts/publish-iso.sh` publishes a built ISO to SourceForge and updates the
web release index in one step:

1. resolves the newest `x/out/x-*.iso` (or `--iso PATH`);
2. computes the SHA-256 and gpg detached signatures (project key via
   `../../keys/env.sh` / `X_REPO_SIGN_KEY`);
3. renders `README.md` from `scripts/iso-README.template.md`;
4. uploads with rsync to
   `xscriptor@frs.sourceforge.net:/home/frs/project/xlnux/iso` and removes the
   previous `x-*.iso` versions;
5. updates `web/data/releases.json` (`releases[0]`).

Push the web repo afterwards to deploy the site. A stable URL always points to
the newest release: <https://xlnux.github.io/web/download/latest/>.

```bash
source ../../keys/env.sh       # GNUPGHOME + X_REPO_SIGN_KEY
scripts/publish-iso.sh         # upload + link update
scripts/publish-iso.sh --verify # additionally waits and hashes the public download
```

Options: `--iso PATH`, `--web-dir DIR`, `--dry-run`, `--no-upload`, `--verify`.
Environment: `SF_USER` (default `xscriptor`), `SF_KEY` (default
`~/.ssh/id_ed25519_sourceforge`), `SF_PATH` (default
`/home/frs/project/xlnux/iso`), `X_ISO_DATE`.

The SourceForge account needs the SSH key registered and write access to the
`xlnux` project. Signing material stays in the workspace `keys/` directory and
`~/.ssh` — never inside any git repository.
