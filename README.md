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
>
> **Device recommendation for terminal/headless use:**
> **Trezor One** is the best choice for terminal and script-based workflows.
> It is the only Trezor model that allows PIN entry from the terminal via the
> numeric keypad matrix. All other models (Safe 3, Model T) require PIN entry
> on the device touchscreen and cannot be used headlessly.

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
```

```bash
source ~/.bashrc
```

### 1.3 Verify installation

```bash
trezor-gpg --version
```

```bash
trezorctl version
```

### 1.4 Install udev rules (required for Trezor USB access)

```bash
sudo curl -L https://data.trezor.io/udev/51-trezor.rules \
  -o /etc/udev/rules.d/51-trezor.rules
```

```bash
sudo udevadm control --reload-rules
```

```bash
sudo udevadm trigger
```

---

## 2. Environment Variables

Set these permanently in `~/.bashrc`:

```bash
echo 'export GNUPGHOME="$HOME/.gnupg-trezor"' >> ~/.bashrc
```

TTY / SSH session:
```bash
echo 'export TREZOR_PIN_ENTRY_BINARY=/usr/bin/pinentry-tty' >> ~/.bashrc
```

Desktop / X11:
```bash
echo 'export TREZOR_PIN_ENTRY_BINARY=/usr/bin/pinentry-gtk-2' >> ~/.bashrc
```

```bash
echo 'export TREZOR_PASSPHRASE=""' >> ~/.bashrc
```

```bash
echo 'export TREZOR_PASSPHRASE_ON_DEVICE=0' >> ~/.bashrc
```

```bash
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
> GNUPGHOME=~/.gnupg-trezor gpg --list-keys
> ```
> A date of `1970-01-01` confirms `--time=0` was used.

If the directory already exists, remove it first:

```bash
rm -rf ~/.gnupg-trezor
```

```bash
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

Set signing key:
```bash
git config --global user.signingkey YOUR_FINGERPRINT
```

Sign all commits automatically:
```bash
git config --global commit.gpgsign true
```

Create GPG wrapper so Git always uses the correct GNUPGHOME:
```bash
cat > ~/.local/bin/trezor-gpg-wrapper << 'WRAPPER'
#!/bin/bash
export GNUPGHOME="$HOME/.gnupg-trezor"
exec gpg "$@"
WRAPPER
```

```bash
chmod +x ~/.local/bin/trezor-gpg-wrapper
```

```bash
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

If `user.signingkey` is missing, add it:
```bash
git config --global user.signingkey YOUR_FINGERPRINT
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
```

```bash
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
  YOUR_FINGERPRINT
```
```bash
GNUPGHOME=~/.gnupg-trezor gpg --export --armor \
  YOUR_FINGERPRINT > ~/trezor-gpg-public.asc
```

### 7.3 Restore key on a new machine

**1. Install trezor-agent:**
```bash
pip3 install trezor-agent --break-system-packages
```

```bash
export PATH="$HOME/.local/bin:$PATH"
```

**2. Install udev rules:**
```bash
sudo curl -L https://data.trezor.io/udev/51-trezor.rules \
  -o /etc/udev/rules.d/51-trezor.rules
```

```bash
sudo udevadm control --reload-rules && sudo udevadm trigger
```

**3. Connect and unlock Trezor.**

**4a. Regenerate key** — requires same seed, passphrase, identity string, timestamp:
```bash
rm -rf ~/.gnupg-trezor
```

```bash
trezor-gpg init --time=0 "First Last <email@example.com>"
```

**4b. Alternative: import backed-up public key:**
```bash
mkdir -p ~/.gnupg-trezor && chmod 700 ~/.gnupg-trezor
```

```bash
GNUPGHOME=~/.gnupg-trezor gpg --import ~/trezor-gpg-public.asc
```

```bash
GNUPGHOME=~/.gnupg-trezor gpg --edit-key YOUR_FINGERPRINT
```

In the GPG editor: `trust` → `5` (ultimate) → `quit`

**5.** Set environment permanently (see Section 2).

**6.** Configure Git (see Section 4).

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
```

```bash
gpg --list-keys
```

### `commit.gpgsign` has no effect
```bash
git config --global --list | grep gpgsign
```

```bash
git config --global commit.gpgsign true
```

### `GPG home directory exists, remove it manually`
```bash
rm -rf ~/.gnupg-trezor
```

```bash
trezor-gpg init --time=0 "Name <email>"
```

### Trezor not recognized
```bash
ls /etc/udev/rules.d/ | grep trezor
```

```bash
sudo curl -L https://data.trezor.io/udev/51-trezor.rules \
  -o /etc/udev/rules.d/51-trezor.rules
```

```bash
sudo udevadm control --reload-rules
```

```bash
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
Fixed keypad positions (what you type):
  7  8  9
  4  5  6
  1  2  3
```

The Trezor display shows a scrambled layout each time, for example:
```
  3  7  5
  8  2  9
  1  4  6
```

To enter a 6-digit PIN, e.g. **2-7-4-9-1-5**, look at the Trezor display
and find where each digit appears, then type its **position**:

| PIN digit | Appears at position | Type |
|---|---|---|
| 2 | bottom-center | `2` |
| 7 | top-left | `7` |
| 4 | middle-left | `4` |
| 9 | middle-right | `6` |
| 1 | bottom-left | `1` |
| 5 | middle-center | `5` |

So you type: `7` `2` `4` `6` `1` `5` — not the digits themselves.

The layout changes every time you enter your PIN. Always look at the
Trezor display, not the keyboard.

### `pinentry` / passphrase errors with trezor-agent
```bash
export TREZOR_PASSPHRASE=""
```

```bash
export TREZOR_PASSPHRASE_ON_DEVICE=0
```

Note: this activates empty passphrase mode and disables Hidden Wallet.

### `gpg: signing failed: End of file`
Stale trezor-gpg-agent processes are blocking USB access:
```bash
pkill -f trezor-gpg-agent
```

```bash
git commit
```

### Shell quoting errors with BIP32 paths
Always quote derivation paths to prevent shell interpretation of `'`:

Correct:
```bash
trezorctl ethereum get-address -n "m/44'/60'/0'/0/0"
```

Wrong — shell will interpret unquoted apostrophes:
```bash
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
```

```bash
export SSH_AUTH_SOCK=$(trezor-agent --sock-path)
```

```bash
ssh user@remotehost
```

### 12.3 Use with Git over SSH (GitHub)

Export public key for GitHub identity:
```bash
trezor-agent identity://ssh/git@github.com
```

Add to GitHub: **Settings → SSH and GPG keys → New SSH key** — paste the `ecdsa-sha2-nistp256` line.

Connect:
```bash
trezor-agent identity://ssh/git@github.com -- ssh -T git@github.com
```

### 12.4 Persistent agent in shell session

```bash
eval $(trezor-agent identity://ssh/user@remotehost --ssh-agent)
```

```bash
ssh user@remotehost
```

```bash
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

Ethereum:
```bash
trezorctl ethereum get-address -n "m/44'/60'/0'/0/0"
```

Bitcoin — Legacy (P2PKH):
```bash
trezorctl btc get-address -n "m/44'/0'/0'/0/0" -t p2pkh
```

Bitcoin — SegWit bech32 (P2WPKH) — recommended:
```bash
trezorctl btc get-address -n "m/84'/0'/0'/0/0" -t p2wpkh
```

Bitcoin — P2SH-SegWit:
```bash
trezorctl btc get-address -n "m/49'/0'/0'/0/0" -t p2sh
```

Litecoin:
```bash
trezorctl ltc get-address -n "m/44'/2'/0'/0/0" -t p2pkh
```

Dogecoin:
```bash
trezorctl doge get-address -n "m/44'/3'/0'/0/0" -t p2pkh
```

Stellar (XLM):
```bash
trezorctl stellar get-address -n "m/44'/148'/0'"
```

Ripple (XRP):
```bash
trezorctl xrp get-address -n "m/44'/144'/0'/0/0"
```

If passphrase is active, you will be prompted after PIN entry.

---

## 15. Session Management

Clear session and lock the device (PIN required on next access):
```bash
trezorctl clear-session
```

| Command | Effect |
|---|---|
| `clear-session` | Clears host-side session cache and locks the device — PIN required on next access |

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
```

```bash
./trezor-login.sh
```

---

## 17. Windows Setup

> **Note:** trezor-agent (GPG/SSH bridge) is **not supported on Windows**.
> Only `trezorctl` (device communication, wallet addresses, session management)
> works natively. For GPG commit signing on Windows, use WSL2 (see below).

### 17.1 Install trezorctl on Windows

**Requirements:** Python 3.10+, pip

```powershell
pip install trezor
```

```powershell
trezorctl version
```

### 17.2 Trezor USB access on Windows

No udev rules needed — Windows uses WinUSB/libusb via Zadig if the device
is not recognized automatically.

If `trezorctl list` returns nothing:

1. Download Zadig from https://zadig.akeo.ie
2. Plug in Trezor
3. In Zadig: **Options → List All Devices** → select **Trezor** → install **WinUSB**

### 17.3 Environment variables on Windows

Set in PowerShell (current session):
```powershell
$env:GNUPGHOME = "$env:USERPROFILE\.gnupg-trezor"
```

Set permanently:
```powershell
[System.Environment]::SetEnvironmentVariable("GNUPGHOME", "$env:USERPROFILE\.gnupg-trezor", "User")
```

### 17.4 GPG commit signing on Windows (via WSL2)

trezor-agent does not run on Windows. The recommended approach is WSL2:

**1. Install WSL2 with Ubuntu:**
```powershell
wsl --install
```

**2.** Inside WSL2, follow the Linux setup (Sections 1–6) as normal.

**3.** Configure Git inside WSL2 — commits signed there will show as **Verified** on GitHub.

**4. Forward Trezor USB to WSL2 using usbipd:**

Install usbipd-win (once):
```powershell
winget install usbipd
```

List USB devices:
```powershell
usbipd list
```

Attach Trezor to WSL2 (replace X-Y with your bus ID):
```powershell
usbipd attach --wsl --busid X-Y
```

Verify inside WSL2:
```bash
lsusb | grep -i trezor
```

### 17.5 Login script on Windows (PowerShell)

```powershell
# trezor-login.ps1
# Note: Passphrase protection can be disabled on the Trezor device.
# To disable it, run: trezorctl set passphrase off
$result = trezorctl get-address -n "m/44'/0'/0'/0/0" 2>$null
if ($result) {
    Write-Host "Login successful, you can logout with 'trezorctl clear-session'"
} else {
    Write-Host "Login failed"
}
```

Run:
```powershell
.\trezor-login.ps1
```

### 17.6 Session management on Windows

```powershell
trezorctl clear-session
```

---

## 18. Runtime Flow

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
