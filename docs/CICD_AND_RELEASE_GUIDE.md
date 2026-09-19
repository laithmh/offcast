# 🚀 OffCast CI/CD & Automated Release Guide

OffCast includes a dual-pipeline **GitHub Actions CI/CD automation system**:
1. **CI Quality Gate (`.github/workflows/ci.yml`)**: Automatically triggers on every push and pull request to `main` to verify code formatting, run static analysis (`flutter analyze --fatal-infos`), and execute the 50-test suite.
2. **Release Deployment (`.github/workflows/release.yml`)**: Automatically triggers when you push a version tag (e.g. `v1.0.0+1`), builds an optimized Android release APK, generates a cryptographic SHA-256 checksum, and creates a public GitHub Release with the binary attached.

---

## 🏷️ How to Publish a New Release

To trigger an automated build and publish a release to GitHub:

### Option 1: Using Git Tags (Recommended)

```bash
# 1. Ensure your local branch is clean and pushed
git checkout main
git pull origin main

# 2. Create an annotated version tag
git tag -a v1.0.0+1 -m "Release v1.0.0+1: Production Release with Teleprompter & VAD"

# 3. Push the tag to GitHub
git push origin v1.0.0+1
```

Once pushed, GitHub Actions will:
1. Spin up an `ubuntu-latest` runner with Java 17 and Flutter stable.
2. Execute the test suite.
3. Compile `offcast-v1.0.0+1.apk`.
4. Generate `offcast-v1.0.0+1.apk.sha256`.
5. Create a GitHub Release at `https://github.com/laithmh/offcast/releases/tag/v1.0.0%2B1` with the APK and changelog attached.

---

### Option 2: Manual Trigger via GitHub UI (`workflow_dispatch`)

1. Go to your repository on GitHub: `https://github.com/laithmh/offcast`.
2. Click the **Actions** tab.
3. Select **Build & Publish Release APK** in the left sidebar.
4. Click **Run workflow**.
5. *(Optional)* Enter a custom tag name (e.g. `v1.0.1`), or leave blank to auto-generate a timestamped build tag.
6. Click **Run workflow**.

---

## 🔑 (Optional) Setting Up Production Keystore Signing Secrets

By default, if no secrets are configured, the workflow builds a valid release APK using the project's default signing configuration so builds never fail.

To sign release builds in GitHub Actions with your official `offcast-release.jks`:

### 1. Encode your Keystore to Base64
In PowerShell on your machine:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android/app/offcast-release.jks")) | Set-Clipboard
```
*(Your clipboard now holds the full base64 string!)*

### 2. Add Repository Secrets in GitHub
Navigate to **GitHub Repository** -> **Settings** -> **Secrets and variables** -> **Actions** -> **New repository secret**:

| Secret Name | Value Description |
| :--- | :--- |
| `KEYSTORE_BASE64` | Paste the base64 string from your clipboard |
| `KEYSTORE_PASSWORD` | The password you used when generating `offcast-release.jks` |
| `KEY_ALIAS` | The key alias (e.g., `offcast` or `upload`) |
| `KEY_PASSWORD` | The key alias password |

Once configured, the workflow will automatically decode the keystore on the runner, construct `android/key.properties`, and sign your APK with your production key!
