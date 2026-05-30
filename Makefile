INSTALL_DIR := $(HOME)/.local/bin
UDEV_RULES  := /etc/udev/rules.d/51-trezor.rules
BASHRC      := $(HOME)/.bashrc

.PHONY: all install install-deps install-udev install-scripts install-env \
        install-git uninstall help

all: help

help:
	@echo "Trezor GPG Setup — available targets:"
	@echo ""
	@echo "  make install        Full install (all steps below)"
	@echo "  make install-deps   Install trezor-agent via pip"
	@echo "  make install-udev   Install udev rules for USB access"
	@echo "  make install-env    Add environment variables to ~/.bashrc"
	@echo "  make install-git    Configure Git for GPG signing"
	@echo "  make install-scripts Install trezor-login and trezor-logout scripts"
	@echo "  make uninstall      Remove installed scripts and udev rules"

install: install-deps install-udev install-env install-scripts
	@echo ""
	@echo "Done. Run 'source ~/.bashrc' to apply environment variables."
	@echo "Then follow README.md Section 3 to generate your GPG key."

install-deps:
	@echo "==> Installing trezor-agent..."
	pip3 install trezor-agent --break-system-packages
	@echo "==> PATH is managed by ~/.profile — no changes needed."

install-udev:
	@echo "==> Installing udev rules..."
	sudo curl -fsSL https://data.trezor.io/udev/51-trezor.rules \
		-o $(UDEV_RULES)
	sudo udevadm control --reload-rules
	sudo udevadm trigger
	@echo "==> Udev rules installed: $(UDEV_RULES)"

install-env:
	@echo "==> Adding environment variables to $(BASHRC)..."
	@grep -qF 'GNUPGHOME' $(BASHRC) || \
		echo 'export GNUPGHOME="$$HOME/.gnupg-trezor"' >> $(BASHRC)
	@grep -qF 'TREZOR_PIN_ENTRY_BINARY' $(BASHRC) || \
		echo 'export TREZOR_PIN_ENTRY_BINARY=/usr/bin/pinentry-tty' >> $(BASHRC)
	@grep -qF 'TREZOR_PASSPHRASE=' $(BASHRC) || \
		echo 'export TREZOR_PASSPHRASE=""' >> $(BASHRC)
	@grep -qF 'TREZOR_PASSPHRASE_ON_DEVICE' $(BASHRC) || \
		echo 'export TREZOR_PASSPHRASE_ON_DEVICE=0' >> $(BASHRC)
	@echo "==> Environment variables added."

install-scripts:
	@echo "==> Installing scripts to $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)
	install -m 755 trezor-login  $(INSTALL_DIR)/trezor-login
	install -m 755 trezor-logout $(INSTALL_DIR)/trezor-logout
	@echo "==> Scripts installed:"
	@echo "      $(INSTALL_DIR)/trezor-login"
	@echo "      $(INSTALL_DIR)/trezor-logout"

install-git:
	@echo "==> Configuring Git for GPG signing..."
	@mkdir -p $(INSTALL_DIR)
	@printf '#!/bin/bash\nexport GNUPGHOME="$$HOME/.gnupg-trezor"\nexec gpg "$$@"\n' \
		> $(INSTALL_DIR)/trezor-gpg-wrapper
	@chmod +x $(INSTALL_DIR)/trezor-gpg-wrapper
	git config --global gpg.program trezor-gpg-wrapper
	git config --global commit.gpgsign true
	@echo "==> Git configured. Set signing key with:"
	@echo "      git config --global user.signingkey YOUR_FINGERPRINT"

uninstall:
	@echo "==> Removing installed scripts..."
	rm -f $(INSTALL_DIR)/trezor-login
	rm -f $(INSTALL_DIR)/trezor-logout
	rm -f $(INSTALL_DIR)/trezor-gpg-wrapper
	@echo "==> Removing udev rules..."
	sudo rm -f $(UDEV_RULES)
	sudo udevadm control --reload-rules
	@echo "==> Uninstall complete."
	@echo "    Remove environment variables from $(BASHRC) manually if needed."
