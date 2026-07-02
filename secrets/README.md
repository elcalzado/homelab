# Secrets (sops-nix)

## Setup

1. Generate a keypair with `age-keygen -o key.txt`. Place the public key in `.sops.yaml`.

2. Install the private key on the host at `/var/lib/sops-nix/key.txt`and do:
   ```bash
   chmod 600 /var/lib/sops-nix/key.txt
   ```

3. Paste your secret into `<host>.yaml`, then:
   ```bash
   sops -e -i secrets/<host>.yaml
   ```
   Confirm the file is now ciphertext before committing.

## Editing later

```bash
sops secrets/*.yaml    # decrypts to $EDITOR, re-encrypts on save
```
