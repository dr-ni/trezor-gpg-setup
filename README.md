# Trezor GPG Key Setup for Git Commit Signing

This document describes the complete setup, usage, and recovery of a GPG key based on the **Trezor Model T** for signing Git commits.

---

## Prerequisites

- Trezor Model T
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

### 1.2 Add to PATH

The installed scripts land in `~/.local/bin` — add permanently to your shell:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 1.3 Verify installation

```bash
trezor-gpg --version
trezorctl version
```

---

## 2. Create GPG Key

### 2.1 Connect Trezor

Plug in the Trezor Model T via USB and unlock it (enter PIN).

### 2.2 Generate key

```bash
trezor-gpg init --time=0 "First Last <email@example.com>"
```

> **Important:** Always use `--time=0`. This sets the key creation timestamp to Unix Epoch (1970-01-01), which allows you to regenerate the **exact same key** on any machine at any time — as long as you have the Trezor seed.
>
> To verify your timestamp:
> ```bash
> GNUPGHOME=~/.gnupg-trezor gpg --list-keys --with-colons | grep "^pub"
> ```
> A date of `1970-01-01` confirms `--time=0` was used.
> If you did not use `--time=0` during the first `init`, note the exact timestamp printed in the output.

The key is stored in `~/.gnupg-trezor`. If the directory already exists, remove it first:

```bash
rm -rf ~/.gnupg-trezor
trezor-gpg init "First Last <email@example.com>"
```

### 2.3 Set GNUPGHOME permanently

```bash
echo 'export GNUPGHOME="$HOME/.gnupg-trezor"' >> ~/.bashrc
source ~/.bashrc
```

### 2.4 Note the key fingerprint

```bash
GNUPGHOME=~/.gnupg-trezor gpg --list-keys
```

Example output:
```
sec   nistp256 1970-01-01 [SC]
      0D51A98FB69A6887ED489FC1514E25BFCC1CCF35
uid           [ultimate] Uwe Niethammer <68241100+dr-ni@users.noreply.github.com>
ssb   nistp256 1970-01-01 [E]
```

Keep the fingerprint `0D51A98F...` in a safe place.

---

## 3. Configure Git

```bash
# Set signing key
git config --global user.signingkey 0D51A98FB69A6887ED489FC1514E25BFCC1CCF35

# Sign all commits automatically
git config --global commit.gpgsign true

# GPG wrapper so Git uses the correct GNUPGHOME
cat > ~/.local/bin/trezor-gpg-wrapper << 'WRAPPER'
#!/bin/bash
export GNUPGHOME="$HOME/.gnupg-trezor"
exec gpg "$@"
WRAPPER
chmod +x ~/.local/bin/trezor-gpg-wrapper

git config --global gpg.program trezor-gpg-wrapper
```

### 3.1 Verify configuration

```bash
git config --global --list | grep -E "gpg|sign"
```

Expected output:
```
gpg.program=trezor-gpg-wrapper
user.signingkey=0D51A98FB69A6887ED489FC1514E25BFCC1CCF35
commit.gpgsign=true
```

---

## 4. Add Public Key to GitHub

### 4.1 Export public key

```bash
GNUPGHOME=~/.gnupg-trezor gpg --export --armor 0D51A98FB69A6887ED489FC1514E25BFCC1CCF35
```

### 4.2 Add to GitHub

1. Open https://github.com/settings/keys
2. Click **"New GPG key"**
3. Paste the entire block from `-----BEGIN PGP PUBLIC KEY BLOCK-----` to `-----END PGP PUBLIC KEY BLOCK-----`
4. Click **"Add GPG key"**

---

## 5. Test Signing

```bash
# Connect and unlock Trezor
git commit --allow-empty -m "test: GPG signing with Trezor"
git log --show-signature -1
```

Expected output:
```
gpg: Signature made Mon May 25 17:46:56 2026 CEST
gpg:                using ECDSA key 0D51A98FB69A6887ED489FC1514E25BFCC1CCF35
gpg: Good signature from "Uwe Niethammer <...>" [uncertain]
```

> **Note:** `[uncertain]` and the Web of Trust warning are normal for self-created keys without external certification. The signature is technically valid.

---

## 6. Backup and Recovery

### 6.1 What needs to be backed up

The private key **never leaves the Trezor** — it cannot be exported. What you need to back up:

| What | Where | How to back up |
|---|---|---|
| **Trezor seed (24 words)** | On the Trezor | Paper, metal plate |
| **Public key** (`~/.gnupg-trezor`) | Local | Copy to another machine |
| **Key fingerprint** | Noted | Password manager |
| **Creation timestamp** | Printed during `init` | Noted (for exact reproduction) |

### 6.2 Export and back up public key

```bash
GNUPGHOME=~/.gnupg-trezor gpg --export --armor \
  0D51A98FB69A6887ED489FC1514E25BFCC1CCF35 > ~/trezor-gpg-public.asc
```

Store securely — e.g. in a password manager or encrypted USB drive.

### 6.3 Restore key on a new machine

On the new machine:

```bash
# 1. Install trezor-agent
pip3 install trezor-agent --break-system-packages
export PATH="$HOME/.local/bin:$PATH"

# 2. Connect and unlock Trezor

# 3. Regenerate key — always use --time=0 for identical key
trezor-gpg init --time=0 "First Last <email@example.com>"

# 4. Alternative: import backed-up public key
mkdir -p ~/.gnupg-trezor
chmod 700 ~/.gnupg-trezor
GNUPGHOME=~/.gnupg-trezor gpg --import ~/trezor-gpg-public.asc
GNUPGHOME=~/.gnupg-trezor gpg --edit-key 0D51A98FB69A6887ED489FC1514E25BFCC1CCF35
# In the editor: trust → 5 (ultimate) → quit

# 5. Set GNUPGHOME and PATH permanently
echo 'export GNUPGHOME="$HOME/.gnupg-trezor"' >> ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 6. Configure Git (see Section 3)
```

---

## 7. Multiple Machines

On each machine:

1. Install `trezor-agent` (Section 1)
2. Set up `~/.gnupg-trezor` — either via `trezor-gpg init` with the same timestamp or by importing the backed-up public key (Section 6.3)
3. Configure Git (Section 3)
4. Connect Trezor whenever signing commits

The **private key always stays on the Trezor** — no copying between machines needed.

---

## 8. Troubleshooting

### `gpg: WARNING: nothing exported`
`GNUPGHOME` points to the wrong directory:
```bash
export GNUPGHOME=~/.gnupg-trezor
gpg --list-keys
```

### `commit.gpgsign` has no effect
Check if the setting is actually set:
```bash
git config --global --list | grep gpgsign
# If empty:
git config --global commit.gpgsign true
```

### `GPG home directory exists, remove it manually`
The directory must be completely removed before `trezor-gpg init`:
```bash
rm -rf ~/.gnupg-trezor
trezor-gpg init "Name <email>"
```

### Trezor not recognized
```bash
# Check udev rules
ls /etc/udev/rules.d/ | grep trezor
# If missing:
sudo curl -L https://data.trezor.io/udev/51-trezor.rules \
  -o /etc/udev/rules.d/51-trezor.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### Commit fails when Trezor is not connected
With `commit.gpgsign=true` the Trezor must be plugged in and unlocked for every commit. To sign without Trezor temporarily:
```bash
git commit --no-gpg-sign -m "message"
```

---

## 9. Important Notes

- The **Trezor seed** is the only true backup — whoever has the seed can restore the key on any device
- `nistp256` (ECDSA) is the algorithm used — secure for current use cases, not post-quantum
- trezor-gpg is still **experimental** — the API may change
- With `commit.gpgsign=true`, the Trezor must be connected and unlocked for every commit, otherwise the commit will fail
