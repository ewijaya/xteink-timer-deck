#!/usr/bin/env python3
"""Build the pinned upstream interpreter locally with 32-bit Lua numbers."""
import hashlib
import pathlib
import subprocess
import tarfile
ROOT = pathlib.Path(__file__).resolve().parents[1]
VERSION = '5.5.0'
SHA256 = '57ccc32bbbd005cab75bcc52444052535af691789dba2b9016d5c50640d68b3d'
def setup():
    folder = ROOT/'build/toolchain'
    folder.mkdir(parents=True, exist_ok=True)
    archive = folder/f'lua-{VERSION}.tar.gz'
    if not archive.exists():
        raise SystemExit(f'Missing local Lua source archive: {archive}. Network access is not automatic.')
    assert hashlib.sha256(archive.read_bytes()).hexdigest() == SHA256, 'Lua source checksum mismatch'
    source = folder/f'lua-{VERSION}'
    if not source.exists():
        with tarfile.open(archive) as tar:
            for member in tar.getmembers():
                assert not member.name.startswith('/') and '..' not in pathlib.Path(member.name).parts
            tar.extractall(folder)
    binary = source/'src/lua'
    if not binary.exists():
        subprocess.run(['make', '-C', str(source), '-j2', 'linux', 'MYCFLAGS=-DLUA_32BITS'], check=True)
    subprocess.run([str(binary), '-e', 'assert(_VERSION=="Lua 5.5"); assert(math.maxinteger==2147483647); assert(string.packsize("j")==4 and string.packsize("n")==4)'], check=True)
    return binary
if __name__ == '__main__':
    print(setup())
