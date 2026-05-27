# Trezor GPG Key Setup for Git Commit Signing

Complete setup, usage, and recovery of a GPG key based on the **Trezor Model T** for signing Git commits.

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

Plug in the Trezor Model T and enter your PIN.

### 2.2 Generate key

```bash
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

The key is stored in `~/.gnupg-trezor`.

### 2.3 Set GNUPGHOME permanently

```bash
echo 'export GNUPGHOME="$HOME/.gnupg-trezor"' >> ~/.bashrc
source ~/.bashrc
```

### 2.4 Get key fingerprint

```bash
gpg --list-keys
```

Note the 40-character fingerprint (e.g. `0D51A98FB69A6887ED489FC1514E25BFCC1CCF35`).

---

## 3. Configure Git

```bash
git config --global user.signingkey YOUR_FINGERPRINT
git config --global commit.gpgsign true
git config --global gpg.program gpg
```

Verify:
```bash
git config --global --list | grep -E "signing|gpg"
```

---

## 4. Add Public Key to GitHub

### 4.1 Export public key

```bash
gpg --export --armor YOUR_FINGERPRINT
```

### 4.2 Add to GitHub

1. Open https://github.com/settings/keys
2. Click **"New GPG key"**
3. Paste the entire block including `-----BEGIN PGP PUBLIC KEY BLOCK-----`
4. Click **"Add GPG key"**

> **Important:** The commit author email must match the email on the GPG key
> for GitHub to show **Verified**. Use the GitHub no-reply address in both:
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

> **Note:** `[uncertain]` is normal for self-signed keys without Web of Trust.
> GitHub will still show **Verified** as long as the email addresses match.

---

## 6. Backup and Recovery

### 6.1 What to back up

The private key **never leaves the Trezor** — it cannot be exported. Back up:

| What | Where | How |
|---|---|---|
| **Trezor seed (24 words)** | On the Trezor | Paper or metal plate — keep offline |
| **Public key** | `~/.gnupg-trezor/` | Export to `.asc`, store in password manager |
| **Key fingerprint** | Noted above | Password manager |
| **`--time=0`** | This README | Ensures identical key reproduction |

### 6.2 Export public key

```bash
gpg --export --armor YOUR_FINGERPRINT > ~/trezor-gpg-public.asc
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
trezor-gpg init --time=0 "First Last <email@example.com>"

# 5. Set environment permanently
echo 'export GNUPGHOME="$HOME/.gnupg-trezor"' >> ~/.bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 6. Configure Git (see Section 3)
```

---

## 7. Multiple Machines

On each machine:

1. Install `trezor-agent` (Section 1)
2. Regenerate key with `--time=0` — always gives the same fingerprint (Section 6.3)
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
```bash
git commit --no-gpg-sign -m "message"
```

---

## 9. Important Notes

- The **Trezor seed** is the only true backup — whoever has the seed can restore the key on any device
- `nistp256` (ECDSA) is the algorithm used — secure for current use cases, not post-quantum
- trezor-gpg is still **experimental** — the API may change
- With `commit.gpgsign=true`, the Trezor must be connected and unlocked for every commit
