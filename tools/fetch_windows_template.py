"""Read only the Windows x64 release entry of the official Godot template ZIP."""
from pathlib import Path
import urllib.request, io, zipfile, hashlib, json
URL='https://github.com/godotengine/godot-builds/releases/download/4.6-stable/Godot_v4.6-stable_export_templates.tpz'
ROOT=Path(__file__).resolve().parents[1]
class RemoteZip(io.RawIOBase):
    def __init__(self):
        with urllib.request.urlopen(urllib.request.Request(URL,headers={'Range':'bytes=0-0'}),timeout=60) as response:
            assert response.status==206, 'Server does not support byte ranges'
            self.url=response.url;self.length=int(response.headers['Content-Range'].split('/')[-1]);response.read()
        self.pos=0
    def seekable(self):return True
    def readable(self):return True
    def tell(self):return self.pos
    def seek(self,offset,whence=0):
        self.pos=offset if whence==0 else self.pos+offset if whence==1 else self.length+offset
        return self.pos
    def read(self,size=-1):
        end=self.length-1 if size<0 else min(self.length-1,self.pos+size-1)
        if self.pos>end:return b''
        req=urllib.request.Request(self.url,headers={'Range':f'bytes={self.pos}-{end}'})
        with urllib.request.urlopen(req,timeout=120) as response:
            assert response.status==206 and response.headers['Content-Range'].startswith(f'bytes {self.pos}-{end}/')
            data=response.read()
        assert len(data)==end-self.pos+1
        self.pos+=len(data);return data
target=ROOT/'tools/godot-templates';target.mkdir(exist_ok=True)
with zipfile.ZipFile(RemoteZip()) as archive:
    names=[n for n in archive.namelist() if 'windows' in n and 'x86_64' in n and 'release' in n]
    print('Official template entries:',names,flush=True)
    records=[]
    for name in names:
        data=archive.read(name) # zipfile verifies the central-directory CRC.
        path=target/Path(name).name;path.write_bytes(data)
        records.append({'name':path.name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'zip_crc32':f'{archive.getinfo(name).CRC:08x}'})
        print(path.name,len(data),flush=True)
(target/'provenance.json').write_text(json.dumps({'source':URL,'integrity':'HTTPS byte ranges; ZIP entry CRC checked; SHA256 of downloaded entries recorded','files':records},indent=2),'utf8')
