# pbzweihander's private infra

```
# iam access key id
terraform console <<< 'local.encrypted_admin_access_key.id'
# iam secret access key
terraform console <<< 'local.encrypted_admin_access_key.encrypted_secret' | base64 -d | keybase decrypt
```
