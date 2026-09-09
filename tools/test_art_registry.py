"""Validate source correspondence and reject broken management DB relationships.

Run after tools/build_database.py, or pass --live runtime/FILE.json for development.
Does not mutate the committed snapshot. Python standard library only.
"""
from pathlib import Path
import argparse
import copy
import json
import sqlite3
import tempfile
import time
import art_registry
import build_database

ROOT=Path(__file__).resolve().parents[1]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--live',type=Path)
    args=parser.parse_args()
    data=json.loads((args.live or ROOT/'docs/database/stelrpg-database.json').read_text('utf8'))
    if args.live:data=build_database.normalize(data)
    build_database.validate(data)
    checks=1
    def rejects(change):
        nonlocal checks
        bad=copy.deepcopy(data)
        change(bad)
        try:art_registry.validate(bad,ROOT)
        except AssertionError:checks+=1;return
        raise AssertionError('Corrupt art registry was accepted')
    rejects(lambda d:d['art_assets'][0].update(file_id='missing'))
    rejects(lambda d:d['art_uses'][0].update(art_id='missing'))
    rejects(lambda d:d['art_uses'][0].update(target_table='equipment',target_id='missing'))
    rejects(lambda d:d['art_assets'][0].update(rect=[0,0,999999,999999]))
    rejects(lambda d:d['art_assets'][0].update(status='available_catalog' if d['art_assets'][0]['status']=='applied' else 'applied'))
    rejects(lambda d:d['art_uses'].__setitem__(slice(None),[u for u in d['art_uses'] if u['art_id']!=d['art_assets'][0]['id']]))
    prepared = next((a for a in data['art_assets'] if a.get('render_cache_file_id')), None)
    if prepared:
        prepared_id = prepared['id']
        def cached_asset(d):return next(a for a in d['art_assets'] if a['id']==prepared_id)
        rejects(lambda d:cached_asset(d).update(render_cache_file_id='missing'))
        rejects(lambda d:cached_asset(d)['metadata']['render_cache'].update(source='res://wrong.png'))
        rejects(lambda d:cached_asset(d)['metadata']['render_cache'].update(key='invalid'))
    with tempfile.TemporaryDirectory(prefix='art-registry-test-',dir=ROOT/'runtime') as temporary:
        path=Path(temporary)/'registry.sqlite'
        build_database.build_sqlite(path,data)
        con=sqlite3.connect(path);con.execute('PRAGMA foreign_keys=ON')
        for sql in ["UPDATE art_assets SET file_id='missing' WHERE rowid=1", "UPDATE art_uses SET art_id='missing' WHERE rowid=1", "UPDATE art_uses SET equipment_id='missing',target_id='missing' WHERE target_table='equipment' AND rowid=(SELECT MIN(rowid) FROM art_uses WHERE target_table='equipment')"]:
            try:con.execute(sql);con.commit()
            except sqlite3.IntegrityError:con.rollback();checks+=1
            else:raise AssertionError('SQLite accepted invalid art foreign key')
        count=con.execute("SELECT COUNT(DISTINCT target_id) FROM art_usage WHERE category='equipment' AND target_table='equipment'").fetchone()[0]
        assert count==2500;checks+=1
        assert con.execute("SELECT COUNT(*) FROM art_catalog WHERE category='floor_tile'").fetchone()[0]==6;checks+=1
        if prepared:
            assert con.execute("SELECT COUNT(*) FROM art_files WHERE representation='rgba_gzip'").fetchone()[0]==41;checks+=1
            assert con.execute("SELECT COUNT(DISTINCT render_path) FROM art_catalog WHERE render_cache_file_id IS NOT NULL").fetchone()[0]==41;checks+=1
            try:con.execute("UPDATE art_assets SET render_cache_file_id='missing' WHERE render_cache_file_id IS NOT NULL");con.commit()
            except sqlite3.IntegrityError:con.rollback();checks+=1
            else:raise AssertionError('SQLite accepted invalid prepared cache foreign key')
        assert not con.execute('PRAGMA foreign_key_check').fetchall();checks+=1
        assert con.execute('PRAGMA integrity_check').fetchone()[0]=='ok';checks+=1
        con.close()
    # Every recorded runtime hash is checked against preserved project bytes.
    for f in data['art_files']:
        assert art_registry.digest(art_registry.local(ROOT,f['path']).read_bytes())==f['sha256'];checks+=1
    for s in data['art_sources']:
        assert art_registry.digest(art_registry.local(ROOT,s['path']).read_bytes())==s['sha256'];checks+=1
    print('ART_REGISTRY_PORTABLE PASS checks='+str(checks)+' files='+str(len(data['art_files']))+' regions='+str(len(data['art_assets']))+' uses='+str(len(data['art_uses'])))


if __name__=='__main__':main()
