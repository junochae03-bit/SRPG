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
