from pathlib import Path
import base64, zlib, hashlib
parts = [
    '.github/core_v6_payload_1.txt',
    '.github/core_v6_payload_1b.txt',
    '.github/core_v6_payload_2.txt',
    '.github/core_v6_payload_3.txt',
    '.github/core_v6_payload_4.txt',
]
payload = ''.join(Path(p).read_text().strip() for p in parts)
data = zlib.decompress(base64.b64decode(payload))
sha = hashlib.sha256(data).hexdigest()
expected = '680b371d26679dec67ffd1f38e54e30c602b0f4999004c0a46340bd9da4e88b5'
if sha != expected:
    raise SystemExit(f'payload sha mismatch {sha}')
Path('papyrus/JM_RE_Core.psc').write_bytes(data)
print('promoted canonical core', sha)
