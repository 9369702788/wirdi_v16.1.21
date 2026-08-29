# One-time setup: permanent RELEASE signing via GitHub Secrets

Release builds are signed from GitHub Secrets, never auto-generated in CI.
Do this ONCE:

1. Get a release.keystore file. If you already downloaded one from a
   previous Actions run artifact ("release-keystore-COMMIT-THIS-TO-REPO-ROOT-AND-KEEP-SAFE"),
   use that exact file so any prior release build stays consistent. Its
   original password/alias (from the old workflow) were:
     storePassword: wirdi_release_2026
     keyAlias:      wirdi_release
     keyPassword:   wirdi_release_2026
   (If you have never used it to publish anything yet, feel free to
   generate a brand new one instead with your own passwords.)

2. Base64-encode the keystore file:
   - Windows (PowerShell): [Convert]::ToBase64String([IO.File]::ReadAllBytes("release.keystore")) | Out-File release.keystore.b64
   - macOS/Linux: base64 -i release.keystore -o release.keystore.b64

3. In your GitHub repo: Settings > Secrets and variables > Actions > New repository secret.
   Create these 4 secrets:
     RELEASE_KEYSTORE_BASE64   = (paste the full contents of release.keystore.b64)
     RELEASE_KEYSTORE_PASSWORD = wirdi_release_2026   (or your own, if you generated a new one)
     RELEASE_KEY_ALIAS         = wirdi_release
     RELEASE_KEY_PASSWORD      = wirdi_release_2026

4. Keep the original release.keystore file backed up somewhere safe OUTSIDE
   GitHub too (e.g. a password manager or encrypted drive). If you ever
   lose it AND the GitHub secret, you can never publish updates to the
   same Play Store listing again.

5. Do NOT commit release.keystore or key.properties to the repository.
   They are intentionally excluded now -- the workflow builds them at
   runtime from the secrets above and discards them after the job ends.
