# Balance and side-effect notes

Things to check later. Add to this list as new questions come up.

## How we measure balance

1. **Primary: Core HP lost per fight.** Read it by fight type (early / late / elite / boss), floor band, god power and encounter. Use the average, and check the median and 90th percentile for swingy fights. It is net of in-fight healing, and a defeat ends the fight, so losing fights understate the damage.
2. **Secondary: matchups and outcomes.** God power vs each elite and boss (HP lost and win%), plus win / timeout / loss rates per encounter.
3. **Last: run win rate.** With one act and an unfinished card pool, it depends on too many things at once. A small change in HP per fight can swing it a lot (Osiris loses 0.6 HP per fight less than average but wins 45% of runs vs 23-33%).

### Current baseline (60 runs per power, bot)

| Fight type | Avg HP lost (median / p90) |
|---|---|
| Early fights | 2.0 (2 / 4) |
| Late fights | 7.9 (7 / 15) |
| Elites | 7.2 (7 / 12) |
| Bosses | 27.4 (26 / 39) |
| Floors 1-6 / 7-12 / 13-14 | 3.6 / 8.5 / 12.5 |

- **Outlier pass** (HP per fight, before -> after):
  - First Contact removed (0.1 HP, 100% wins). The early pool is now Hollow Procession, Swarm, Tangled Ruins and Carrion Flock.
  - Swarm 6.2 -> 2.5: one Void Spawn fewer (3 Spawn + 2 Wisps).
  - Hollow Procession 0.7 -> 2.2: a second Hollow Archer behind the Bulwark.
  - Double Charge, renamed Charge Line, 13.3 -> 9.6: one Charger replaced by a Zealot.
  - Ashen Tide 12.2 -> 10.0: Ashen Wraith ATK 3 -> 2. Swapping the Weaver for an archer made it worse (13.0), so the Ashes damage was the issue, not the Webs.
  - Fenrir 12.3 -> 9.4: base ATK 4 -> 3, still +1 per death.
  - Shield Wall 3.6 -> 6.2: an added Void Spawn in lane 1. A Zealot there overshot (8.3, 22% wins).
  - Plague Pit 4.1 -> 8.1 and Sieging Host 4.1 -> 10.0: an added Void Spawn in lane 4. Sieging Host is now the costliest late fight; if it stays there, drop the Spawn's lane or the Engine's HP.
- **Late fights now span 5.1-10.0** and early fights 1.1-2.5.
- **Bosses:** Herald 30.2, Hel ~25, Apep ~25. The Herald is still the costliest; Void Tide 5 -> 4 is the dial if it needs softening. After today's buff the Herald costs the most HP, though its win rate matches Hel's.
- Runs reach the boss having lost about 19 of 55 HP, and the boss costs about 27 more on average.

### Act 2 (placeholder, 60 runs per power)

The run now has two acts. Act 2 reuses Act 1's battles at Act 1 difficulty until the Underworld battles exist; its boss gets +2 ATK / +15 HP.

| Fight type | Act 2 avg HP lost (median / p90) |
|---|---|
| Early fights | 2.9 (2 / 6) |
| Late fights | 7.2 (7 / 13) |
| Elites | 7.3 (7 / 12) |
| Bosses | 27.9 (25 / 40) |

- About 29% of bot runs beat the Act 1 boss. With a 75% heal between acts, about 60% of those reach the Act 2 boss, entering with about 31 HP. Overall bot win rate is 6% (it was 28% when the run ended after Act 1).
- **Heal between acts** (`ACT_HEAL`): 50% -> 10% of runs reach the Act 2 boss; 75% -> 18%; 100% -> 18% (with Act 1-difficulty placeholders).
- **Act 2 at 8+ HP per fight is unsurvivable.** With an extra scaling step and late fights in the early pool, Act 2 cost about 8 HP per fight and only about 4% of runs reached its boss, even with a full heal (7%). Each act should cost about 20-25 HP before its boss.

## Current difficulty setup

- Two acts of 15 floors each (`Data.ACTS`). Beating an act boss heals 75% of missing Core HP, recharges the power and grants a free upgrade.
- 15-floor map (was 8), with two guaranteed shops, two guaranteed elites and a mid-act rest site.
- Core HP 55 for every patron (set per patron in `PATRONS`, so classes can differ later). Rest sites heal 15.
- Floor scaling every 6 floors: each step Empowers one more random enemy per fight (+2 ATK / +6 HP each) and adds a round. Floors 7-12 have one Empowered enemy and 4 rounds; floors 13-14 have two and 5 rounds.
- God powers: one per run, free, once per fight, then recharging for 3 floors (`POWER_COOLDOWN_FLOORS` in `data.gd`).
- The Void Herald has fixed stats (10 ATK / 42 HP, Void Tide 5) and is never Empowered. In phase 1 it summons a Void Spawn every round and a Void Wisp in its back row every second round; phase 2 summons nothing.
- Enemy Pierce stops at your back unit and never reaches the Core. The Siege Engine picks its lane (most units) as it fires, so the target is hidden.
- Elites have Threat 3. Fenrir 3 ATK / 10 HP / +1 ATK per death, Set 3 ATK / 8 HP with a one-round Sandstorm, Medusa guarded by one Bulwark and a Void Spawn.

## Balance to check in playtests

- **Longer runs mean repeated encounters.** There are only 3 early fights, 3 late fights and 3 elites, and a 15-floor run visits roughly 9-10 fights and 2-3 elites. Late fights repeat about 4 times per run. New encounters are the next thing to add if runs start to feel samey.
- **Attrition from Charge Line (was Double Charge).** It cost the bot about 13 HP per fight with two Chargers; now about 10 with one. Watch whether it still feels like the run killer.
- **Difficulty spread.** About two thirds of bot runs reach the Herald and about half of those beat it. When scaling stepped every 5 floors, the +4 / +12 Empowered bonus hit normal fights on floors 11-13 and only 27% of runs reached the boss.
- **Gold and deck size.** Twice the fights means about twice the gold and card rewards. Check whether shops stay interesting and whether decks get bloated.
- **Void Tide is the boss's difficulty dial** (`void_tide` on the Herald in `ENEMIES`). On the old 8-floor map, with 40 HP: tide 5 -> 32% bot wins, tide 7 -> 12%. With 50 HP: tide 3 -> 65%, tide 5 -> 50%, tide 7 -> 32%. Extra ATK and HP on the Herald alone barely changed its win rate.
- **Empowered enemies.** A single buffed enemy is much gentler than buffing all enemies, because only one lane crosses the ATK breakpoints (a 4-ATK unit one-shots 4-HP Sentinels). Buffing every enemy with +1 ATK made units die before they could act. Check that the Empowered unit feels like a puzzle to solve rather than random bad luck, especially when it lands on an elite.
- **Empowering the boss's summons is far too strong** (bot win rate 5% with the full floor-8 bonus on every summoned Void Spawn). Keep summons unbuffed.
- **Elite trade-off, still open.** Goal: a timeout should cost little HP, and a win should cost low to medium HP. Currently winning is often cheaper than a timeout, because a win ends the fight early. Ideas: lower elite-fight Threat further, or add an Enraged phase at half HP so going for the kill costs something.
- **Fenrir still wipes lined-up units.** Most bot losses there are units standing side by side in front of his Cleave. Check whether humans spread out naturally.
- **The economy changes barely matter.** No timeout gold, rest heal 10 and shop heal at 40 gold only cost about 4 Core HP by the boss. Check whether gold or healing should be tightened further, or whether the shop needs better things to spend on.
- **Round scaling.** Fights get +1 round per scaling step. This cut timeouts sharply but barely changed win rates. Watch that longer late fights don't feel slow, and that Golden Fleece (now "+1 round") still feels worth taking.
- **Timeouts give nothing now.** Check whether this makes elites feel punishing rather than interesting.
- **Early fights are gentle.** Tangled Ruins is still won 100% of the time for about 1 HP. Check whether they should threaten a little more.
- **God power spread.** With cooldown and the new scaling (60 runs each): Tyr 27%, Thor 30%, Zeus 30%, Poseidon 35%, Sekhmet 40%, Osiris 47%. The Norse powers trail and Osiris leads; the bot plays Tyr cautiously and Osiris's revive is easy for it to use well. Re-check with 300 runs before tuning individual powers.
- **Cooldown dial.** Without a cooldown the bot won 50% (vs 28% never using a power); a 3-floor cooldown brought it to 41% before the scaling change. The bot uses its power on elites and the boss, and in normal fights only if it will recharge before the boss. Humans will likely save it better.
- **Herald summons dial** (bot win rate vs the Herald, 60 runs per power): old (one Spawn in phase 1) 61%; two Spawns in both phases plus Wisps 9%; two Spawns in phase 1 plus Wisps 19%; one Spawn plus Wisps in both phases 35%; one Spawn plus Wisps in phase 1 only (current) 43%, level with Hel (44%).
- **Pierce nerf.** Double Charge went from 14.9 to 12.9 HP lost per fight. It is still the costliest normal fight, mostly from the Chargers running into empty lanes. Next step if needed: Charger ATK 4 -> 3.
- **Hidden siege lane.** The bot never moves units, so its Sieging Host numbers barely move (about 4 HP per fight). Watch how humans handle it: the counterplay is to spread out or kill the Engine during its loading round.
- **Upgrade pace.** Thresholds are 4 / 8 / 12 main-pantheon cards. The bot now averages about 0.9 upgrades per run (was about 2.2 at 2 / 4 / 6), and its win rate barely moved (34%). The bot caps its deck at 22 cards and values main-pantheon cards only mildly, so a focused human should reach 1-2. Check that the first upgrade arrives early enough to feel part of the run.
- **Scaling dial.** With powers and cooldown: scaling every 6 floors -> 35% (62% reach the boss); every 5 floors (two Empowered from floor 11) -> 29% (49% reach the boss). Every 5 is the next step if players find runs too easy.
- **Herald phase 2 starts at half max HP** (21 of 42). Check that it still arrives at a sensible point in the fight.

## Side effects to watch

- **Restart planning shows information.** Restarting restores the random state, so anything revealed during planning comes out the same after a restart. For example, if a Raven of Odin dies from a spell, you see which card it draws, and that card will be drawn again later. If this gets exploited, block restarting after a card was drawn during the phase.
- **Restart planning makes experimenting free.** Players can try Rebuke and Transposition setups and take them back. Rebuke is predictable anyway, but check whether this makes planning feel too safe.

## Tools

- All run balance numbers live in the `BALANCE` table in `game/scripts/core/data.gd`. Starting HP and patron relics live in `PATRONS`.
- `game/tests/balance_sim.gd` plays runs with a greedy bot. It reports Core HP lost per fight (by fight type, floor band and god power), a table per encounter (HP lost average / median / p90 / max, then win, timeout and loss rates), god power vs elite and boss matchups, and finally run stats. From the `game` folder:
  `& "C:\Users\nitza\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tests/balance_sim.gd -- 300`
  The count is runs per god power. Add `no_powers` after the run count to measure a bot that never uses its power. Use at least 300 runs per power when comparing powers: at 100 runs the per-power numbers swing by several points.
- `game/tests/trace_fight.gd` prints the full log of the bot playing one battle: `... --script res://tests/trace_fight.gd -- fenrir <seed> <scaling steps>`.
- The bot ignores enemy intents, never looks ahead, never moves units, and skips Ragnarok and Transposition. Use it to compare settings, not to predict human win rates.

## Bot win rate history

Kept for reference; compare future changes by HP lost per fight (above) first.

| Setting | Win rate |
|---|---|
| Original values | 71% |
| Economy changes only | 71% |
| Economy + every enemy +1 ATK / +2 HP every 3 floors | 29% |
| Same, plus patron starting relics and +1 round per step | 32% |
| Same, plus elite changes and no ATK scaling in elite fights | 39% |
| Empowered single enemy (+2 ATK / +6 HP per step), 50 HP, tide 3 | 65% |
| Same, tide 7 | 32% |
| Same, 40 HP, tide 5 | 32% |
| 15 floors, 40 HP, scaling every 5 floors | 8% |
| 15 floors, 55 HP, scaling every 7 floors, rest heal 10 | 24% |
| 15 floors, 55 HP, scaling every 7 floors, rest heal 15 | 32% |
| God powers v1 (no patron relics), no cooldown | 50% |
| Same, 3-floor power cooldown | 41% |
| Same, scaling every 5 floors with stacking Empowered count | 29% |
| Same, scaling every 6 floors | 35% |
| Same, upgrades at 4 / 8 / 12 cards | 34% |
| Same, Herald summons Wisps, enemy Pierce stops before the Core, hidden siege lane, current | 30% |
