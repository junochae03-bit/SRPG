"""Assign reviewed size classes to art/species IDs; runtime remains untouched."""
import json
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/design/normal_monster_expansion'


def main():
    art=json.loads(Path('D:/SSRPG/RPG2/art/MONSTER_DB_HANDOFF_20260913.json').read_text(encoding='utf-8'))['monsters']
    expansion=json.loads((OUT/'catalog.json').read_text(encoding='utf-8'))['monsters']
    db=json.loads((ROOT/'docs/database/stelrpg-database.json').read_text(encoding='utf-8'))
    names={v['asset_id']:v['name_ko'] for v in art};names.update({v['id']:v['name'] for v in expansion})
    groups={
        'small': 'rat cave_bat forest_root_shrew crystal_salt_mite lava_ash_hopper ice_moss_hare machine_oil_tick twilight_sap_bat',
        'medium_small': 'shade imp fairy beetle spellbook ember_slime frost_slime spider goblin_archer goblin_shaman spore_lantern_moth core_rune_leech core_bound_grimoire acorn_slinger grave_lantern frost_penguin snow_wisp abyss_urchin magnetic_orb forest_spore_millipede crystal_echo_gecko flood_silt_skater spore_compost_slug ice_frost_louse machine_copper_crow twilight_bark_isopod nebula_prism_worm core_seal_beetle',
        'medium': 'bat clockwork fox skeleton goblin_captain flood_rustclaw_crab flood_bell_nautilus spore_blade_cricket lava_coal_salamander lava_vent_snail machine_saw_wheel machine_mortar_tripod nebula_quartz_scorpion nebula_comet_cuttlefish thorn_maw bone_serpent coffin_mimic sand_mummy glass_cobra abyss_angler coral_mantis bronze_centipede steam_scarecrow rime_lynx flood_reed_eel spore_hook_mantis lava_slag_mole nebula_dust_ray core_ink_hound',
        'medium_large': 'mole orc_axeman orc_champion centurion sentinel spore_crown_toad core_horned_ram briar_stag glacier_walrus moss_owlbear geode_pangolin chain_jailer cinder_bison dune_djinn',
        'large': 'warden golem flood_bastion_tortoise lava_obsidian_rhino machine_foundry_ogre nebula_crown_manta dune_sphinx boss_flood_anchor_admiral boss_core_crowned_wraith',
        'colossal': 'boss_spore_threefold_hydra boss_lava_caldera_drake boss_machine_siege_engine boss_nebula_starwhale',
    }
    labels=['소형','중소형','중형','중대형','대형','초대형'];ratios=[.5,1.2,2,3,6,10]
    classes=[dict(id=k,name=n,ratio=v,ratio_status='retained_comparison_value' if k=='small' else 'user_defined') for k,n,v in zip(groups,labels,ratios)]
    assigned={};runtime_ids={v['id'] for v in db['monsters']};new_ids={v['id'] for v in expansion}
    for size,ids in groups.items():
        cls=next(v for v in classes if v['id']==size)
        for mid in ids.split():
            assert mid in names and mid not in assigned,mid
            assigned[mid]=dict(monster_id=mid,name=names[mid],size_class=size,ratio=cls['ratio'],
                scope='existing_species' if mid in runtime_ids else 'expansion_proposal' if mid in new_ids else 'art_only_candidate',
                runtime_status='not_applied',basis='체형·생태 역할·공격 실루엣 기준 배정; 사용자 시각 조정 가능')
    assert set(assigned)==set(names),(set(names)-set(assigned),set(assigned)-set(names))
    raid_sizes=['large','large','large','colossal','colossal','large','colossal','large','colossal','large']
    overrides=[]
    for r,size in zip(sorted(db['raids'],key=lambda x:x['id']),raid_sizes):
        cls=next(v for v in classes if v['id']==size)
        overrides.append(dict(raid_id=r['id'],name=r['name'],base_monster_id=r['monster_id'],size_class=size,ratio=cls['ratio'],runtime_status='not_applied'))
    data=dict(status='assigned_design_runtime_pending',measurement='visible_sprite_outer_height_relative_to_reference_character',
        character_reference='동일한 기준 캐릭터의 외곽 표시 높이 1.0; 캐릭터 코스튬/공격 포즈마다 재계산하지 않음',
        collision_policy='표시 크기만 배정. 충돌·히트박스·사거리·스탯·스폰 수 변경 없음',
        precedence='레이드 ID 지정값 > 종별 지정값; 정예라는 이유만으로 추가 확대하지 않음',
        classes=classes,assignments=list(assigned.values()),raid_overrides=overrides,
        counts=dict(species=len(assigned),by_size=dict(Counter(v['size_class'] for v in assigned.values())),
                    by_scope=dict(Counter(v['scope'] for v in assigned.values())),raid_overrides=len(overrides)))
    (OUT/'size_assignments.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (OUT/'size_classes.json').write_text(json.dumps({k:data[k] for k in ['status','measurement','collision_policy','classes']},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    lines=['# 몬스터별 크기 배정','','캐릭터 외곽 높이 대비 비율입니다. 게임에는 아직 미반영이며, 종별 배정은 사용자 시각 조정을 위한 초기안입니다. 소형0.5배는 이전 비교값을 유지했습니다.','','|등급|높이 비율|종수|','|---|---|---|']
    for cls in classes:lines.append(f"|{cls['name']}|{cls['ratio']:g}배|{data['counts']['by_size'][cls['id']]}|")
    for cls in classes:
        lines+=['',f"## {cls['name']} · {cls['ratio']:g}배",'', ' / '.join(v['name'] for v in assigned.values() if v['size_class']==cls['id'])]
    lines+=['','## 레이드 개체 별도 배정','','|레이드|기반 종|비율|','|---|---|---|']
    for v in overrides:lines.append(f"|{v['name']}|{v['base_monster_id']}|{v['ratio']:g}배|")
    lines+=['','## 관리 범위','','- 기존 런타임 24종, 확장 설계 40종, 그 외 접수 아트 후보28종까지 총92종에 배정했습니다. 후보 아트 배정은 해당 종의 게임 등록을 뜻하지 않습니다.','- 종 ID와 레이드 ID를 분리합니다. 같은 파수목·골렘 기반이라도 레이드 외형마다 다른 크기를 적용할 수 있습니다.','- 신체 충돌·공격 범위·이동 경로는 자동 확대하지 않습니다. 대형/초대형은 문·통로와 캐릭터 가림 검토가 필요합니다.','- 기존 확장 DB의 display_height_px는 이전 참고값으로만 보존하고 size_class 및 display_ratio가 새 설계 기준입니다.']
    (OUT/'SIZE_ASSIGNMENTS.ko.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps(data['counts'],ensure_ascii=False))


if __name__=='__main__':main()
