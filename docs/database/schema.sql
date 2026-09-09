PRAGMA foreign_keys=ON;
PRAGMA user_version=1;
CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);
CREATE TABLE families(id TEXT PRIMARY KEY,name TEXT NOT NULL);
CREATE TABLE classes(id TEXT PRIMARY KEY,name TEXT NOT NULL,family_id TEXT NOT NULL REFERENCES families(id),base_class_id TEXT REFERENCES classes(id),description TEXT NOT NULL,weapon TEXT NOT NULL);
CREATE TABLE assets(id TEXT PRIMARY KEY,path TEXT NOT NULL,x REAL NOT NULL,y REAL NOT NULL,width REAL NOT NULL CHECK(width>0),height REAL NOT NULL CHECK(height>0),metadata_json TEXT NOT NULL);
CREATE TABLE rarities(id INTEGER PRIMARY KEY CHECK(id BETWEEN 0 AND 4),name TEXT NOT NULL,color TEXT NOT NULL,option_unlock INTEGER NOT NULL);
CREATE TABLE equipment(id TEXT PRIMARY KEY,name TEXT NOT NULL,family_id TEXT NOT NULL REFERENCES families(id),class_id TEXT REFERENCES classes(id),slot TEXT NOT NULL,tier INTEGER NOT NULL CHECK(tier BETWEEN 0 AND 9),rarity INTEGER NOT NULL REFERENCES rarities(id),required_level INTEGER NOT NULL,bonus INTEGER NOT NULL,asset_id TEXT NOT NULL REFERENCES assets(id),option_summary TEXT NOT NULL);
CREATE UNIQUE INDEX equipment_combination ON equipment(family_id,COALESCE(class_id,''),slot,tier,rarity);
CREATE TABLE monsters(id TEXT PRIMARY KEY,name TEXT NOT NULL,role TEXT NOT NULL,health INTEGER NOT NULL,damage INTEGER NOT NULL,speed REAL NOT NULL,attack_range REAL NOT NULL,xp INTEGER NOT NULL,gold INTEGER NOT NULL,ai TEXT NOT NULL,display_height REAL NOT NULL,asset_id TEXT NOT NULL REFERENCES assets(id),patterns_json TEXT NOT NULL,stagger_json TEXT NOT NULL);
CREATE TABLE floors(id INTEGER PRIMARY KEY CHECK(id BETWEEN 1 AND 100),name TEXT NOT NULL,level INTEGER NOT NULL,required_level INTEGER NOT NULL,tier INTEGER NOT NULL,terrain TEXT NOT NULL,guardian_id TEXT NOT NULL REFERENCES monsters(id),is_raid INTEGER NOT NULL,lore TEXT NOT NULL);
CREATE TABLE raids(id TEXT PRIMARY KEY,floor_id INTEGER UNIQUE NOT NULL REFERENCES floors(id),monster_id TEXT NOT NULL REFERENCES monsters(id),name TEXT NOT NULL,health INTEGER NOT NULL,damage INTEGER NOT NULL,xp INTEGER NOT NULL,gold INTEGER NOT NULL,patterns_json TEXT NOT NULL,stagger_json TEXT NOT NULL);
CREATE TABLE appearances(id TEXT PRIMARY KEY,floor_id INTEGER NOT NULL REFERENCES floors(id),monster_id TEXT NOT NULL REFERENCES monsters(id),role TEXT NOT NULL,raid_id TEXT REFERENCES raids(id),level INTEGER NOT NULL,health INTEGER NOT NULL,damage INTEGER NOT NULL,xp INTEGER NOT NULL,gold INTEGER NOT NULL,speed REAL NOT NULL);
CREATE TABLE drops(id TEXT PRIMARY KEY,monster_id TEXT NOT NULL REFERENCES monsters(id),entry_key TEXT NOT NULL,name TEXT NOT NULL,kind TEXT NOT NULL,slot TEXT,rarity INTEGER NOT NULL REFERENCES rarities(id),chance REAL NOT NULL CHECK(chance BETWEEN 0 AND 1),amount INTEGER NOT NULL CHECK(amount>0),roll_mode TEXT NOT NULL,asset_id TEXT NOT NULL REFERENCES assets(id),entry_json TEXT NOT NULL,UNIQUE(monster_id,entry_key));
CREATE TABLE raid_drops(id TEXT PRIMARY KEY,raid_id TEXT NOT NULL REFERENCES raids(id),rarity INTEGER NOT NULL REFERENCES rarities(id),chance REAL NOT NULL CHECK(chance BETWEEN 0 AND 1),slot_probability REAL NOT NULL CHECK(slot_probability BETWEEN 0 AND 1),amount INTEGER NOT NULL CHECK(amount=1),tier INTEGER NOT NULL,roll_mode TEXT NOT NULL,UNIQUE(raid_id,rarity));
CREATE TABLE skills(id TEXT PRIMARY KEY,class_id TEXT NOT NULL REFERENCES classes(id),name TEXT NOT NULL,effect TEXT NOT NULL,max_rank INTEGER NOT NULL,required_level INTEGER NOT NULL,parent_mode TEXT NOT NULL,target_id TEXT REFERENCES skills(id),description TEXT NOT NULL,asset_id TEXT NOT NULL REFERENCES assets(id),node_json TEXT NOT NULL);
CREATE TABLE skill_parents(skill_id TEXT NOT NULL REFERENCES skills(id),parent_id TEXT NOT NULL REFERENCES skills(id),required_rank INTEGER NOT NULL,mode TEXT NOT NULL,PRIMARY KEY(skill_id,parent_id));
CREATE TABLE skill_ranks(skill_id TEXT NOT NULL REFERENCES skills(id),rank INTEGER NOT NULL CHECK(rank>0),metrics_json TEXT NOT NULL,profile_json TEXT NOT NULL,stagger_base REAL NOT NULL CHECK(stagger_base>=0),stagger_value REAL NOT NULL CHECK(stagger_value>=0),stagger_grade TEXT NOT NULL,stagger_multiplier REAL NOT NULL CHECK(stagger_multiplier>=1),PRIMARY KEY(skill_id,rank));
CREATE INDEX appearances_by_monster ON appearances(monster_id,floor_id);
CREATE INDEX drops_by_slot_rarity ON drops(slot,rarity);
CREATE INDEX skills_by_class ON skills(class_id,effect);
CREATE VIEW equipment_dungeon_sources AS
 SELECT DISTINCT e.id equipment_id,d.id drop_id,a.floor_id,d.monster_id,d.chance,'independent_per_entry' probability_kind
 FROM equipment e JOIN drops d ON d.slot=e.slot AND d.rarity=e.rarity
 JOIN appearances a ON a.monster_id=d.monster_id JOIN floors f ON f.id=a.floor_id AND f.tier=e.tier;
CREATE VIEW equipment_raid_sources AS
 SELECT e.id equipment_id,d.id drop_id,r.floor_id,r.monster_id,d.chance grade_chance,d.slot_probability,d.chance*d.slot_probability joint_slot_chance
 FROM equipment e JOIN raid_drops d ON d.rarity=e.rarity AND d.tier=e.tier JOIN raids r ON r.id=d.raid_id;
