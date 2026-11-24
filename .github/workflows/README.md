# SpeshTV Windows automation

`windows-signed-release.yml` signs and publishes an existing **draft** Windows
release using Microsoft Artifact Signing Public Trust. It never converts or
replaces an already-published release. There is no unsigned fallback.

## One-time Azure setup

1. Create/select an Azure subscription, then an Artifact Signing **Basic** account.
   This is a paid Azure resource. Confirm current pricing before creating it.
2. Complete Public Trust identity validation in the Azure portal and create a
   Public Trust certificate profile. Individual validation requires an eligible
   country and matching legal billing identity. Never upload a private key here.
3. Create an Entra application/service principal with a federated credential:
   issuer `https://token.actions.githubusercontent.com`, audience
   `api://AzureADTokenExchange`, subject
   `repo:daodere1/SpeshTV-Windows:environment:windows-signing`.
4. Assign only **Artifact Signing Certificate Profile Signer** at the certificate
   profile scope. The workflow does not need Azure Owner/Contributor access.
5. Create the GitHub environment `windows-signing`, restrict deployments to main,
   and set these environment variables:

| Variable | Value |
| --- | --- |
| AZURE_CLIENT_ID | Entra application client ID |
| AZURE_TENANT_ID | Directory tenant ID |
| AZURE_SUBSCRIPTION_ID | Subscription ID |
| WINDOWS_SIGNING_ENDPOINT | Regional HTTPS codesigning endpoint |
| WINDOWS_SIGNING_ACCOUNT | Artifact Signing account name |
| WINDOWS_SIGNING_PROFILE | Public Trust certificate profile name |
| WINDOWS_SIGNING_PUBLISHER | Exact certificate subject, including CN and other fields |

These identifiers are configuration, not passwords. OIDC supplies short-lived
credentials; do not create an Azure client secret or put a certificate in Git.

## Each release

Build and test the normal local candidate. Push its final source to main, create
an unpublished draft targeting that exact commit, and upload the reviewed
`SpeshTV-Windows-X.Y.Z-Portable.zip` plus its `SHA256SUMS.txt`. Keep the regular
release notes in that draft. The portable input must contain the `SpeshTV` folder.

Run **Sign and publish Windows release** on main with the draft tag `vX.Y.Z`:

```powershell
gh workflow run windows-signed-release.yml --ref main -f tag=v3.1.3
```

A local build/release script can issue that dispatch command as its final step.
Do not publish the unsigned draft first. The workflow:

- verifies draft/source identity, archive checksum, safe paths and app version;
- signs SpeshTV.exe with SHA-256 and an RFC3161 timestamp;
- verifies publisher and trust before building the installer;
- signs and verifies the installer, then creates the portable ZIP and hashes;
- attaches corresponding source and signature details, removes the old unsigned
  installer, and publishes only after all preceding steps succeed.

It runs on the official Windows 2022 image with Inno Setup 6, and uses pinned
checkout/Azure actions. Third-party DLL publisher signatures are retained.
A failed job leaves the release as a draft. Download and smoke-test the resulting
installer on a clean Windows PC. Signing does not guarantee immediate SmartScreen
reputation and is separate from Microsoft Store certification.

Setup references:
- https://learn.microsoft.com/azure/artifact-signing/quickstart
- https://github.com/Azure/artifact-signing-action
- https://learn.microsoft.com/windows/apps/package-and-deploy/smartscreen-reputation
