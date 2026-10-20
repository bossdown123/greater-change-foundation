#!/usr/bin/env python3
"""Create local-only credentials; never prints secrets or overwrites existing values."""
import hashlib
import os
from pathlib import Path
import secrets

path = Path('.env')
values = dict(line.split('=', 1) for line in path.read_text().splitlines() if line and not line.startswith('#') and '=' in line) if path.exists() else {}
password = secrets.token_urlsafe(24)
salt = secrets.token_bytes(16)
defaults = {
    'GCF_SESSION_SECRET': secrets.token_hex(64),
    'GCF_ADMIN_PASSWORD_HASH': 'pbkdf2:' + salt.hex() + ':' + hashlib.pbkdf2_hmac('sha256', password.encode(), salt, 600000).hex(),
    'GARAGE_RPC_SECRET': secrets.token_hex(32),
    'S3_ACCESS_KEY_ID': 'GK' + secrets.token_hex(16),
    'S3_SECRET_ACCESS_KEY': secrets.token_hex(32),
}
new_password = not values.get('GCF_ADMIN_PASSWORD_HASH')
for key, value in defaults.items():
    if not values.get(key):
        values[key] = value
values['GARAGE_DEFAULT_ACCESS_KEY'] = values['S3_ACCESS_KEY_ID']
values['GARAGE_DEFAULT_SECRET_KEY'] = values['S3_SECRET_ACCESS_KEY']
with path.open('w') as handle:
    os.chmod(path, 0o600)
    handle.write(''.join(f'{key}={value}\n' for key, value in values.items()))
if new_password:
    path = Path('.admin-password')
    with path.open('w') as handle:
        os.chmod(path, 0o600)
        handle.write(password + '\n')
print('Local credentials ready. Initial password is in .admin-password (keep private).')
