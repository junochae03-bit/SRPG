"""Package the verified, read-only developer database separately from the game."""
from pathlib import Path
import hashlib,json,sqlite3,zipfile
from engine_path import ROOT
from release_version import VERSION,KEY

source=ROOT/'docs/database'
manifest=json.loads((source/'manifest.json').read_text('utf8'))
for name,entry in manifest['files'].items():
    file=source/name
    assert file.parent==source and file.stat().st_size==entry['bytes']
    assert hashlib.sha256(file.read_bytes()).hexdigest()==entry['sha256'],name
with sqlite3.connect((source/'stelrpg.sqlite').as_uri()+'?mode=ro',uri=True) as connection:
    assert connection.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    assert not connection.execute('PRAGMA foreign_key_check').fetchall()
prefix='StelRPG-'+VERSION+'-Database'
out=ROOT/'releases'/VERSION;out.mkdir(parents=True,exist_ok=True)
archive=out/(prefix+'.zip')
files={name:source/name for name in ['stelrpg.sqlite','stelrpg-database.json','schema.sql','queries.sql','manifest.json']}
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as package:
    package.write(ROOT/'docs/GAME_DATABASE.ko.md',prefix+'/GAME_DATABASE.ko.md')
    package.write(ROOT/'docs/ASSET_REGISTRY_V05.ko.md',prefix+'/ASSET_REGISTRY_V05.ko.md')
    for name,path in files.items():package.write(path,prefix+'/database/'+name)
with zipfile.ZipFile(archive) as package:
    assert len(package.namelist())==7 and package.testzip() is None
digest=hashlib.sha256(archive.read_bytes()).hexdigest()
(out/(prefix+'-SHA256.txt')).write_text(digest+'  '+archive.name+'\n','utf8')
report={'status':'PASS','version':VERSION,'filename':archive.name,'bytes':archive.stat().st_size,'sha256':digest,'entries':7,'counts':manifest['counts']}
(ROOT/'artifacts'/('database-package-'+KEY+'.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),'utf8')
print('DATABASE_PACKAGE PASS',json.dumps(report,ensure_ascii=False))
