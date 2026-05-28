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
