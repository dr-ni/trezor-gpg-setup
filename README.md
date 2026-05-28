# Trezor GPG Key Setup for Git Commit Signing

Complete setup, usage, and recovery of a GPG key based on **Trezor** for signing Git commits.

---

## Prerequisites

- Trezor hardware wallet
- Ubuntu / Debian Linux
- Python 3.10+
- Git 2.x
- `pip3` available

---

## 1. Installation

### 1.1 Install trezor-agent

```bash
pip3 install trezor-agent --break-system-packages
```

### 1.2 Set PATH permanently

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 1.3 Verify installation

```bash
trezor-gpg --version
trezorctl version
```

### 1.4 Install udev rules (required for Trezor USB access)

```bash
sudo curl -L https://data.trezor.io/udev/51-trezor.rules \
  -o /etc/udev/rules.d/51-trezor.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

---

## 2. Generate GPG Key

### 2.1 Connect and unlock Trezor

Plug in the Trezor via USB and unlock it (enter PIN).

### 2.2 Generate key

```bash
TREZOR_PIN_ENTRY_BINARY=/usr/bin/pinentry-x11 \
trezor-gpg init --time=0 "First Last <email@example.com>"
```

> **Important:** Always use `--time=0`. This sets the key creation timestamp to Unix
> Epoch (1970-01-01), which allows you to regenerate the **exact same key** on any
> machine at any time — as long as you have the Trezor seed.
>
> To verify your timestamp:
> ```bash
> GNUPGHOME=~/.gnupg-trezor gpg --list-keys --with-colons | grep "^pub"
> ```
> A date of `1970-01-01` confirms `--time=0` was used.
> If you did not use `--time=0` during the first `init`, note the exact timestamp
> printed in the output.

The key is stored in `~/.gnupg-trezor`. If the directory already exists, remove it first:

```bash
rm -rf ~/.gnupg-trezor
TREZOR_PIN_ENTRY_BINARY=/usr/bin/pinentry-x11 \
trezor-gpg init --time=0 "First Last <email@example.com>"
```

### 2.3 Set GNUPGHOME permanently

```bash
echo 'export GNUPGHOME="$HOME/.gnupg-trezor"' >> ~/.bashrc
echo 'export TREZOR_PIN_ENTRY_BINARY=/usr/bin/pinentry-x11' >> ~/.bashrc
source ~/.bashrc
```

### 2.4 Get key fingerprint

```bash
gpg --list-keys
```

Example output:
```
sec   nistp256 1970-01-01 [SC]
      0D51A98FB69A6887ED489FC1514E25BFCC1CCF35
uid           [ultimate] First Last <email@example.com>
ssb   nistp256 1970-01-01 [E]
```

Keep the fingerprint in a safe place.

---

## 3. Configure Git

```bash
# Set signing key
git config --global user.signingkey YOUR_FINGERPRINT

# Sign all commits automatically
git config --global commit.gpgsign true

# GPG wrapper so Git always uses the correct GNUPGHOME
cat > ~/.local/bin/trezor-gpg-wrapper << 'WRAPPER'
#!/bin/bash
export GNUPGHOME="$HOME/.gnupg-trezor"
exec gpg "$@"
WRAPPER
chmod +x ~/.local/bin/trezor-gpg-wrapper

git config --global gpg.program trezor-gpg-wrapper
```

Verify:
```bash
git config --global --list | grep -E "gpg|sign"
```

Expected output:
```
gpg.program=trezor-gpg-wrapper
user.signingkey=YOUR_FINGERPRINT
commit.gpgsign=true
```

---

## 4. Add Public Key to GitHub

### 4.1 Export public key

```bash
GNUPGHOME=~/.gnupg-trezor gpg --export --armor YOUR_FINGERPRINT
```

### 4.2 Add to GitHub

1. Open https://github.com/settings/keys
2. Click **"New GPG key"**
3. Paste the entire block from `-----BEGIN PGP PUBLIC KEY BLOCK-----`
   to `-----END PGP PUBLIC KEY BLOCK-----`
4. Click **"Add GPG key"**

> **Important:** The commit author email must match the email on the GPG key
> for GitHub to show **Verified**. Use the same address in both Git config and
> the GPG key — e.g. the GitHub no-reply address:
> `12345678+username@users.noreply.github.com`

---

## 5. Test Signing

```bash
# Connect and unlock Trezor
git commit --allow-empty -m "test: GPG signing with Trezor"
git log --show-signature -1
```

Expected output:
```
gpg: Signature made ...
gpg:                using ECDSA key YOUR_FINGERPRINT
gpg: Good signature from "First Last <email>" [uncertain]
```

> **Note:** `[uncertain]` and the Web of Trust warning are normal for self-created
> keys without external certification. The signature is technically valid and GitHub
> will show **Verified** as long as the email addresses match.

---

## 6. Backup and Recovery

### 6.1 What to back up

The private key **never leaves the Trezor** — it cannot be exported. What you need:

| What | Where | How |
|---|---|---|
| **Trezor seed (24 words)** | On the Trezor | Paper or metal plate — keep offline |
| **Public key** (`~/.gnupg-trezor`) | Local | Export to `.asc`, store in password manager |
| **Key fingerprint** | Noted above | Password manager |
| **`--time=0`** | This README | Ensures identical key reproduction |

### 6.2 Export public key

```bash
GNUPGHOME=~/.gnupg-trezor gpg --export --armor \
  YOUR_FINGERPRINT > ~/trezor-gpg-public.asc
```

### 6.3 Restore key on a new machine

```bash
# 1. Install trezor-agent
pip3 install trezor-agent --break-system-packages
export PATH="$HOME/.local/bin:$PATH"

# 2. Install udev rules
sudo curl -L https://data.trezor.io/udev/51-trezor.rules \
  -o /etc/udev/rules.d/51-trezor.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# 3. Connect and unlock Trezor

# 4. Regenerate identical key (--time=0 always gives the same key)
rm -rf ~/.gnupg-trezor
TREZOR_PIN_ENTRY_BINARY=/usr/bin/pinentry-x11 \
trezor-gpg init --time=0 "First Last <email@example.com>"

2. Set up `~/.gnupg-trezor` — either via `trezor-gpg init --time=0` or by
   importing the backed-up public key (Section 6.3)
3. Configure Git (Section 3)
4. Connect Trezor whenever signing commits

The **private key always stays on the Trezor** — no copying between machines needed.
The `--time=0` flag guarantees the same key fingerprint on every machine.

---

## 8. Troubleshooting

### `gpg: WARNING: nothing exported`
`GNUPGHOME` points to the wrong directory:
```bash
export GNUPGHOME=~/.gnupg-trezor
gpg --list-keys
```

### `commit.gpgsign` has no effect
```bash
git config --global --list | grep gpgsign
# If empty:
git config --global commit.gpgsign true
```

### `GPG home directory exists, remove it manually`
```bash
rm -rf ~/.gnupg-trezor
TREZOR_PIN_ENTRY_BINARY=/usr/bin/pinentry-x11 \
trezor-gpg init --time=0 "Name <email>"
```

### Trezor not recognized
```bash
ls /etc/udev/rules.d/ | grep trezor
# If missing:
sudo curl -L https://data.trezor.io/udev/51-trezor.rules \
  -o /etc/udev/rules.d/51-trezor.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Commit fails when Trezor is not connected
- With `commit.gpgsign=true`, the Trezor must be connected and unlocked for every
  commit, otherwise the commit will fail

---

## 10. FIDO U2F / FIDO2 Support

| Feature | FIDO U2F (FIDO1) | FIDO2 / WebAuthn |
|---|---|---|
| Standard | FIDO Alliance, 2014 | FIDO Alliance, 2018 |
| Also known as | U2F | WebAuthn, CTAP2, Passkeys |
| Purpose | 2nd factor only (password + key) | Passwordless or 2nd factor |
| Resident keys (Passkeys) | ✗ | ✓ stored on device |
| User verification (PIN/biometric) | ✗ | ✓ optional or required |
| Phishing resistance | ✓ origin-bound | ✓ origin-bound + attestation |
| Works without password | ✗ | ✓ passwordless login |
| Browser support | All modern browsers | All modern browsers |
| Works with Google / GitHub | ✓ as 2FA | ✓ as 2FA or Passkey |
| **Trezor One** | **✓** | **✗** |
| **Trezor Model T / Safe 3/5** | **✓** | **✓** |

**Trezor One supports FIDO U2F only** — not FIDO2/WebAuthn or Passkeys.
For FIDO2, upgrade to Trezor Model T or Trezor Safe 3/5.

### Setup (no driver needed beyond udev rule)

Register the Trezor directly in your browser or service's security key settings
— no additional software required beyond the udev rule (Section 1.4).

### Works with

- Google accounts (two-factor authentication)
- GitHub (two-factor authentication)
- Dropbox, GitLab, Bitbucket
- Any service listed at https://fidoalliance.org

---

## 11. SSH Authentication — Examples

### 11.1 Connect directly to a remote server

```bash
trezor-ssh-agent -- ssh user@remotehost
```

The Trezor will prompt for confirmation on the device display.

### 11.2 Generate public key and add to server

```bash
# Generate public key
trezor-ssh-keygen -c "my-laptop"

# Output: ~/.trezor-ssh/id_ecdsa.pub (or similar)
# Copy to server:
ssh-copy-id -i ~/.trezor-ssh/id_ecdsa.pub user@remotehost

# Or manually append to ~/.ssh/authorized_keys on the server
```

### 11.3 Use with SSH config

```bash
# ~/.ssh/config
Host myserver
    HostName remotehost
    User myuser
    IdentityFile ~/.trezor-ssh/id_ecdsa

# Connect:
trezor-ssh-agent -- ssh myserver
```

### 11.4 Use with Git over SSH (GitHub)

```bash
# 1. Generate public key
trezor-ssh-keygen -c "github"

# 2. Add to GitHub:
#    Settings → SSH and GPG keys → New SSH key
#    Paste contents of ~/.trezor-ssh/id_ecdsa.pub

# 3. Test connection
trezor-ssh-agent -- ssh -T git@github.com

# 4. Use Git with Trezor SSH
trezor-ssh-agent -- git clone git@github.com:user/repo.git
trezor-ssh-agent -- git push
```

### 11.5 Persistent agent in shell session

```bash
# Start agent once and keep it running
eval $(trezor-ssh-agent)

# Now use ssh/git normally in this shell session
ssh user@remotehost
git push
```

---

## 12. 2FA / FIDO U2F — Examples

### 12.1 GitHub

1. Go to **Settings → Password and authentication → Two-factor authentication**
2. Click **"Add new method"** → **"Security key"**
3. Click **"Register new security key"**
4. Insert Trezor and tap the button when prompted
5. Name it (e.g. "Trezor One") → **Save**

From now on: login with password → browser prompts for security key → tap Trezor.

### 12.2 Google Account

1. Go to **myaccount.google.com → Security → 2-Step Verification**
2. Scroll to **"Security keys"** → **"Add security key"**
3. Insert Trezor → tap when prompted → name it → **Done**

### 12.3 GitLab

1. Go to **Preferences → Account → Two-Factor Authentication**
2. Select **"Register Two-Factor Authenticator"**
3. Choose **"WebAuthn device"**
4. Insert Trezor → tap when prompted

### 12.4 Any FIDO U2F compatible service

General steps:
1. Go to the service's security or account settings
2. Find **"Security key"**, **"Hardware key"**, or **"FIDO U2F"** option
3. Insert Trezor
4. Click **"Register"** or **"Add"**
5. Tap the Trezor button when the browser prompts

> **Note:** Trezor One uses FIDO U2F — no PIN or biometric required on the device.
> Just a physical tap confirms the login. Always keep a backup 2FA method
> (e.g. recovery codes) in case the Trezor is lost or damaged.

### 12.5 Check which services support FIDO U2F

- Full list: https://fidoalliance.org
- Community list: https://2fa.directory (filter by "Hardware token")
