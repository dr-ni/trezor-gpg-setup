# Trezor — GPG · SSH · 2FA Setup

Complete setup, usage, and recovery for GPG signing, SSH authentication,
and 2FA using a **Trezor** hardware wallet.

---

## Architecture Overview

| Layer | Component | Responsibility |
|---|---|---|
| Device | Trezor | PIN entry, private key operations, signing |
| Protocol | trezorctl / python-trezor | Device communication |
| Wrapper | trezor-agent | SSH / GPG bridge |
| Host UI | pinentry | Passphrase prompts on host |

> **Key distinction:**
> - **PIN** — entered via device matrix, handled entirely by Trezor firmware
> - **Passphrase** — optional, entered on host via pinentry or set via env variable
> - **pinentry** — affects passphrase and trezor-agent flows only, not PIN

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

## 2. Environment Variables

Set these permanently in `~/.bashrc`:

```bash
# GPG keyring for Trezor keys
echo 'export GNUPGHOME="$HOME/.gnupg-trezor"' >> ~/.bashrc

# pinentry program — choose based on your environment:
# TTY / SSH session:
echo 'export TREZOR_PIN_ENTRY_BINARY=/usr/bin/pinentry-tty' >> ~/.bashrc
# Desktop / X11:
# echo 'export TREZOR_PIN_ENTRY_BINARY=/usr/bin/pinentry-gtk-2' >> ~/.bashrc

# Passphrase mode — see note below
echo 'export TREZOR_PASSPHRASE=""' >> ~/.bashrc
echo 'export TREZOR_PASSPHRASE_ON_DEVICE=0' >> ~/.bashrc

source ~/.bashrc
```

> **Note on pinentry:**
> `TREZOR_PIN_ENTRY_BINARY` affects **passphrase** prompts and trezor-agent flows
> only — **not** the Trezor PIN matrix. The PIN is always handled by device
> firmware directly.
>
> | Environment | Recommended pinentry |
> |---|---|
> | TTY / SSH | `pinentry-tty` |
> | Desktop / X11 | `pinentry-gtk-2` |
> | KDE | `pinentry-qt` |

> **Note on passphrase:**
> `TREZOR_PASSPHRASE=""` activates **empty passphrase mode** — this disables
> Hidden Wallet functionality. If you use a passphrase for a Hidden Wallet,
> do not set this variable and enter your passphrase when prompted.

---

## 3. Generate GPG Key

### 3.1 Connect and unlock Trezor

Plug in the Trezor via USB and enter PIN when prompted.

### 3.2 Generate key

```bash
trezor-gpg init --time=0 "First Last <email@example.com>"
```

> **Important — `--time=0`:**
> Sets the key creation timestamp to Unix Epoch (1970-01-01).
> Using the same timestamp, identity string, seed, passphrase, and curve
> will reproduce the same key fingerprint on any machine.
>
> To verify:
> ```bash
> GNUPGHOME=~/.gnupg-trezor gpg --list-keys --with-colons | grep "^pub"
> ```
> A date of `1970-01-01` confirms `--time=0` was used.

If the directory already exists, remove it first:

```bash
rm -rf ~/.gnupg-trezor
trezor-gpg init --time=0 "First Last <email@example.com>"
```

### 3.3 Get key fingerprint

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

## 4. Configure Git

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

### 4.1 Verify configuration

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

## 5. Add Public Key to GitHub

### 5.1 Export public key

```bash
GNUPGHOME=~/.gnupg-trezor gpg --export --armor YOUR_FINGERPRINT
```

### 5.2 Add to GitHub

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

## 6. Test Signing

```bash
git commit --allow-empty -m "test: GPG signing with Trezor"
git log --show-signature -1
```

Expected output:
```
gpg: Signature made ...
gpg:                using ECDSA key YOUR_FINGERPRINT
gpg: Good signature from "First Last <email>" [uncertain]
```

> `[uncertain]` is normal for self-created keys without external certification.
> The signature is technically valid. GitHub will show **Verified** as long as
> email addresses match.

---

## 7. Backup and Recovery

### 7.1 What to back up

Private signing operations occur on-device — the key material is derived
from the seed and never stored on the host. What you need to back up:

| What | Where | How |
|---|---|---|
| **Trezor seed (24 words)** | On the Trezor | Paper or metal plate — keep offline |
| **Public key** (`~/.gnupg-trezor`) | Local | Export to `.asc`, store in password manager |
| **Key fingerprint** | Noted above | Password manager |
| **Identity string** | This README | Exact string used in `trezor-gpg init` |
| **`--time=0`** | This README | Required for identical key reproduction |

### 7.2 Export public key

```bash
GNUPGHOME=~/.gnupg-trezor gpg --export --armor \
  YOUR_FINGERPRINT > ~/trezor-gpg-public.asc
```

### 7.3 Restore key on a new machine

```bash
# 1. Install trezor-agent
pip3 install trezor-agent --break-system-packages
export PATH="$HOME/.local/bin:$PATH"

# 2. Install udev rules
sudo curl -L https://data.trezor.io/udev/51-trezor.rules \
  -o /etc/udev/rules.d/51-trezor.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

# 3. Connect and unlock Trezor

# 4a. Regenerate key — requires same seed, passphrase, identity string, timestamp
rm -rf ~/.gnupg-trezor
trezor-gpg init --time=0 "First Last <email@example.com>"

# 4b. Alternative: import backed-up public key
mkdir -p ~/.gnupg-trezor && chmod 700 ~/.gnupg-trezor
GNUPGHOME=~/.gnupg-trezor gpg --import ~/trezor-gpg-public.asc
GNUPGHOME=~/.gnupg-trezor gpg --edit-key YOUR_FINGERPRINT
# In the editor: trust → 5 (ultimate) → quit

# 5. Set environment permanently (see Section 2)

# 6. Configure Git (see Section 4)
```

---

## 8. Multiple Machines

On each machine:

1. Install `trezor-agent` (Section 1)
2. Set environment variables (Section 2)
3. Set up `~/.gnupg-trezor` via `trezor-gpg init --time=0` or by importing
   the backed-up public key (Section 7.3)
4. Configure Git (Section 4)
5. Connect Trezor whenever signing commits

The **private signing operations always occur on the Trezor** — no key material
is copied between machines. `--time=0` with identical parameters reproduces the
same key fingerprint on every machine.

---

## 9. Troubleshooting

### `gpg: WARNING: nothing exported`
```bash
export GNUPGHOME=~/.gnupg-trezor
gpg --list-keys
```

### `commit.gpgsign` has no effect
```bash
git config --global --list | grep gpgsign
git config --global commit.gpgsign true
```

### `GPG home directory exists, remove it manually`
```bash
rm -rf ~/.gnupg-trezor
trezor-gpg init --time=0 "Name <email>"
```

### Trezor not recognized
```bash
ls /etc/udev/rules.d/ | grep trezor
sudo curl -L https://data.trezor.io/udev/51-trezor.rules \
  -o /etc/udev/rules.d/51-trezor.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Commit fails when Trezor is not connected
```bash
git commit --no-gpg-sign -m "message"
```

### `PIN invalid` error
Trezor One uses position-based PIN entry. The display shows numbers in random
order — enter the **position** of each digit on the matrix, not the digit itself:
```
Display shows random layout.    Fixed keypad positions:
  e.g.  3  7  5                   7  8  9
        8  2  9                   4  5  6
        1  4  6                   1  2  3
```
Look at the Trezor display while typing. PIN enters the position where your
digit appears, not the digit shown on the keypad.

### `pinentry` / passphrase errors with trezor-agent
```bash
export TREZOR_PASSPHRASE=""
export TREZOR_PASSPHRASE_ON_DEVICE=0
```
Note: this activates empty passphrase mode and disables Hidden Wallet.

### `gpg: signing failed: End of file`
Stale trezor-gpg-agent processes are blocking USB access:
```bash
pkill -f trezor-gpg-agent
git commit
```

### Shell quoting errors with BIP32 paths
Always quote derivation paths to prevent shell interpretation of `'`:
```bash
# Correct:
trezorctl ethereum get-address -n "m/44'/60'/0'/0/0"

# Wrong — shell will interpret unquoted apostrophes:
trezorctl ethereum get-address -n m/44'/60'/0'/0/0
```

---

## 10. Important Notes

- **Private signing operations occur on-device** — key material is derived
  from the seed inside the Trezor and never stored on the host
- Deterministic key reproduction requires identical: seed, passphrase, identity
  string, curve, and timestamp
- `nistp256` (ECDSA) is used — secure for current use cases, not post-quantum
- trezor-gpg is still **experimental** — the API may change
- With `commit.gpgsign=true`, the Trezor must be connected for every commit

---

## 11. FIDO U2F / FIDO2 Support

| Feature | FIDO U2F (FIDO1) | FIDO2 / WebAuthn |
|---|---|---|
| Standard | FIDO Alliance, 2014 | FIDO Alliance, 2018 |
| Also known as | U2F | WebAuthn, CTAP2, Passkeys |
| Purpose | 2nd factor only | Passwordless or 2nd factor |
| Resident keys (Passkeys) | ✗ | ✓ stored on device |
| User verification (PIN/biometric) | ✗ | ✓ optional or required |
| Phishing resistance | ✓ origin-bound | ✓ origin-bound + attestation |
| Works without password | ✗ | ✓ passwordless login |
| **Trezor One** | **✓** | **✗** |
| **Trezor Model T / Safe 3/5** | **✓** | **✓** |

**Trezor One supports FIDO U2F only** — not FIDO2/WebAuthn or Passkeys.

### Setup

Register the Trezor directly in your browser or service's security key settings
— no additional software required beyond the udev rule (Section 1.4).

### Works with

- Google, GitHub, GitLab, Dropbox, Bitbucket
- Any service at https://fidoalliance.org or https://2fa.directory

---

## 12. SSH Authentication

### How it works

`trezor-agent` acts as an SSH agent bridge. It exports the public key derived
from your Trezor identity and signs authentication challenges on-device.

```
SSH client → trezor-agent → Trezor (signs challenge) → SSH server
```

### 12.1 Export public key

```bash
trezor-agent identity://ssh/user@remotehost
```

This prints the public key for the given identity. Add it to
`~/.ssh/authorized_keys` on the remote server.

### 12.2 Connect via SSH

```bash
trezor-agent identity://ssh/user@remotehost -- ssh user@remotehost
```

Or start a persistent agent socket:

```bash
trezor-agent identity://ssh/user@remotehost &
export SSH_AUTH_SOCK=$(trezor-agent --sock-path)
ssh user@remotehost
```

### 12.3 Use with Git over SSH (GitHub)

```bash
# 1. Export public key for GitHub identity
trezor-agent identity://ssh/git@github.com

# 2. Add to GitHub:
#    Settings → SSH and GPG keys → New SSH key
#    Paste the ecdsa-sha2-nistp256 line

# 3. Connect
trezor-agent identity://ssh/git@github.com -- ssh -T git@github.com
```

### 12.4 Persistent agent in shell session

```bash
eval $(trezor-agent identity://ssh/user@remotehost --ssh-agent)
ssh user@remotehost
git push
```

---

## 13. 2FA / FIDO U2F — Examples

### 13.1 GitHub

1. **Settings → Password and authentication → Two-factor authentication**
2. **"Add new method"** → **"Security key"** → **"Register new security key"**
3. Insert Trezor → tap when prompted → name it → **Save**

### 13.2 Google Account

1. **myaccount.google.com → Security → 2-Step Verification**
2. **"Security keys"** → **"Add security key"**
3. Insert Trezor → tap → name it → **Done**

### 13.3 GitLab

1. **Preferences → Account → Two-Factor Authentication**
2. **"WebAuthn device"** → Insert Trezor → tap

### 13.4 General flow

1. Go to the service's security settings
2. Find **"Security key"**, **"Hardware key"**, or **"FIDO U2F"**
3. Insert Trezor → click Register → tap device button

> Always keep backup 2FA (recovery codes) in case the Trezor is lost.

---

## 14. Get Wallet Addresses

> Always quote BIP32 derivation paths to prevent shell issues with `'`.

```bash
# Ethereum
trezorctl ethereum get-address -n "m/44'/60'/0'/0/0"
```
```bash
# Bitcoin — Legacy (P2PKH)
trezorctl btc get-address -n "m/44'/0'/0'/0/0" -t p2pkh
```
```bash
# Bitcoin — SegWit bech32 (P2WPKH) — recommended
trezorctl btc get-address -n "m/84'/0'/0'/0/0" -t p2wpkh
```
```bash
# Bitcoin — P2SH-SegWit
trezorctl btc get-address -n "m/49'/0'/0'/0/0" -t p2sh
```
```bash
# Litecoin
trezorctl ltc get-address -n "m/44'/2'/0'/0/0" -t p2pkh
```
```bash
# Dogecoin
trezorctl doge get-address -n "m/44'/3'/0'/0/0" -t p2pkh
```
```bash
# Stellar (XLM)
trezorctl stellar get-address -n "m/44'/148'/0'"
```
```bash
# Ripple (XRP)
trezorctl xrp get-address -n "m/44'/144'/0'/0/0"
```

If passphrase is active, you will be prompted after PIN entry.

---

## 15. Session Management

```bash
# Clear session cache on host (device stays unlocked)
trezorctl clear-session
```

| Command | Effect |
|---|---|
| `clear-session` | Removes host-side session cache — device stays unlocked |
| `lock-device` | Locks device firmware — PIN required on next access |

---

## 16. Login Script

A minimal script to unlock the Trezor and confirm authentication without
exposing the derived address.

```bash
#!/bin/bash
# Note: Passphrase protection can be disabled on the Trezor device.
# To disable it, run: trezorctl set passphrase off
trezorctl get-address -n "m/44'/0'/0'/0/0" > /tmp/trezor_out
result=$(cat /tmp/trezor_out)
rm -f /tmp/trezor_out
if [ -n "$result" ]; then
    echo "Login successful, you can logout with 'trezorctl clear-session'"
else
    echo "Login failed"
fi
```

Save as `trezor-login.sh` and make executable:

```bash
chmod +x trezor-login.sh
./trezor-login.sh
```

---

## 17. Runtime Flow

```
Connect Trezor
      ↓
PIN entry (device matrix — firmware handles this directly)
      ↓
Passphrase (if active — entered on host via pinentry or env variable)
      ↓
Command executes (signing, address derivation, SSH auth)
```

| Step | Handled by |
|---|---|
| PIN matrix display | Trezor firmware |
| PIN input | User via device buttons / keypad |
| Passphrase prompt | pinentry (host UI) |
| Signing / key derivation | Trezor firmware (on-device) |
| SSH / GPG bridge | trezor-agent |
| Device communication | trezorctl / python-trezor |
