"""Package only approved build files, never saves or development outputs."""
from pathlib import Path
import json,zipfile,hashlib
from engine_path import ROOT
from release_version import VERSION,KEY
OUT=ROOT/'releases'/VERSION/('StelRPG-'+VERSION+'-Windows')
verification=json.loads((ROOT/('artifacts/export-check-'+KEY+'.json')).read_text('utf8'))
assert verification['status']=='PASS'
assert verification['version']==VERSION
manifest=json.loads((ROOT/('artifacts/export-'+KEY+'.json')).read_text('utf8'))
assert verification['executable_sha256']==hashlib.sha256((OUT/'StelRPG.exe').read_bytes()).hexdigest()
assert verification['pck_sha256']==hashlib.sha256((OUT/'StelRPG.pck').read_bytes()).hexdigest()
archive=OUT.parent/('StelRPG-'+VERSION+'-Windows.zip')
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for row in manifest['files']:
        file=OUT/row['name'];assert file.is_file() and file.parent==OUT
        assert hashlib.sha256(file.read_bytes()).hexdigest()==row['sha256'],('Build file changed after export',file.name)
        z.write(file,OUT.name+'/'+file.name)
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert len(z.namelist())==len(manifest['files'])
    assert not any('/saves/' in name or '/tests/' in name or '/runtime/' in name for name in z.namelist())
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
(OUT.parent/'SHA256SUMS.txt').write_text(digest+'  '+archive.name+'\n','utf8')
print('V01_PACKAGE PASS',archive.name,archive.stat().st_size,'bytes',digest,flush=True)
