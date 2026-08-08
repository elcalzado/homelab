# Secrets (sops-nix)

One age keypair per host plus an admin keypair on the workstation. Each
`<host>.yaml` is encrypted to that host's key and the admin key, so a host
decrypts only its own secrets.

`.sops.yaml` has a rule per file and no catch-all so a new host errors with "no
matching creation rules found" until you add one.

## Adding a host

```bash
age-keygen -o age-<host>.txt          # private half -> password manager
age-keygen -y age-<host>.txt          # public half  -> a new .sops.yaml rule
sops -e -i secrets/<host>.yaml        # then set sops.defaultSopsFile
```

`-e` is used to encrypt, `-i` is for in-place.

Every host needs `guster/passwordHash`, or `guster` has no password and no `sudo`
and root login and SSH passwords are both off.

```bash
nix --extra-experimental-features 'nix-command flakes' run --inputs-from . nixpkgs#mkpasswd -- -m yescrypt
```

## Editing

Run sops from the repo root so `path_regex` matches.

```bash
sops secrets/<host>.yaml              # edit
```
