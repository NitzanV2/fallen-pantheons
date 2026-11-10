# Act 3: The Binding Vault — Theme and Battles

Planning document for the third act’s setting, verbs, enemies, elites, bosses and battle roster. Numbers are first-pass placeholders for the balance sim, in the same spirit as the early Act 2 notes. Card archetypes (Runes / Voyage / Edicts), shop odds and phased implementation stay in `act3_design.md`; this file locks the **place** and the **fights**.

**Status:** battles-first implementation shipped (act shell, vault verbs, enemies/battles/elites/bosses, relics/events, rules). Player cards / fourth archetypes still deferred. Kill-order for elites/bosses is intentional: aggressive vs patient decks should prefer different targets.

---

## 1. Through-line

| Act | Name | What it is |
|---|---|---|
| 1 | The Dying Stars | The living world. A Void portal has torn into the realm; hollow echoes and Void spawn pour through the Reliquary’s ruins. |
| 2 | The Drowned Underworld | The flooded afterlife — Duat, Hades and Helheim run together. Ferries, tolls and weighing. The road *down*. |
| 3 | **The Binding Vault** | The final destination under all three afterlives: the vault where the gods locked what they could not kill. The underworld drowned because these doors are failing. Close them, or the onslaught never stops. |

**Story beat.** Act 1 fights the spill. Act 2 crosses the drowned threshold. Act 3 reaches the lock. Victory is not “another underworld boss” — it is **resealing the vault** so the Void can no longer push through the Reliquary into the living world.

The player is not merely surviving a deeper dungeon. They are finishing the work the pantheons started and abandoned: hold the prisoner, mend the seals, end the invasion at its hinge.

---

## 2. Setting

### Place

Beneath the drowned necropolis lies a sealed complex older than any single pantheon. Norse, Greek and Egyptian bindings are all here — chains of Gleipnir’s kin, Olympian adamant, Egyptian cartouches cut into living stone — wrapped around the same dark. The vault was built by gods who still hated each other, which is why the locks disagree and why they are failing separately.

Rooms are **seals**, **hinges**, **anterooms**, **key-chapels** and **ward galleries**. Nodes on the map sit on cracked doors, gold seams, collapsed pillars and prayer-wheels that still turn.

The Reliquary Core the player carries is not incidental: it is a fragment of the same binding craft. That is why the Void wants it, and why only someone bearing it can reseal the deepest lock.

### Look

| Act | Palette |
|---|---|
| 1 | Purple Void over sandstone and star-ruin |
| 2 | Dark teal water, bone-white stone, ghost-lights |
| 3 | **Warm bronze and cracked gold on charcoal stone**; violet rift-light bleeding through door-seams; chain-shadows |

Act 3 must not read as “more teal” or “more purple.” Gold = still-holding bindings. Violet seams = Void leaking. Charcoal = the vault’s age.

- **Map background:** `game/art/map/background_act3.jpg` — stacked vault floors with mythic architecture (Greek pillars, Egyptian columns, Norse chains, bronze doors). Sparse glowing eyes / few silhouettes ramp upward. Loaded via act `map_bg` (Acts 1–2 keep `background_soft.jpg`).
- **Map tint:** warm bronze at the base (not Act 2 cyan), e.g. `Color(1.05, 0.9, 0.7)` — leave room for violet Void on the top gate.
- **Map read (bottom → top):** warm gold-lit **small** outer seals → mid galleries → dark **largest fortified gate** with Void rift-cracks. Watchers sparse; eyes return near the top. Boss node on that gate.
- **Final-act color thesis:** charcoal stone + living bronze/gold (order still holding) vs sickly violet / bruise-purple Void (the leak). Avoid Act 1 nebula-purple and Act 2 teal as dominant fills.
- **Board:** same 4 lanes × 2 rows. Do **not** delete slots as a default verb (Nidhogg already rots the board; a second shrinking act stacks badly with handlock).
- **Battle backgrounds:** `game/art/battle/background_act3.jpg` (vault antechamber) and **`background_act3_boss.jpg`** (innermost fortified gate + Void seams). Wired in `battle_view` for act 3 / boss.
- **Tiles:** `tile_vault_player.jpg` / `tile_vault_enemy.jpg` — charcoal flagstones with gold inlay and bruise-violet hairline cracks (`BoardView.use_vault_tiles`).

### In-game map preview

Mock of the Act 3 run map as it would read in Godot: Binding Vault backdrop + existing node discs/icons + sidebar chrome. Climb from the outer seals at the bottom to the Void-touched boss door at the top.

**Final-act art pass** (bronze/charcoal vs bruise-violet; pantheon seals; gold veins → violet rifts; sparse eyes; massive fortified top gate with Void seams):

![The Binding Vault — final-act art pass preview](design_art/binding_vault_map_ingame_finalpass.png)

![The Binding Vault — final-act map background](design_art/binding_vault_map_bg_finalpass.jpg)

Game candidate: `game/art/map/background_act3_finalpass.jpg` (also copied to `background_act3.jpg`). Previous iteration kept as `background_act3_prev.jpg` / `binding_vault_map_bg_prev.jpg`.

### Battle boards

Normal Act 3 fights (vault antechamber — gold-inlaid floor, pillars, seals, braziers):

![Binding Vault — battle board](design_art/binding_vault_board.jpg)

Boss fights only (innermost fortified gate with Void rift — separate art):

![Binding Vault — boss board](design_art/binding_vault_board_boss.jpg)

### Concept map

Descending read of the vault (outer seals at the top → innermost door at the bottom). Mood reference only — not the game map texture.

![The Binding Vault — concept map](design_art/binding_vault_map.jpg)

Top to bottom: outer bronze gates → chain galleries and gold-inlaid corridors → cracked prayer wheels / key chapels → violet rift-seams through failing gold → adamant hinges and manacle halls → the innermost sealed door.

### Tone

Ceremony under pressure. Everything was meant to be quiet forever. Now hinges scream, wards flicker, and things that should not have names press against the gold. The fights feel like **breaking into a prison that is also breaking out**.

---

## 3. Act verbs

Each Act 2 verb was one readable rule. Act 3’s kit should teach **bindings, breaches and resealing** — not another river, and not “erase the player’s deck.”

| Mechanic | Rule | Counter / play |
|---|---|---|
| **Bound** | While this unit lives, a named ally (or the battle’s colossus) cannot be killed / cannot Sunder / cannot be targeted. Shown as a gold chain between them. | Kill the Bound unit first, or break its chain with a specific hit. |
| **Sealmark** | A lane or slot is Marked. Marked player slots: units there cannot leave that lane by move or Embark until the mark ends. Marked enemy slots: that enemy cannot be pushed or swapped (Transposition fails). | Kill the sealer, or spend the mark by dealing X damage to the warden that placed it. |
| **Rift** | At end of round, if any **Breach** is open on the board, the Core takes 1 per open Breach (or a Void Spawn appears in the emptiest enemy front). Breaches are tile marks, not deleted slots. | Close Breaches (see Ward), or keep tempo so few exist. |
| **Ward** | A Ward token or unit can **spend itself** (or exhaust) to close one Breach in its lane or an adjacent lane. | Bring a way to answer Rift; don’t ignore Breaches while racing the boss. |
| **Unravel** | This unit’s ATK or a boss phase clock ticks up each round it remains alive. Intent shows the rising number. | Kill it early, or plan for the late spike. |
| **Keybearer** | While this unit lives, a locked door/elite rule stays shut (e.g. the boss’s phase 2 cannot start, or a Bound colossus stays Bound). | Focus the Keybearer; the fight changes when the key falls. |

**Sunder** (from the Primordial scout) can still appear on one elite or one boss phase — a body that splits when the binding fails — but it is not the act’s default identity. The Binding Vault’s default is **chains and cracks**, not flesh giants.

**What this act refuses**

- Silencing keywords or eating the player’s whole archetype for a round (Void-as-act problem).
- Deleting board slots as a common enemy tool.
- Shortening the round clock as a boss identity (spare-round gold must stay meaningful).

---

## 4. Enemies

Placeholders: late-Act-2 strength plus a step. Threat values guide timeout pressure.

### Common / early teachers

| Id | Name | Sketch (ATK / HP / SPD, Threat) | Rule it teaches |
|---|---|---|---|
| seal_warden | Seal Warden | 2 / 6 / 2, T1 | Bound: while it lives, the highest-HP other enemy in its row cannot drop below 1 HP. |
| chain_thrall | Chain Thrall | 3 / 5 / 3, T1 | Sealmark: on death, Marks your front slot in its lane for 2 rounds (cannot move out). |
| rift_mite | Rift Mite | 1 / 3 / 4, T1 | Ranged. On death, opens a Breach in its lane (enemy side marker that still counts for Rift). |
| vault_scribe | Vault Scribe | 2 / 5 / 3, T1 | Ranged. Start of round: if any Breach is open, gains +1 ATK. |
| hinge_guard | Hinge Guard | 2 / 8 / 1, T1 | Taunt. Sealmark on itself: cannot be pushed or swapped. |

### Mid / late pressure

| Id | Name | Sketch | Rule it teaches |
|---|---|---|---|
| gold_seam | Gold Seam | 0 / 10 / 1, T1 | Immovable. Bound to the battle’s largest enemy: that enemy cannot be reduced below half HP until the Seam dies. |
| unraveling_shade | Unraveling Shade | 2 / 6 / 3, T2 | Incorporeal. Unravel: +1 ATK at the start of each round. |
| void_hinge | Void Hinge | 3 / 7 / 2, T2 | End of round: opens a Breach in a random player lane with no Ward answer. |
| cartouche_bound | Cartouche-Bound | 3 / 9 / 2, T2 | Bound to a Rift Mite or Seam if present; if Bound partner dies, this unit gains Frenzy and +2 ATK. |
| adamant_warden | Adamant Warden | 1 / 12 / 1, T2 | Taunt. Ward (enemy version): the first time each round an ally in its lane would die, it survives at 1 HP and this Warden takes 2. |
| key_acolyte | Key Acolyte | 2 / 5 / 4, T2 | Keybearer: while it lives, Breaches cannot be closed. Must die before Wards matter. |
| gleipnir_echo | Gleipnir Echo | 4 / 6 / 4, T2 | Pierce. Sealmark: after it attacks a unit, that unit cannot Reinforces or move this round. |

Reuse Act 2 spice sparingly (one Incorporeal, one ferry wave) so the vault still feels new. Flooded is Act 2’s river — do not make it the Act 3 default terrain. Optional **Cracked** terrain: slot has +1 ATK and takes 1 at end of round (gold under stress) — use lightly.

---

## 5. Battles

Act 2 used ~4 early, ~8–12 late, ~5 elite, 3 bosses. Act 3 starts in the same band. Waves remain `[round, id, lane, row]`.

### Early (floors 1–3) — teach Bound, Breach, Sealmark

| Id | Name | Enemies (sketch) | What it asks |
|---|---|---|---|
| outer_seal | Outer Seal | Seal Warden + Chain Thrall ×2 + Rift Mite back | Kill the Bound partner; don’t ignore the Mite’s Breach |
| chain_gallery | Chain Gallery | Hinge Guard, Chain Thrall, Vault Scribe | Taunt wall + Sealmark death; Scribe rewards open Breaches |
| prayer_wheel | Prayer Wheel | Vault Scribe ×2, Rift Mite ×2 | Rift pressure; clear mites or eat Core drip |
| bronze_threshold | Bronze Threshold | Adamant Warden, Seal Warden, Chain Thrall; one pre-Cracked player slot | Enemy Ward + Bound; learn focus order |

### Late (floors 4–14) — combine verbs, raise stakes

| Id | Name | Enemies (sketch) | What it asks |
|---|---|---|---|
| gold_vein | Gold Vein | Gold Seam, Bound Giant-lite (or Adamant Warden), Rift Mite | Seam gates half-HP; then the body |
| unraveling_hall | Unraveling Hall | Unraveling Shade ×2, Vault Scribe, Hinge Guard | Kill Unravel early or face late ATK |
| key_chapel | Key Chapel | Key Acolyte, Void Hinge, Chain Thrall ×2 | Keybearer blocks closing Breaches |
| adamant_procession | Adamant Procession | Adamant Warden ×2, Seal Warden, Gleipnir Echo | Slow wall; Pierce finisher |
| rift_nave | Rift Nave | Void Hinge ×2, Rift Mite ×2, Vault Scribe; wave: Rift Mite round 3 | Breach economy under ferry pressure |
| cartouche_crypt | Cartouche Crypt | Cartouche-Bound, Gold Seam, Vault Scribe | Egyptian-flavored Bound pair |
| hinge_of_worlds | Hinge of Worlds | Void Hinge, Unraveling Shade, Key Acolyte, Hinge Guard | All verbs at once, lower HP each |
| gleipnir_walk | Gleipnir Walk | Gleipnir Echo ×2, Seal Warden, Chain Thrall | Pierce + Sealmark lockdown |
| broken_litany | Broken Litany | Vault Scribe, Cartouche-Bound ×2, Rift Mite; one Flooded player slot (Act 2 echo) | Reminder that the underworld leaked in |
| innermost_antechamber | Innermost Antechamber | Gold Seam, Adamant Warden, Key Acolyte, Unraveling Shade | Dress rehearsal for boss focus order |

### Elites — five locks, five lessons

Match Act 1–2 elite pool size (5). Each owns a vault verb and a dual kill-order.

| Id | Elite | Identity |
|---|---|---|
| door_of_gleipnir | **The Door of Gleipnir** (Norse-flavored construct; Immovable, width 2, back) | Bound to two Chain Anchors in front. While either Anchor lives, the Door cannot drop below 1 HP. Each round it Sealmarks one of your lanes (units there cannot move). When both Anchors die, the Door Unravels (+2 ATK) and starts opening Breaches. Teaches: clear bindings before the lock. |
| hundred_handed | **The Hundred-Handed** (Greek-flavored prisoner echo; width 2) | Keybearer for its own chains: three Chain Thralls start Bound to it. While any Thrall lives, it cannot be reduced below half HP. At half HP it Sundering-splits into two Arms (lesser units) if no Gold Seam remains. Teaches: Key / Bound / optional Sunder as binding failure. |
| canopic_lock | **The Canopic Lock** (Egyptian-flavored; 0 ATK ward bosslet) | Does not attack. Each round places a Sealmark on your fullest lane and opens a Breach if you leave any lane empty. Two Vault Scribes support it. Killing it closes all Breaches at once. Teaches: Rift economy and not leaving lanes bare (Nun-adjacent without copying Nun). |
| mad_turnkey | **The Mad Turnkey** (Greek-leaning jailer) | Bound to a Key Acolyte (floor 1). Each round Sealmarks your strongest lane, then locks your lowest-HP unit in a Marked lane into a cell for one round (no death; Act 2 Ferry callback without discarding). No prey → opens a Breach. Dual: chip to 1 / cut Key / finish, or kill Key first and reseal. |
| skeleton_key | **The Skeleton Key** (Egyptian-leaning false key) | Keybearer + Unravel. Each round Sealmarks and opens a Breach. Death while any Rift Mite lives tears two Breaches open; death after the Mites seals every Breach. Dual: race the Key (Breach burst) or clear Mites for a clean reseal. |

Act 3 events (5): Turnkey's Bargain, Litany of False Names, Last Prayer Wheel, **Living Seam**, **Abandoned Manacle**.

### Bosses — reseal the vault (one per run)

Beating the Act 3 boss **ends the run in victory** and, in fiction, reseals the innermost door so the Void’s onslaught on the living world fails.

Each boss is a face of the vault: **Warden**, **Prisoner**, **Seal**. Same pattern as Act 2: hint, blurb, map preview once Act 3 starts. HP band ~70–85 before sim tuning.

---

#### Boss A — **The Warden Eternal** (Greek-leaning guardian)

**Fiction.** The god who stayed behind to hold the door. Centuries of watch turned them into the hinge. They believe anyone approaching the vault is a jailbreak — including you. Defeat them to inherit the authority to close the lock.

**Board.** Immovable, back width 2. Two **Door Clerks** in front (nomination officers — not Bound).

**Rules (Tribunal).**

- **Accused.** Only the Accused may damage the Warden; other hits on the Warden are refused (no Core tax). Clerks, Bailiffs, and Warders can still be attacked by anyone. While any Clerk/Bailiff lives, the court nominates your highest-ATK unit(s). Kill them to choose the Accused yourself (Shift-click). The Accused is Sealmarked that planning phase.
- **Board attacks.** Odd rounds: **Contempt of Court** (2 to every non-Accused; whole board if none). Even rounds: **Gavel Sweep** (Warden ATK to every unit in your fullest lane; both fullest lanes in phase 2). Phase 2 Contempt also **Sentences** the highest-HP non-Accused (5 + Sealmark).
- **Door Warders.** Each round the Warden calls Warders (1, or 2 in phase 2) into empty slots, preferring lanes that are **not** the Accused’s — at most **3** officers alive. Killing an officer deals **2** to the Warden.
- **Authority.** +1/round (+2 in phase 2). End of round: Core takes Authority. If the Accused dealt ≥6 (≥8 in phase 2) to the Warden, Authority −2. **Failure to Appear** (0 damage): Sealmark the Accused’s lane again.
- **Phase 2 (half HP).** Door Bailiffs take the floor (forced nomination returns); two Accused; faster Authority; **Gavel** — if an Accused dies, Core 3 and Authority +1. Sentence joins Contempt.

**What it checks.** Who may strike the boss; carry vs chump petitioner; clearing Clerks for agency; Authority clock vs petition burst.

**Victory read.** The Warden’s key falls to the Reliquary. The outer authority of the vault is yours — the door can be commanded shut.

---

#### Boss B — **The Unbound** (Norse-leaning prisoner)

**Fiction.** What the gods chained and could not kill. The Void pouring into Act 1 is its breath through the cracks. It is almost free. You do not negotiate. You drive it back under the gold before the last chain snaps.

**Board.** Width 2 front; not Immovable (it *strains*). Light support (Rift Mite); no permanent Gold Seam.

**Rules.**

- **Unravel.** +1 ATK at the start of each round while the body is still whole. Intent shows the rising ATK.
- **Rift Roar / Shatter.** Whenever it takes 5+ damage in one hit, open a Breach in its lane **and** the Core takes 3.
- **Gold Filament.** On even rounds while whole, a short-lived Filament (6 HP, 2 rounds) strands behind it. While it lives, Unbound takes half damage. Kill it early for full damage; if it expires unkilled, Core takes 3 and a Breach opens.
- **Cascade Sunder.** At half HP it splits into two **Chain-Broke** (inherit ATK, Unravel). Each Chain-Broke at half splits into two **Unbound Remnants** (Pierce, partial ATK inherit; same face as the boss). Each Sunder event deals 2 to the Core and opens a Breach. Empty player slots deal 1 to the Core at end of round until the last husk dies. Chain Weights / Adamant Links pulse behind it while whole — **kill them** to cut its ATK by 2 / 3.

**What it checks.** Burst vs chip (Shatter tax vs Unravel clock); backline tempo vs Filament snaps; finishing gen-1 husks before Pierce gen-2; formation vs empty-slot bleed.

**Victory read.** The prisoner is driven under again. The Reliquary’s light pours into the empty manacles. The portal in the living world starves.

---

#### Boss C — **The Seal of Names** (Egyptian-leaning lock)

**Fiction.** Not a jailer and not a inmate — the lock itself, given will by a thousand cartouches. It is rewriting its own law so the Void can pass. You must break the Seal of Names and rewrite the final cartouche with the Reliquary’s authority.

**Board.** Immovable, back centre width 2. Does little direct attacking early; the board is its scripture.

**Rules.**

- **Litany.** Start of round: Mark the lane with the fewest of your units (leftmost on ties). Each of your units there takes 2; if the lane is empty, open a Breach there and the Core takes 2.
- **False Name.** When planning ends, if you have an unspent Faith, the Seal spends 1 Faith *for you* and draws a Void Web (or Void Taint) into your discard — the lock “corrects” your prayer. If you have 0 Faith, it opens an extra Breach instead.
- **Phase 2 (half HP).** Litany marks two emptiest lanes. Spawns two Vault Scribes. Key Acolyte arrives once; while it lives, Litany damage becomes 3 and Breaches cannot be closed.

**What it checks.** Empty-lane laziness; Faith budgeting (Toll’s cousin without copying Charon); Swarm/Pack wanting full coverage; Oracle wanting spare Faith.

**Victory read.** The false names crack. The Reliquary writes the true seal. The vault’s law holds. The drowned rivers still, and the tear over the Dying Stars closes.

---

## 6. Map and run structure (act-facing)

- `Data.ACTS` gains a third entry: name **The Binding Vault**, own pools (`act3_early`, `act3_late`, `act3_elite`, `act3_boss`), `map_bg` → `res://art/map/background_act3.jpg`, warm bronze `map_tint`, higher price mult / Rare odds than Act 2 (exact numbers wait for sim). `run_view` already loads per-act `map_bg` when set.
- Beating the Act 2 boss → act-complete (heal 75% missing Core, free power upgrade, cooldown clear) → Act 3 map.
- Victory = beating the Act 3 boss. Run summary covers all three acts.
- Boss picked at setup with no repeat of earlier-act bosses (same as Act 2’s rule across the run).
- Floor count: keep 15 for now (`Run.FLOORS`); a shorter climax is an open question, not a requirement of this theme.

---

## 7. How the vault meets the fourth archetypes

If Runes / Voyage / Edicts ship (see `act3_design.md`), they are the **player’s binding craft** — the same language as the vault, seen from the other side.

| Player tool | Vault echo |
|---|---|
| Rune on a unit or slot | Gold Seam / Bound mark — a condition waiting on a place or body |
| Embark / Landfall | Passing a sealed door and returning through another |
| Edict on a lane | Sealmark / Litany — law written on a lane that cuts both ways until mastered |

None of this requires those archetypes to exist before Act 3 battles ship. Every deck can kill a Keybearer and stand in an empty lane. The new cards make the vault *feel* like home turf; they are not a soft lock.

---

## 8. Events and relics (act flavour, short list)

Not a full build list — enough to keep the theme consistent when content is added.

**Relic seeds:** Key of the Outer Seal (start of fight: close one Breach), Broken Manacle (the first Bound enemy each fight is not Bound), Reliquary Inlay (Ward: once per fight, prevent the next Breach from opening), Cartouche Shard (Sealmarks on your units last 1 fewer round).

**Event seeds:** The Turnkey’s Bargain (pay gold or max HP for a Key relic; risk freeing a mini-wave), Litany of False Names (gamble: remove a curse or gain Void Taint), The Last Prayer Wheel (choose: heal and open a Breach next fight, or take damage and gain a Ward relic).

---

## 9. Decisions locked in this document

- Act 3’s setting is **The Binding Vault**, not the Primordial surface reading and not “the Void as a whole act.”
- Victory fiction: **resealing** so the living-world onslaught ends.
- Act verbs: **Bound, Sealmark, Rift/Breach, Ward, Unravel, Keybearer**. Sunder is optional spice on failure-of-binding moments.
- Three bosses: **Warden Eternal** (authority), **The Unbound** (prisoner / source of the spill), **Seal of Names** (the lock itself).
- No slot deletion as a common tool; no archetype-silence; no shortened round clock as boss identity.
- Palette: bronze / cracked gold / charcoal / violet seam-light.

---

## 10. Open questions

- Exact Breach damage curve (1 per Breach vs. Spawn-on-Breach) once the sim sees Act 3 HP/fight.
- Whether Gold Seam is a unit, a terrain-linked prop, or both.
- Whether the Warden Eternal should be pantheon-agnostic in art (recommended) so all patrons feel equally entitled to seize the door.
- Shorter Act 3 map (e.g. 10–12 floors) vs. full 15.
- How much Act 2 ferry/Flooded reprise is allowed before the vault feels diluted.
- Rename pass on enemy ids for portrait filenames once art is scheduled.

---

## 11. Not in this document

- Fourth-archetype card lists (remain in `act3_design.md`).
- Implementation phases, portrait checklist, and deploy steps.
- Final numeric balance, shop multipliers, and badge threshold retunes for three-act runs (badge ideas parked separately for that pass).
