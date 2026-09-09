-- Read-only examples. Percent columns state the event whose probability they show.

-- 1. A reaper can wear rogue-family armor, but only reaper weapons.
SELECT e.id,e.name,r.name grade,e.slot,e.required_level,e.bonus,e.option_summary
FROM equipment e JOIN rarities r ON r.id=e.rarity
WHERE (e.slot='weapon' AND e.class_id='reaper')
   OR (e.slot<>'weapon' AND e.family_id=(SELECT family_id FROM classes WHERE id='reaper'))
ORDER BY e.tier,e.rarity,e.slot;

-- 2. Real scaled monsters on floor 100. The extra elite's displayed level is +3.
SELECT a.floor_id,COALESCE(r.name,m.name) name,a.role,a.level,a.health,a.damage,a.xp,a.gold
FROM appearances a JOIN monsters m ON m.id=a.monster_id LEFT JOIN raids r ON r.id=a.raid_id
WHERE a.floor_id=100 ORDER BY a.role,m.name;

-- 3. Independent drops of a goblin captain: these probabilities do NOT sum to 100%.
SELECT name,kind,slot,100*chance independent_percent,amount
FROM drops WHERE monster_id='goblin_captain' ORDER BY chance DESC;

-- 4. Boss's guaranteed EXTRA item's grade and a chosen slot (e.g. weapon).
SELECT r.floor_id,r.name,g.name grade,100*d.chance extra_item_grade_percent,
       100*d.chance*d.slot_probability extra_item_grade_and_slot_percent
FROM raid_drops d JOIN raids r ON r.id=d.raid_id JOIN rarities g ON g.id=d.rarity
WHERE r.floor_id=100 ORDER BY d.rarity;

-- 5. Exact equipment tier/slot/grade sources. Smartloot binds owner to killer.
SELECT * FROM equipment_dungeon_sources WHERE equipment_id='eq:reaper:weapon:03:1';
SELECT * FROM equipment_raid_sources WHERE equipment_id='eq:reaper:weapon:09:3';

-- 6. All rank metrics and skill stagger for a class (reference damage100/HP1000/TECH0).
SELECT s.id,s.name,s.effect,k.rank,k.metrics_json,k.stagger_grade,k.stagger_value
FROM skills s JOIN skill_ranks k ON k.skill_id=s.id
WHERE s.class_id='breaker' ORDER BY s.id,k.rank;

-- 7. Read the prerequisite web; mode 'any' means one qualified parent is sufficient.
SELECT child.name skill,parent.name prerequisite,p.required_rank,p.mode
FROM skill_parents p JOIN skills child ON child.id=p.skill_id JOIN skills parent ON parent.id=p.parent_id
WHERE child.class_id='reaper' ORDER BY child.id,parent.id;

-- 8. Atlas paths/cells for the art team, without embedding any new source artwork.
SELECT s.id,s.name,a.path,a.x,a.y,a.width,a.height
FROM skills s JOIN assets a ON a.id=s.asset_id WHERE s.class_id='elementalist';

-- 9. Checks used by the generator.
PRAGMA foreign_key_check;
PRAGMA integrity_check;
SELECT raid_id,SUM(chance) FROM raid_drops GROUP BY raid_id HAVING ABS(SUM(chance)-1)>0.00000001;

-- 10. Reaper specializations with explicit SP opportunity costs and tradeoffs.
SELECT n.id,c.name,c.cluster_name,n.type,n.cost,c.effects_text,c.synergy,c.tradeoff,n.exclusive_group
FROM build_nodes n JOIN constellations c ON c.id=n.id
WHERE n.class_id='reaper' ORDER BY c.cluster,n.id;

-- 11. The actual effects combat consumes, separate from displayed Korean names.
SELECT c.name,e.effect_id,e.value FROM constellation_effects e
JOIN constellations c ON c.id=e.node_id JOIN build_nodes n ON n.id=c.id
WHERE n.class_id='reaper' AND n.type='keystone';

-- 12. Original and specialization prerequisite graph with any/all semantics.
SELECT e.* FROM build_edges e JOIN build_nodes n ON n.id=e.node_id
WHERE n.class_id='fighter' ORDER BY e.node_id,e.parent_id;

-- 13. Each class has five keys, but max two may be selected. Each pair below is exclusive.
SELECT g.id,n.id,c.name,g.max_selected FROM exclusive_groups g
JOIN build_nodes n ON n.exclusive_group=g.id JOIN constellations c ON c.id=n.id
WHERE g.class_id='mage' ORDER BY g.id,n.id;

-- 14. Finished art: distinguish runtime mappings from catalog-only availability.
SELECT category,status,COUNT(*) regions FROM art_catalog
GROUP BY category,status ORDER BY category,status;

-- 15. New equipment art follows the actual 2,500 equipment definitions.
SELECT e.id,e.name,a.runtime_path,a.x,a.y,a.width,a.height,a.runtime_sha256
FROM equipment e JOIN art_uses u ON u.equipment_id=e.id
JOIN art_catalog a ON a.id=u.art_id
WHERE e.id='eq:reaper:weapon:09:3';

-- 16. Floor material samples and current theme/layer mapping, not unused walls.
SELECT a.name,a.runtime_path,a.x,a.y,a.width,a.height,u.mapping_json
FROM art_catalog a JOIN art_uses u ON u.art_id=a.id
WHERE a.category='floor_tile' AND u.floor_id=100;

-- 17. The NPC idle pose is applied; its other completed poses remain available.
SELECT id,name,frame,action,status,runtime_path,x,y,width,height
FROM art_catalog WHERE id LIKE 'art:character:costume:pink-beret-gunner:%'
ORDER BY frame;

-- 18. Source identity and every gameplay/catalog consumer of a finished region.
SELECT target_table,target_id,consumer,usage_kind,mapping_json
FROM art_usage WHERE art_id='art:equipment:weapon_reaper_relic';

-- 19. Runtime code references do not imply every library atlas region is used.
SELECT id,name,category,runtime_path,provenance_path FROM art_catalog
WHERE status='available_catalog' ORDER BY category,id;
