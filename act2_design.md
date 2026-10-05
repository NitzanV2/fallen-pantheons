# Act 2: The Drowned Underworld - Design Plan

Planning only; nothing here is implemented yet. All numbers are first-pass placeholders for the balance sim. Each phase in section 8 ends with tests, a sim run, rulebook entries and a deploy.

## 1. Run structure

- **One run, two acts.** Beating the Act 1 boss no longer ends the run. A short act-transition screen leads into a new 15-floor Act 2 map, using the same generator with Act 2 pools.
- **Between acts:** heal 75% of missing Core HP (`ACT_HEAL`), and get one free god power upgrade pick (the "act boss grants an upgrade" rule from `pantheon_identity_design.md`). The power cooldown resets.
- **Victory** is beating the Act 2 boss. The run summary shows both acts.
- **Per-act content:** `BATTLE_POOLS` values become `"act1_early"`, `"act2_late"`, `"act2_boss"` and so on (or an `act` field per battle). Each act picks its own boss at setup, so the map can preview both.
- **Scaling:** Act 2 enemies are designed stronger by default, not just Empowered. Floor scaling restarts each act, every 6 floors, so Act 2 floors 7-14 still get Empowered enemies on top of the stronger base.
- **Upgrade thresholds:** add 16 and 20 to `POWER_THRESHOLDS`, plus tier-3 nodes (section 7).
- **Gold and cards:** reward odds shift toward Uncommon and Rare in Act 2, and shop prices go up about 15%.
- **Balance sim:** report everything per act. Add "HP entering Act 2" and "HP entering each boss" to the run section.
- **Save data and seed:** the map RNG is seeded per act (seed + act), so Act 2 maps are reproducible.

## 2. Setting: The Drowned Underworld

The Void has flooded the realms of the dead. The Duat, Hades and Helheim have run together into one drowned afterlife, where the dead no longer rest and the rivers (Styx, the Nile of the Duat, Gjoll) have burst their banks.

- **Look:** dark teal water, bone-white stone, drowned temples, ghost-lights. Act 1's palette was purple Void over sandstone.
- **Map background:** a flooded necropolis with the river winding between nodes.
- **Board:** the same layout, with new Act 2 tile art (wet flagstones on the enemy side, river-stone on the player side).

### New terrain: Flooded

Placed by the battle layout or by enemies. The unit in a Flooded slot has -1 ATK and can't Revive. Battles can pre-flood slots, and some enemies flood the slot they die in. It pushes players to reposition, which is good for Raiders and Wolves.

### New enemy mechanics

Each mechanic is a single readable rule, in the style of Act 1's Split, Veil and Thorns.

| Mechanic | Rule | Counter |
|---|---|---|
| **Incorporeal** | Melee attacks against it deal half damage (round down, minimum 1). | Ranged units, spells, Burn |
| **Drown** | When it dies, its slot's facing player slot (same lane, front) becomes Flooded. | Kill it where you don't mind flooding, or move afterwards |
| **Drag** | Its attack pulls your back unit in its lane to the front (if the front is empty), then hits it. | Keep the front filled, or use Taunt |
| **Devour** | When a player unit it kills stays dead, it heals 3 and gains +1 ATK. | Shields, keeping units alive (this punishes the Doomed) |
| **Toll** | When planning ends, you must have at least 1 Faith left unspent: the Toll takes it. If you have 0, the Core takes 2 instead. The Faith counter shows a coin marker while a Toll is active. | Budget a Faith each round, or kill it fast |
| **Judgement** | Attacks the player unit that killed an enemy last round, anywhere (the most recent killer if several; its own lane if none). The judged unit gets a scales marker during planning. | Shield or move your finisher, or let a disposable unit take the kill |

### New battle feature: reinforcement waves

Some battles list enemies that arrive by ferry mid-fight, for example "2 Shades arrive in round 3". A boat marker on the enemy side shows the round and the lanes from the start of the fight, so planning ahead matters. Arrivals take the named slots if empty, otherwise the nearest empty enemy slot. Battle data gets a `"waves": [[round, enemy_id, lane, row], ...]` field. Act 1 had no mid-fight arrivals apart from boss summons.

## 3. Act 2 enemies

Stats are placeholders, roughly Act 1 late-fight strength plus about 25%.

| Enemy | Stats (ATK / HP / SPD, Threat) | Keywords and text |
|---|---|---|
| Drowned Thrall | 2 / 5 / 2, T1 | Drown. Attacks its own lane. |
| Shade | 3 / 4 / 3, T1 | Incorporeal. |
| Styx Lamprey | 2 / 4 / 4, T1 | Drag. |
| Assessor of Ma'at | 2 / 5 / 3, T2 | Ranged. Judgement. |
| Soul Eater (lesser Ammit) | 3 / 6 / 2, T2 | Devour. |
| Hel-Hound | 3 / 4 / 5, T2 | Gains +2 ATK against units that are Flooded or below half HP. |
| Gjoll Wraith | 1 / 5 / 2, T1 | Ranged. Shuffles a Drowned status into your draw pile when it attacks (Unplayable; when drawn, your units in a random lane get -1 ATK this round). |
| Obol Collector | 0 / 6 / 1, T1 | Toll. Doesn't attack. |
| Grave Shield | 1 / 10 / 1, T1 | Taunt. Incorporeal. (Act 2's wall: melee needs to bring a lot.) |

## 4. Battles

Act 1 has 4 early, 10 late, 5 elite and 3 boss encounters. Act 2 starts with 4 early, 8 late, 4 elite and 3 boss, and grows later.

### Early (Act 2 floors 1-3)

| Id | Name | Enemies (sketch) | Tests |
|---|---|---|---|
| styx_banks | Banks of the Styx | Shade x2 front, Drowned Thrall, Gjoll Wraith back | Incorporeal: bring Ranged or spells |
| drowned_procession | Drowned Procession | Thrall x3 front, Assessor back; one pre-Flooded player slot | Flooding and repositioning |
| obol_toll | The Ferry Toll | Obol Collector back, Thrall and Lamprey front; wave: Thrall in round 3 | Spend your Faith, kill the Collector, plan for the ferry |
| hounds_of_gjoll | Hounds of Gjoll | Hel-Hound x2, Shade | Protect wounded units |

### Late (Act 2 floors 4-14)

| Id | Name | Enemies (sketch) | Tests |
|---|---|---|---|
| hall_of_two_truths | Hall of Two Truths | Assessor x2 back, Grave Shield, Shade | Judgement focus-fires your carry |
| devourers_feast | The Devourer's Feast | Soul Eater x2, Thrall, Gjoll Wraith | Don't feed units to Devour |
| river_crossing | River Crossing | Lamprey x2, Thrall; two pre-Flooded slots; waves: Shade x2 in round 2, Thrall in round 4 | Drag, flooding and arrivals: positional puzzle |
| sunken_sanctum | Sunken Sanctum | Grave Shield x2, Assessor, Obol Collector | Damage race against Toll behind walls |
| shade_tide | Tide of Shades | Shade x3, Gjoll Wraith | Melee-heavy decks suffer |
| drowned_legion | Drowned Legion | Thrall x2, Hel-Hound, Siege Engine | Act 1 crossover; Siege plus floods |
| weighing_room | The Weighing Room | Assessor, Soul Eater, Lamprey, Obol Collector | Everything at once, low HP each |
| gjoll_bridge | Gjoll Bridge | Gjoll Wraith x2, Grave Shield, Hel-Hound | Deck clog plus a fast hound |

### Elites

| Id | Elite | Identity |
|---|---|---|
| charon | **Charon, the Ferryman** (Greek; 3 / 14 / 2) | Toll. Ferry: at the end of each round he carries your back-row unit with the lowest HP out of the fight. Its card goes to your discard pile, so you can redeploy it later at full HP (tokens are simply removed). The target is marked during planning. Pressures the back row without killing, so On-Death and Revive don't trigger. |
| cerberus | **Cerberus** (three 3 / 7 heads in lanes 2-4) | Three linked heads. Each head that dies gives the survivors +2 ATK. If all three are alive at end of round, they heal 2. Rewards area damage or focused burst. |
| hraesvelgr | **Hraesvelgr, the Corpse-Swallower** (Norse; 4 / 13 / 3, Airborne, back row) | Wingbeat: each round, the intent shows a direction (left or right), and at the end of planning all your units are pushed one lane that way. Units pushed off the edge, or into an occupied slot, stay put and take 2. Rewards Raiders-style repositioning and punishes rigid formations. |
| erinyes | **The Erinyes** (Greek; three 2 / 6 Furies, Airborne) | Vengeance: each round they all attack whichever of your units dealt the most damage last round. Forces spreading damage. |
| twelfth_gate | **Keeper of the Twelfth Gate** (Egyptian; 0 / 18 / 1, Immovable, centre back, width 2) | Seal: each round, seals one of your lanes (intent shown). Your units there can't attack unless the Gate took 6+ damage this round. Two Gate Guardians (3 / 5) stand in front of it and return two rounds after dying. |

Garm was dropped: Fenrir is already a wolf elite, and wolves are now the Norse player archetype.

### Bosses (one picked per run)

| Id | Boss | Phases and identity |
|---|---|---|
| hades | **Hades, Lord of the Dead** (Greek), 70 HP, back row | Claim Soul: each round he claims the highest-cost card in your hand (shown as an intent during planning). Claimed cards sit under the board, visible. Dealing 8+ damage to him in a round frees the most recent claim back to your hand. Helm of Darkness: every 3rd round he is untargetable. Phase 2 (half HP): claims two cards a round, and Shades arrive by ferry (a wave every other round). Hurts decks that lean on one key card; rewards cheap, deep decks and burst damage. |
| ammit | **Ammit, the Devourer** (Egyptian), 60 HP | Weighing of the Heart: at the end of each round she compares your total ATK in lanes 1-2 against lanes 3-4. The heavier side takes the difference x2, split across its front units (the Core if that side has none). A live preview shows both totals during planning. Phase 2 (half HP): the difference is x3, and she devours (heals 4 from) any unit killed by the Weighing. Rewards balanced boards; checks tall Forge and Pack builds without banning them. |
| nidhogg | **Nidhogg, the Corpse-Gnawer** (Norse), 65 HP, coils over two lanes | Gnaws the roots: each round, one of your slots becomes Rotted (unusable for the fight; units there are pushed to an adjacent free slot or take 4). Poison breath on one lane every other round. The board shrinks over the fight. Rewards mobility and timing; hurts slow scaling decks. |

Each boss gets a `hint` and `blurb` like the Act 1 bosses, and the map shows the Act 2 boss once Act 2 starts.

## 5. New archetypes

Each archetype gets 7 cards (2 Common, 3 Uncommon, 1 Rare, 1 spell or a token), so each pantheon goes from about 17 to 24 cards. Each is built around one new rule the rulebook can explain in a paragraph.

### Norse: The Pack (wolves)

**Rule: Wolf and Pack.** Some units are Wolves (a tribe tag shown on the card). Pack: the unit gains +1 ATK for each other Wolf you control (max +4). It plays wide like Swarm, but each body hits harder, and Wolf deaths feed the Doomed (Berserker, Odin, Einherjar).

| Card | Rarity | Cost | Stats | Text |
|---|---|---|---|---|
| Wolf (token) | Token | 0 | 1 / 2 / SPD 4 | Wolf. Pack. |
| Ulfr Hunter | Common | 1 | 2 / 2 / SPD 4 | Wolf. Pack. Reinforce. (A second Reinforce card besides Valkyrie, so Gjallarhorn has more than one target. It waits behind a front Wolf and steps up when that Wolf falls.) |
| Call of the Pack | Common | 1 | spell | Summon a Wolf in an empty slot, and another in the other slot of that lane if it's empty (one target, and it sets up a Flank pair). |
| Geri | Uncommon | 2 | 3 / 4 / SPD 4 | Wolf. Pack. Whenever another Wolf dies, Geri gains +1 ATK / +1 HP. The front half of a pair. |
| Freki | Uncommon | 2 | 2 / 4 / SPD 4 | Wolf. Pack. Flank. End of round: if Freki attacked this round, summon a Wolf in the nearest empty slot. The back half of a pair. |
| Blood Scent | Uncommon | 2 | spell | Choose an enemy. Each of your Wolves deals damage equal to its ATK to it. |
| Skoll and Hati | Rare | 3 | 4 / 5 / SPD 4 | Wolf. Pack. Your Wolves have Flank. Start of round: summon a Wolf if you have fewer than 4. |

**Back row: Flank.** A Wolf with Flank in the back row attacks right after the Wolf in front of it in the same lane, hitting the same target (melee, so the target must be one the front Wolf could hit). If the front slot is empty or not a Wolf, it doesn't attack. Wolves therefore pair up within a lane (one front, one behind) rather than filling the front row like Scarabs, which gives the archetype a real back-row role. The Wolf token and Ulfr Hunter don't have Flank: it comes from Freki and Skoll and Hati, so the pairs are earned.

New relic idea: **Gleipnir Fragment** (Uncommon): your Wolves have +1 HP.

### Greek: The Forge (armaments)

**Rule: Armament.** A new card type. Play it on one of your units to attach it for the rest of the fight. A unit holds one Armament; a new one replaces the old (the old card goes to the discard pile). **When an armed unit dies, its Armament shuffles into your draw pile,** so it comes back later in the fight but costs a draw and Faith again. Sacrifice combos can't loop it. If they feel weak in the sim, buff the Armament effects rather than the return rule. Armed units show a small anvil badge, and the hover shows the attached item.

| Card | Rarity | Cost | Stats | Text |
|---|---|---|---|---|
| Bronze Spear | Common | 1 | armament | +2 ATK. |
| Hoplon | Common | 1 | armament | Start of round: Shield 2. |
| Forge Apprentice | Common | 1 | 1 / 4 / SPD 2 | Rally 1. Your first Armament each round costs 1 less. |
| Cyclops Smith | Uncommon | 2 | 3 / 5 / SPD 2 | On deploy: add a random Common Armament to your hand. It costs 0 this round. |
| Harpe | Uncommon | 1 | armament | +1 ATK and Cleave. |
| Golden Cuirass | Uncommon | 2 | armament | +4 HP and Taunt. |
| Talos | Rare | 3 | 3 / 8 / SPD 1 | Immovable. Can hold any number of Armaments. Each Armament on Talos also gives +1 ATK. When he dies, all of them shuffle into your draw pile. |

It pairs with Olympians (armour on a front wall) and Oracle (Armaments are not spells, so this is deliberately a separate engine; Hermes doesn't discount them). Ammit is a deliberate counter-boss for it.

### Egyptian: The Sun (Sunlit and Burn)

**Rules:**
- **Sunlit** (new player-side terrain): the unit here has +1 ATK, and its attacks apply Burn 1.
- **Burn X** (new status): at the end of the round, the unit takes X damage, then Burn drops by 1. It stacks by adding.

Burn differs from Sekhmet's Poison (1 per round, permanent until healed): it is front-loaded and decays. It shapes the board like Ley Lines, and burns through Incorporeal and walls in Act 2.

| Card | Rarity | Cost | Stats | Text |
|---|---|---|---|---|
| Dawn Ritual | Common | 1 | spell | Turn one of your slots without terrain into Sunlit for this fight. Exhaust. |
| Priestess of Aten | Common | 1 | 1 / 3 / SPD 3 | Ranged. Her attacks apply Burn 2. |
| Solar Barque | Uncommon | 2 | 2 / 6 / SPD 2 | Start of round: if it is on a Sunlit slot, the allies left and right of it gain Shield 2. |
| Noon Blaze | Uncommon | 2 | spell | Burn 3 every enemy in a lane where you have a Sunlit slot. |
| Benben Stone | Uncommon | 1 | 0 / 6 / SPD 1 | Immovable. Doesn't attack. Its slot and the slots left and right of it are Sunlit while it lives. |
| Eye of Ra | Uncommon | 1 | spell | Double the Burn on an enemy. |
| Horus | Rare | 3 | 3 / 5 / SPD 4 | Ranged. Airborne. Deals +2 damage to Burning enemies. Once per round, when a Burning enemy dies, gain 1 Faith next round. |

The Eye of Horus relic already exists, so Horus's card text should not overlap with it.

### Optional: a third god power per pantheon

Powers are pantheon-level, not archetype-level, but each new archetype has a natural power. All three use reserve names from `pantheon_identity_design.md`.

- **Odin's Wild Hunt** (Norse): summon a Wolf. Branches: more Wolves, or Wolves gain Pack +1 this round.
- **Hephaestus's Forge** (Greek): attach a free Bronze Spear to an ally. Branches: better forged items, or forged items return to your hand instead of the draw pile.
- **Ra's Dawn** (Egyptian): make a slot Sunlit and Burn 2 the enemies in that lane. Branches: bigger Burn, or Sunlit spreads.

This turns patrons into a 3-power choice. Decide after the archetypes have been played.

## 6. Act 2 relics and events

- **Relics (4-6):** Gleipnir Fragment (Wolves +1 HP), Anvil of Lemnos (your first Armament each fight costs 0), Sun Disk (start of fight: one random empty player slot becomes Sunlit), Obol (the first Toll each fight is free; +10 gold per elite), Charon's Lantern (Flooded slots don't stop Revive), Styx Water (Rare: the first ally to die each fight returns with 1 HP and Incorporeal).
- **Events (4-5):** The Ferryman's Price (pay gold, HP or a card to cross; gamble on swimming), Scales of Ma'at (weigh a card: remove it or upgrade it), Lethe's Spring (forget a card for gold or heal, but risk forgetting a relic), Hel's Feast (fight a mini-wave for a relic), Persephone's Pomegranate (a big reward, but the Core loses max HP each act).

## 7. God power tree extension

- **Tier 3 per branch** (from section 6 of `pantheon_identity_design.md`, adjusted to v1 nodes). Examples: Tyr Blood 3 "the sacrificed unit's On-Death triggers twice"; Thor Hammer 3 "your units in the lane gain Frenzy this round"; Zeus Chain 3 "chains to every adjacent enemy"; Osiris Life 3 "return your last two dead allies".
- **New thresholds:** 16 and 20 main-pantheon cards. The act-transition pick means even spread decks get at least one tier.
- **Capstone (optional):** needs a full branch; "usable twice per fight" for most powers.

## 8. Implementation phases

Each phase ends with tests, the balance sim, rulebook entries and a push.

1. **Act infrastructure (done).** `Data.ACTS` (name, pools, extra scaling steps, boss bonus, reward odds, price multiplier, map tint), act index on the run, a boss per act with no repeats, the act-complete screen (heal and free upgrade), Act 2 map tint, per-act sim reporting. Act 2 is a placeholder: Act 1's battle pools at Act 1 difficulty, with the boss at +2 ATK / +15 HP, better reward odds and 15% higher prices. An extra scaling step plus late fights as the early pool cost about 8 HP per fight, so almost no bot run reached the Act 2 boss.
2. **The Pack (Norse) (done).** Wolf tribe tag, Pack, Flank (back-row follow-up attack; if the front Wolf's target died, it takes that Wolf's next target), 6 cards plus the Wolf token, bot heuristics (Flank Wolves go behind front Wolves, Call of the Pack fills an empty lane, Blood Scent goes for kills), tests, rulebook entries, portraits and Pack/Flank icons. The sim gained `archetype=<key>` (drafts that archetype first, its pantheon's patrons only). Act 1 HP per fight with Norse patrons, 150 runs per power: Pack 7.4, Doomed 7.5, Raiders 7.7, inside the ±1 target. Gleipnir Fragment waits for phase 8.
3. **The Forge (Greek) (done).** The Armament card type (targets an ally, attaches, replaces the old one into the discard pile, shuffles into the draw pile when the unit dies, isn't a spell), an anvil badge per Armament on the token, "Armed:" lines in the hover, 7 cards, bot heuristic (attack gear on front attackers, defensive gear on front units under threat, Talos preferred, never replaces), tests and fuzz invariants (Armaments count as a card pile, one per unit except Talos), rulebook entries, portraits and the anvil icon. Forge Apprentice has Rally 1, as required. Act 1 HP per fight with Greek patrons, 150 runs per power: Forge 7.4, Olympians 7.2, Oracle 7.45, inside the ±1 target.
4. **The Sun (Egyptian) (done).** Sunlit terrain (Dawn Ritual creates it in either row; a living Benben Stone lights its own slot and its row neighbours, shown with a golden glow) and the Burn status (ticks after Poison: deals X, then drops by 1; heals don't cure it, Revive clears it). Burn badge with its number on the token, hover entries, tile art, Burn and Sunlit icons, rulebook entries, 7 cards, bot heuristics and tests. Eye of Ra only targets Burning enemies. Horus's Faith arrives at the start of the next round, since Faith resets each round and most kills happen in battle. Act 1 HP per fight with Egyptian patrons, 150 runs per power: Sun 7.3, Eternal 7.3, Swarm 7.25, inside the ±1 target.
5. **Act 2 enemy mechanics and early and late battles.** Reinforcement waves (data, boat marker, arrival), Flooded terrain, Incorporeal, Drown, Drag, Devour, Toll, Judgement, the Drowned status; 9 enemies and 12 battles; replace the placeholder pools from phase 1; art and background.
6. **Act 2 elites.** Charon, Cerberus (linked units), Hraesvelgr (board-wide push), Erinyes (damage tracking per unit), Keeper of the Twelfth Gate (lane seals, returning guards).
7. **Act 2 bosses.** Hades (hand claims, the first boss to touch cards), Ammit (lane-balance preview UI), Nidhogg (Rotted slots). Tune each to about 25-30 HP per fight on the HP metric.
8. **Power tree tier 3, Act 2 relics and events, and a balance pass.** Optionally, the three new god powers.

Phases 2-4 are independent of 5-7 and also enrich Act 1, so they can be done in either order or alternated.

## 9. Balance targets (HP lost per fight, bot)

| | Act 1 (current) | Act 2 target |
|---|---|---|
| Early fights | 2.0 | 3-4 |
| Late fights | 7.9 | 7-9 |
| Elites | 7.2 | 8-10 |
| Bosses | 27.4 | 28-32 |

- **Run target:** about 55-65% of the bot runs that enter Act 2 reach its boss, with about 30-35 HP. (Phase 1 placeholder: about 60% at a 75% heal.) Higher per-fight targets were dropped after the phase 1 sim: at 8+ HP per fight, almost no run survived Act 2.
- **New archetypes:** each one's average HP per fight, measured with a bot that drafts it, should land within ±1 of the existing archetypes. This needs an archetype-aware draft option in the sim.

## 10. Decisions

- **Start with phase 1** (act infrastructure).
- **The new archetype cards appear in all acts,** Act 1 rewards included.
- **Between acts:** a fixed heal of 75% of missing HP plus a free power upgrade, not a choice. Set from the sim: at 50%, about a third of the runs entering Act 2 reached its boss; at 100%, about 60%; 75% lands just below the full heal.
- **Act 2 total cost:** each act must cost a run about 20-25 HP before its boss, as Act 1 does. Act 2 fights should therefore average about 4-6 HP, not 8+, when the real battles arrive in phase 5.
- **Third god powers come later,** after the archetypes have been playtested.
- **Bosses:** Hades claims cards from your hand; Ammit weighs lanes 1-2 against 3-4; Nidhogg rots slots. (The first drafts of Hades and Ammit both punished deaths, like Hel.)
- **Elites:** Hraesvelgr replaces Garm; the Keeper of the Twelfth Gate is added as the Egyptian elite (5 elites in total).
- **Judgement** targets the unit that killed an enemy last round (the Herald already targets highest ATK).
- **Charon:** no Faith payment and no Shade conversion. He has Toll, and ferries your lowest-HP back unit out of the fight to your discard pile each round.
- **Battles:** reinforcement waves are in. Toll: leave 1 Faith unspent each round for it to take, or the Core takes 2 (spending everything was too easy to make the old version matter).

- **Armaments:** when an armed unit dies, its Armament shuffles into your draw pile (not back to hand, not exhausted). Buff effects if they're weak.
- **Wolves:** Flank gives the archetype its back-row role (a back-row Wolf attacks right after the Wolf in front of it), so Pack plays as lane pairs instead of a full front row like Scarabs. Pack is +1 ATK per other Wolf, max +4 (raised from +3; the cap stops damage growing with the square of the Wolf count). Skoll and Hati summon while you have fewer than 4 Wolves. Blood Scent became a 2-cost finisher dealing each Wolf's ATK, since 1 damage per Wolf was weaker than a Starter. After the change: Pack 7.3 vs Doomed 7.5 HP per fight.

## 11. Future updates (not in this plan)

- **Patron starting cards:** each patron could offer a starting card from the new archetype as an alternative (for example Ulfr Hunter instead of Shieldmaiden).
