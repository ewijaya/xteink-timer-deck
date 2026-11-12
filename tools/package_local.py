#!/usr/bin/env python3
"""Explicit opt-in community packaging for personal USB installation only.

No normalization: the exact XTM3 bytes go into XTDT. No upload or device access.
The owner approved local app packaging; this command is always local-only.
"""
import argparse
import hashlib
import importlib.util
import json
import struct
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]

PIN='4290dcab76ad0317803421f442cbc7e01a90a8ad'
HASHES={'tools/vendor/mksd.py':'8787787c61ec2f37202e845c6ca0bfab0dfc04a41da59bc4d395432786ab4e9e',
        'xtpack.py':'76580e3feedf5a19aac75b217246c5a69f5bbfb964907dcd68f837276227baa6',
        'tools/vendor/xtapp.py':'2e87c7630fcb46aea0b4d9c0ba17d84bf3d3d5b62cb05ba0c0d2bb830736a06a'}

def package(synthetic=False):
    vendor=ROOT/'tools/vendor/xtpack'
    for name,expected in HASHES.items():
        assert hashlib.sha256((vendor/name).read_bytes()).hexdigest()==expected,'Packager source changed: '+name
    spec=importlib.util.spec_from_file_location('missal_xtpack',vendor/'xtpack.py')
    pack=importlib.util.module_from_spec(spec);spec.loader.exec_module(pack)
    source=ROOT/'app'
    man=json.loads((source/'manifest.json').read_text())
    expected=json.loads((ROOT/'PRD.md').read_text().split('## Appendix A.')[1].split('```json\n')[1].split('```')[0])
    expected['version']=man['version']
    assert man==expected, 'Manifest differs from Appendix A'
    assert (source/'lib/gen/version.lua').read_text()=="return '"+man['version']+"'\n"
    pack.validate_manifest(man,str(source/'manifest.json'))
    code=[(str(p.relative_to(source)),p.read_bytes()) for p in sorted(source.rglob('*.lua'))]
    code.sort(key=lambda pair:(pair[0]!='index.lua',pair[0]))
    assert len(code)<=40
    data=[]
    icon_path=source/'assets'/f'{man["app_icon_s"]}.png'
    with Image.open(icon_path) as image:
        assert image.size==(88,88) and image.mode=='1'
        expected_pixels=list(image.convert('L').get_flattened_data())
        icon=pack.build_xic_1bpp(image)
    icons=pack.build_xtab([('app_icon_s',icon)])
    raw,key=pack.build_container(man,pack.device_pubkey(),code,data,icons=icons)
    _,decoded=pack.xtapp.read_licorice_container(raw)
    assert dict(pack.xtapp.read_licorice_code(raw,key))==dict(code)
    sections=pack.xtapp.licorice_sections(raw)
    assert sections['data'][1]==0, 'Unexpected data section'
    # Independently locate and decode the actual launcher section and its pixels.
    offset,size=sections['icons'];stored=raw[offset:offset+size]
    assert stored==icons and stored[:4]==b'XTAB'
    count,table,data_start,total=struct.unpack_from('<IIII',stored,8)
    assert count==1 and table==64 and data_start==104 and total==len(stored)
    assert stored[64:88].rstrip(b'\0')==b'app_icon_s'
    image_offset,image_size,w,h,fmt=struct.unpack_from('<IIHHB',stored,88)
    xic=stored[data_start+image_offset:data_start+image_offset+image_size]
    assert (w,h,fmt)==(88,88,1) and xic[:4]==b'XIC\0'
    assert struct.unpack_from('<HH',xic,4)==(88,88)
    pixels=[0 if xic[24+y*11+x//8] & (0x80>>(x%8)) else 255 for y in range(88) for x in range(88)]
    assert pixels==expected_pixels,'Packaged icon pixels differ from PNG'
    for field,value in man.items(): assert decoded[field]==value
    suffix=''
    assert len(raw)<200000, 'Package exceeds 200 KB'
    out=ROOT/'dist'/f'{man["app_id"]}-{man["version"]}{suffix}.xtapp';out.parent.mkdir(exist_ok=True)
    out.write_bytes(raw)
    report={'path':str(out.relative_to(ROOT)),'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),
      'app_id':man['app_id'],'code_files':len(code),'data_files':len(data),'data_bytes':sum(len(b) for _,b in data),
      'roundtrip':f'byte-identical {len(code)} Lua and {len(data)} data files; all 7744 launcher pixels match','packager_commit':PIN,'packager_sha256':HASHES,
      'icon':{'key':'app_icon_s','width':88,'height':88,'bits_per_pixel':1,'sha256':hashlib.sha256(icon_path.read_bytes()).hexdigest()},
      'source_sha256':{name:hashlib.sha256(blob).hexdigest() for name,blob in code+data},
      'device_verified':False,'synthetic':synthetic}
    out.with_suffix('.json').write_text(json.dumps(report,indent=2)+'\n')
    (ROOT/'dist/SHA256SUMS').write_text(report['sha256']+'  '+out.name+'\n')
    print(json.dumps(report,indent=2));return out

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--synthetic',action='store_true')
    a=p.parse_args();package(a.synthetic)
