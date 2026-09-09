"""Audit shipped source and documentation for invalid Unicode and merge debris."""
from pathlib import Path
import subprocess,sys,re,json
ROOT=Path(__file__).resolve().parents[1]
SUFFIXES={'.gd','.gdshader','.py','.json','.md','.cfg','.godot','.tscn','.tres','.sql','.txt','.toml'}
def audit():
    names=subprocess.check_output(['git','ls-files','-z','--cached','--others','--exclude-standard'],cwd=ROOT).decode('utf-8').split('\0')
    failures=[];count=0
    for name in names:
        p=ROOT/name
        if not name or p.suffix not in SUFFIXES or not p.is_file():continue
        # Separate art teams' unfinished packs are not part of this release.
        if any(t in name for t in ['_v06/','_V06.','_v06.py']):continue
        count+=1
        try:text=p.read_bytes().decode('utf-8-sig',errors='strict')
        except UnicodeDecodeError as e:failures.append(f'{name}: invalid UTF-8 at byte {e.start}');continue
        if name.startswith('game/') and p.suffix in {'.gd','.json','.tscn','.tres','.godot'}:
            display_text=text
            if p.suffix=='.json':
                try:display_text=json.dumps(json.loads(text),ensure_ascii=False)
                except ValueError:failures.append(f'{name}: invalid JSON')
            if any(0x3400<=ord(c)<=0x4dbf or 0x4e00<=ord(c)<=0x9fff or 0xf900<=ord(c)<=0xfaff for c in display_text):
                failures.append(f'{name}: non-Korean CJK ideograph in runtime text')
        for line_number,line in enumerate(text.splitlines(),1):
            if chr(0xfffd) in line or any(0xd800<=ord(c)<=0xdfff for c in line):failures.append(f'{name}:{line_number}: damaged Unicode')
            if re.match(r'^(<{7}|>{7})\s',line):failures.append(f'{name}:{line_number}: merge conflict marker')
    for failure in failures:print(failure)
    print(f'TEXT_ENCODING checks={count} failures={len(failures)}')
    return not failures
if __name__=='__main__':sys.exit(0 if audit() else 1)
