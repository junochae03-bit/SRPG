"""Follow actual resource references; do not include unused extraction folders."""
from pathlib import Path
import re,hashlib,json
ROOT=Path(__file__).resolve().parents[1]
def referenced_files():
    game=ROOT/'game'
    pending=list((game/'scripts').glob('*.gd'))+[game/'main.tscn',game/'project.godot']
    seen=set()
    while pending:
        path=pending.pop().resolve()
        if path in seen:continue
        if not path.is_file():raise FileNotFoundError(path)
        seen.add(path)
        if path.suffix not in ['.gd','.gdshader','.tscn','.tres','.json','.godot']:continue
        # Prepared-art manifests index a source as `res://file.png|chroma`.
        # The discriminator is not part of the filename; source/path values
        # independently retain both original and prepared dependencies.
        for relative in re.findall(r'res://([^"\s|]+)',path.read_text('utf8')):
            target=(game/relative).resolve()
            if not target.is_relative_to(game.resolve()):continue
            if target.is_dir():raise ValueError('Unresolved dynamic asset directory: '+relative)
            pending.append(target)
    return sorted(seen)
def inventory():
    return [{'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in referenced_files()]
if __name__=='__main__':
    rows=inventory();print(len(rows),'used runtime files;',round(sum(x['bytes'] for x in rows)/1048576,2),'MiB')
    (ROOT/'docs/RUNTIME_FILES.json').write_text(json.dumps(rows,indent=2),'utf8')
