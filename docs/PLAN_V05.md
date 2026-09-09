# V0.5 implementation plan

Baseline: e01b80f on origin/main. Worktree: SRPG-v04, branch feature/constellation-character-v04.

## Scope

Rebuild the growth screen as an illustrated, connected skill map; introduce behavior-changing choices, shared SP costs and cross-skill synergies while preserving the existing 20 class identities and 610 original skill IDs. Add a character sheet before creating an empty save slot and a portrait/name/dialogue panel before NPC services. Remove persistent instructions for obvious controls and save status. Preserve existing characters and their property.

Online multiplayer and unrelated combat/content expansion remain deferred. Source art and other agents' work stay intact; the latest user steering below expands runtime art integration into V0.5.

## Latest steering: complete project art integration

The user requested all prepared backgrounds, monster sprites, skill effects, semantic icons and character sheets to be applied in V0.5. Inspect the latest completed handoffs, connect each usable asset to actual game behavior and include only runtime files. Repair the two unsafe costume sheets before including them. Keep original model IDs, class/equipment restrictions, damage and stagger contracts. The prepared release is postponed until this expanded scope passes verification.

- Environment agent: forest_environment/world_art/new environment reader and assets; enemy-only draw_actor branch and biome asset DB mapping. Integrate 18 environment sheets across the four completed packs, plus 6 monster and 6 boss sheets, with proper keying and feet. Coordinate walkable decoration with collision agent.
- Collision agent: reproduce tutorial/dungeon spawn immobility, repair walkable spawn/entry route, test all 100 floor starts and actual movement. Do not conflate foliage occlusion with physics.
- UI agent: default to one understandable skill branch with optional full map and automatic prerequisite reveal; preserve all choices. Remove the circled inventory instructions, starter-kit button and pause/close footer.
- Character art thread: prepare all 33 character sheets as safe runtime frames with keying and feet in assets/costume_v04, costume_art_v04.gd, shaders and dedicated tests. Review weapon/motion eligibility: 30 are player costumes and 3 are NPC-only. Root registers them for the appropriate role without copying old main/UI files.
- Root: selective semantic icon/VFX integration, costume registration, automatic initial equipment when creating a character (remove reliance on the deleted starter button), coherent documentation/DB/export/QA and clean publication.

Expanded proof: used-asset coverage and atlas bounds, all costume motions at common body height, enemy/environment biome rendering, readable branch navigation and inventory, 100-floor start movement, final full source gate and actual exported Windows UI/combat/save checks. Existing play saves and separate source art are preserved.

User steering added during implementation: redesign the title screen as well. Replace the large form and explanatory copy with an original title illustration, readable typographic logo and concise save-record selection/start action. The character name remains exclusively in the creation sheet. Generate one title-only background using the built-in image tool; save its prompt and provenance. This does not integrate or alter the other agents' gameplay environment packs. Verify the title in the graphical UI test and exported build.

## Contract and ownership

### New floor tiles and asset database (2026-09-09)

Inspect the completed `RPG2/art/tiles/fantasy-tiles-20260909` handoff and replace blurry or broken ground with its new tiles. Keep room topology, collision, entrance clearance and camera transforms unchanged. Select appropriate surfaces for tutorial, town and all ten dungeon biomes; verify seams and camera zoom in actual Full HD renders. Only used tile sources/catalogs belong in the source repository.

Register applied art in the management database as well as gameplay definitions. The SQLite/JSON registry must expose category, original source/provenance, runtime file hash, atlas region/frame and actual consumers for backgrounds, tiles, monsters, characters, icons, effects and equipment. Preserve the existing equipment/monster/drop/skill tables and source fingerprint checks. Unfinished equipment themes and unused source extraction packs remain excluded.

Ownership: environment agent owns the floor reader/rendering/assets and focused tests; database agent owns asset registry generation, queries and DB tests; root owns main integration, complete gate, exported package verification, backup/sync and publication. The completed equipment pack at `be30d7b` contributes 115 item drawings through the memory RGBA reader. Its focused checks have passed, but any earlier full gate or Windows QA predating equipment/tiles/registry were repeated on the final source for V0.5.

### Full HD and legibility steering (2026-09-09)

The user additionally requested a 1920×1080 default window, larger skill icons, a substantial HUD/inventory/navigation improvement, no text covered by ornamental frames, plain first-job names 검사/궁수/마법사, and appearance choices appropriate to the selected job. Use a 1600×900 logical canvas with canvas-items rendering at 1920×1080. Center existing modal coordinates, use the wider canvas for the inventory, and keep the HUD independent of the battle camera zoom. Test the actual full-resolution images and pointer input; outer panel containment alone does not prove that decorative borders leave the text visible.

- Tree/preview agent: large skill nodes and clear single-branch navigation; full-alpha preview bounds and per-job costume session tests.
- Environment/inventory agent: larger bag cells/equipment slots, scrolling detailed item content, safe frame insets and filtered appearance lists.
- HUD agent: larger six-skill grid, compact/collapsible quest tracking, separated quick actions and all 15 job-resource panels with measured text/icon insets.
- Root: resolution and input transforms, boss camera framing, creator headings and spacing, appearance eligibility and model validation, class names, whole-project validation and release.
- Character art thread: classify the actual visible weapons and motion of every new costume; preserve raster files and provide per-class matching evidence.

Acceptance: no section title under a frame ornament; no character preview over a title; full descriptions reachable without clipping; forbidden job/appearance combinations rejected by both UI and simulation; previous save property preserved; screenshots are 1920×1080 and the real mouse still reaches the visible controls.

Implemented source state: 1920×1080 default window, 1600×900 logical canvas; default-branch tree glyphs at least 48 logical px, HUD skill buttons 96 px, inventory cells 64 px. Full-map glyphs may shrink with zoom. The inventory uses three illustrated regions, fixed action buttons, scrolling long item names/comparisons/options, actual upgrade counts, and inner padding around metal/gold decorations. Appearance lists are class-filtered and scroll within a 440 px maximum-height popup. The five creation classes remain 검사, 궁수, 마법사, 도적 and 격투가.

The 33 new character sheets have 528 reader frames in total, including the 3 NPC-only sets. The 30 player costumes are restricted by visible weapon and job; the 3 NPC sets are placed as town visitors. The 24 additional GAT appearances were also reviewed, producing 57 explicit matching records together with the new art. Unknown/withheld entries do not become player choices. Changing to an incompatible class restores a compatible base appearance without discarding property or progress.

All four completed environment/monster packs are integrated: 30 referenced PNGs, 108 environment props, 18 new common-monster and 6 boss variants with idle/attack key poses. Four biomes retain their earlier monster art. Tutorial, town and the ten dungeon biomes consume the environment catalog, while spawn, exit and walkable entry routes remain free of decoration. The final whole-project gate and exported EXE validation passed; publication is recorded in step 5.

- Data agent: constellation_catalog.gd, skill_build.gd (pure allocation rules), game_database.gd, database generation and relevant new tests. Keep original 610 nodes and their ranks compatible. Add 45 specialization nodes per class in five connected clusters (at least 50 total choices even for starter rogue/fighter). Navigation nodes may improve range, speed, duration or efficiency; notable and keystone nodes must have actual supported behavior/conditions. Five keystones, at most two selected, explicit exclusive pairs; 1/3/6 SP for minor/notable/keystone, shared level-1 budget. Coordinate supported effect IDs with combat agent before writing catalog claims.
- Combat agent: constellation_effects.gd and existing active_skills, player_combat, job_combat, scaling/balance hooks and combat tests. Preserve source IDs/modes and class resources, resolve delivery separately. Apply advertised gains and tradeoffs to real casts/hits and preserve one stagger budget per cast.
- UI agent: skill_tree_ui.gd, skill_graph_view.gd, related UI tests. Existing illustrated atlas, pan/zoom graph, stable readable detail panel, search/tags, allocation reason, exclusive choice and synergy information. Six active slots and stats/class pages stay available. Avoid persistent obvious-operation instructions.
- Root: content.gd delegations, simulation/local_session persistence and commands, character_creation.gd, character_sheet_ui.gd, npc_dialogue.gd, main/minimap/HUD integration, regression gates, build/release/sync.
- Pure rule module initializes with original skill/class dictionaries from Content.initialize_jobs(); exposes nodes_for(class_id), node_state(p,id), path_plan(p,id), preview(p,id,next_rank), spent_points(p), available_points(p), validate_build(p), effects(p). New nodes persist in constellation_allocations; original nodes remain in skill_ranks. No Content preload back-edge in rules. Combat effects live separately from allocation rules.
- Save schema 7 adds skill_build_version=2, constellation_allocations={}, creation_points=0 or 10. Existing ranks and loadout remain valid because original rules/IDs are preserved; no forced refund is necessary. Full skill reset clears both allocation sets atomically in town, including lingering casts and class state. Existing stats get no free creation points. New sheet allocates exactly 10 points among the five current stats.

## Sequence and proof

1. [complete] Inspect current model/UI/combat/save consumers and official PoE reference. Read-only agent reviews identified mode dispatch and save-validation hazards. Checkpoint: root accepted separate source/delivery fields and compatibility-preserving catalog.
2. [complete] Implement the independent model, combat, graph and character/dialogue work streams under the contract above. Focused model/combat/UI checks and integration reviews have been performed; the expanded art and Full HD scope passed the final whole-project gate. Checkpoint: root review of supported effects and UI/API integration; update this plan if the contract changes.
   Proof: engine --headless --path game --editor --import --quit; python tools/run_hidden_check.py skill_build_v04; constellation_combat_v04; character_creation_v04; skill_tree_ui_v04 graphics; character_dialogue_ui_v04 graphics.
3. [complete] Save validation, town-only respec, live database/codex and intentional legacy-test updates are integrated. Focused checks cover invalid creations/builds rejecting without writes, existing inventory/name/progression preservation, persistent choices, exclusivity and different real combat advantages for equal-SP builds. The final DB snapshot was regenerated after source freeze and the full gate passed.
   Proof: python tools/build_database.py; python tools/build_database.py --check; python tools/verify_v01.py. Inspect command logs, not merely exit status. Checkpoint: root completion review against all user requirements and actual screenshots.
4. [complete] Package V0.5 and exercise the exported executable. Update concise play guide and verification/release documents; inventory only used runtime files. Test fresh creation, existing slot, NPC dialogue/service/close, graph pan/search/learn/restart and combat.
   Proof: python tools/asset_inventory.py; python tools/build_v01.py --version V0.5; python tools/test_export_v01.py --version V0.5; python tools/package_v01.py --version V0.5; python tools/package_database.py --version V0.5 (inspect each CLI before invocation). Checkpoint: rendered screens and export logs reviewed by root; no original saves in archives.
5. [pending] Deliver the verified client from its separate V0.5 release directory; leave the existing RPG2 source, separate art and original saves in place. Commit/merge/push curated source and publish V0.5 assets to the authorized repository. Verify release server digests, branch and user launch path. No force-push or existing-release replacement.

Godot checks require the already established elevated Windows launch path. Use the installed Godot 4.6 console executable and bundled Python; runtime logs, engines, templates, saves and extracted source packs stay ignored.

## Release target update

The user raised the client target to V0.5 while the expanded art/database work was still in progress. The current feature worktree and `_v04` module/test/asset names are retained as implementation identifiers. No V0.4 publication is claimed. The complete gate, Windows build and GitHub release target V0.5; save schema remains 7. Local delivery uses a separate release directory without replacing the older RPG2 checkout.
