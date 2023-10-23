# pbzweihander's private infra

```
# iam access key id
echo local.encrypted_admin_access_key.id | terraform console | rg '^"|"$' -r ''
# iam secret access key
echo local.encrypted_admin_access_key.encrypted_secret | terraform console | rg '^"|"$' -r '' | base64 -d | keybase pgp decrypt
```
