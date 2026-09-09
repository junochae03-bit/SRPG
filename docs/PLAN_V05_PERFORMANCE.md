# V0.5 client performance and minimal delivery

Baseline: published V0.5 tag 505b390; main adc979a. User requested a minimal runnable client in D:/SRPG and diagnosis/fix of severe lag.

Scope: reproduce actual frame stalls; measure CPU/render/loading paths; fix demonstrated hotspots; export an updated client and copy only required executable/data/license files to the designated empty directory. Original projects and assets stay in place. Do not replace the published V0.5 tag or upload personal saves. Gameplay scope was expanded by the user as recorded below; further unrelated content expansion remains outside this task.

1. [complete] Profile the current EXE and a comparable instrumented source run at 1920x1080 using isolated save copies. Baseline town first draw stalled 1,113.788 ms; HUD metadata repeated at p50 0.739 ms. Runtime pixel keying across 41 costume/equipment sheets took 10,138.18 ms. Root accepted these measured paths before changing their readers. Root runs Godot serially.
2. [complete] Make focused fixes in the measured paths and add a repeatable performance check. Prepared RGBA loading takes 636.078 ms for all 41 sheets and matches every legacy output byte (247 assertions). Interim town HUD p50 is 0.241 ms and first draw 234.480 ms. Final nine-scenario results: town first draw 187.813 ms, HUD p50 0.296 ms. Full HD visual checks passed. See PERFORMANCE_V051.ko.md. Hidden window throttling and a separate active user client prevent a universal FPS claim.
3. [complete] Run relevant model/UI tests, then the project gate (`tools/verify_v01.py`) and rebuilt EXE checks. Package through the versioned build tools. Preserve original source saves and verify copies rather than overwriting them.
4. [complete] Delivered the verified executable, PCK and required notices to D:/SRPG with preserved local records. Exact installed executable launch and file hashes passed. Published V0.5.1 from merge 044787e3 after explicit user approval; all four release asset sizes and server SHA256 digests match the local packages. Original V0.5 remains unchanged. See PUBLICATION_V051.json.

Verification commands and profiling scenario names will be recorded as the measured path is established. No success claim may rely only on the previous 202,684 functional checks: those checks did not establish smooth frame times on the user's play session.

## Added user requirements

- Increase enemy hit volumes to better match visible monster bodies, with boundary/attack geometry tests. Avoid enlarging movement collision or enemy attack reach implicitly.
- Let the user name character/costume appearances (scope confirmed by user). Persist aliases separately and preserve stable internal IDs and saved references.
- Fix portrait/icon cropping, including the HUD portrait shown in the reference, and verify all relevant UI at Full HD.
- Title: replace the new-adventurer wording with an adventure-start action and show each saved character's actual level/name on its record slot. Avoid duplicate start controls.
- Creation uses only the class's default appearance. Costumes move to an in-game shop paid with gold; existing owned/equipped costumes and progress must remain valid.
- Reduce excessive decorative background props while preserving biome identity, walkable entrance clearance and stable alpha transitions.
- Replace the ESC text instruction sheet with a visual keyboard rebinding screen. Support real remapping, conflict handling, reset/save/restart and visible HUD key updates; preserve mouse attack charging/release and modal typing behavior.
- Replace oversized ornamental PopupMenu frames with restrained borders and safe padding. Audit skill tags, branches, class selectors and inventory choices so decorations never cover text.

Full source gate: 264,711 PASS; exported EXE: 71 runs PASS; exact D:/SRPG EXE restored two isolated record copies and 23 persistent fields each. Nine original delivery files verified. V0.5.1 is published at https://github.com/junochae03-bit/SRPG/releases/tag/V0.5.1. A subsequent user request adds a separate local level-100 test save to the empty third slot; it is not part of the public release assets.

Focused checks already passed: `tools/run_hidden_check.py prepared_art_v05` (247), `tools/run_hidden_check.py wardrobe_v05` (74). Final game delivery uses V0.5.1; published V0.5 is immutable. The active user client lives in the OneDrive desktop `StelRPG-V0.5-Windows` directory; use its current slot 1/2 files for the final copy into D:/SRPG, preserving originals and excluding saves from archives. Do not terminate that user process.

Concurrent V0.6 character art work belongs to a separate task. Its new assets/documents stay out of the V0.5.1 commit and package until reviewed and integrated later.

Owner checkpoints: root handles prepared render data, creation/title/costume purchase and actual input integration; UI agent owns HUD/portrait/minimap/tree performance; environment/combat agent owns prop density and enemy hit geometry; DB agent owns lightweight metadata and registered render-cache provenance. Godot execution stays serialized through root during measurement.
