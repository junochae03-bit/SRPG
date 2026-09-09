"""Check prepared-art relations against the published DB without regenerating it.

This focused check exercises Python enrichment and SQLite relations in a temporary
database. The Godot art_registry_v05 check separately verifies live descriptors.
"""
from pathlib import Path
from contextlib import closing
import copy
import json
import sqlite3
import tempfile
import art_registry
import build_database

ROOT = Path(__file__).resolve().parents[1]


def main():
    data = json.loads((ROOT/'docs/database/stelrpg-database.json').read_text('utf8'))
    manifest = json.loads(art_registry.local(ROOT, art_registry.RENDER_CATALOG).read_text('utf8'))
    by_source = {}
    for entry in manifest['entries'].values():
        assert entry['source'] not in by_source, 'Fixture expects one used chroma key per current source'
        by_source[entry['source']] = entry
    original_assets = {a['id']: (a['path'], copy.deepcopy(a['rect'])) for a in data['art_assets']}
    original_uses = copy.deepcopy(data['art_uses'])
    original_equipment = copy.deepcopy(data['equipment'])
    for a in data['art_assets']:
        if a['path'] in by_source:
            entry = by_source[a['path']]
            a['metadata']['render_cache'] = {'catalog': art_registry.RENDER_CATALOG, 'source': a['path'], 'path': entry['path'], 'key': entry['key']}
    data = art_registry.enrich(data, ROOT)
    art_registry.validate(data, ROOT)
    assert len(data['art_assets']) == 1700 and data['art_uses'] == original_uses
    assert data['equipment'] == original_equipment
    assert all((a['path'], a['rect']) == original_assets[a['id']] for a in data['art_assets'])
    assert len([f for f in data['art_files'] if f['representation'] == 'rgba_gzip']) == 41
    checks = 5
    prepared_id = next(a['id'] for a in data['art_assets'] if a.get('render_cache_file_id'))
    def asset(d): return next(a for a in d['art_assets'] if a['id'] == prepared_id)
    def rejected(change, enrich=False):
        nonlocal checks
        invalid = copy.deepcopy(data)
        change(invalid)
        try:
            if enrich: art_registry.enrich(invalid, ROOT)
            else: art_registry.validate(invalid, ROOT)
        except AssertionError:
            checks += 1
            return
        raise AssertionError('Invalid prepared cache mapping accepted')
    rejected(lambda d: asset(d).update(render_cache_file_id='missing'))
    rejected(lambda d: asset(d)['metadata']['render_cache'].update(key='invalid'), True)
    rejected(lambda d: asset(d)['metadata']['render_cache'].update(source='res://wrong.png'), True)
    rejected(lambda d: asset(d)['metadata']['render_cache'].update(path='res://wrong.rgba.gz'), True)
    def bad_original(d):
        f = next(f for f in d['art_files'] if f['id'] == asset(d)['render_cache_file_id'])
        f['origin']['source_file_id'] = 'missing'
    rejected(bad_original)
    with tempfile.TemporaryDirectory(prefix='prepared-registry-', dir=ROOT/'runtime') as temporary:
        path = Path(temporary)/'check.sqlite'
        build_database.build_sqlite(path, data)
        with closing(sqlite3.connect(path)) as con:
            con.execute('PRAGMA foreign_keys=ON')
            assert con.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'; checks += 1
            assert con.execute('PRAGMA foreign_key_check').fetchall() == []; checks += 1
            assert con.execute("SELECT COUNT(DISTINCT render_path) FROM art_catalog WHERE render_representation='rgba_gzip'").fetchone()[0] == 41; checks += 1
            assert con.execute("SELECT COUNT(DISTINCT target_id) FROM art_usage WHERE category='equipment' AND target_table='equipment' AND render_representation='rgba_gzip'").fetchone()[0] == 2500; checks += 1
            for sql in ["UPDATE art_assets SET render_cache_file_id='missing' WHERE render_cache_file_id IS NOT NULL", "DELETE FROM art_files WHERE representation='rgba_gzip'"]:
                try: con.execute(sql); con.commit()
                except sqlite3.IntegrityError: con.rollback(); checks += 1
                else: raise AssertionError('SQLite accepted a dangling prepared file relationship')
    print('ART_REGISTRY_CACHE PASS checks='+str(checks)+' source_regions=1700 prepared_files=41 files='+str(len(data['art_files']))+' uses='+str(len(data['art_uses'])))


if __name__ == '__main__': main()
