# Pantheon Identity: Design Options

Status: **direction chosen / not implemented**. Sections 1-4 capture the options that were considered and how they compare. Section 5 onward is the chosen design: one god power per run, upgraded through a tree, with an open card pool.

## 1. The problem

Today a run starts by picking a **patron** (Shieldmaiden / Myrmidon / Mummy Guardian). The patron gives:

- one starting card of its pantheon,
- a patron relic (Mead of the Einherjar / Spartan Standard / Scarab Amulet),
- 55 Core HP.

After that, every pantheon's cards are available. The reward rule guarantees one card from a pantheon you own and one from a pantheon you don't in every set of three. So by floor 3 most decks are three-pantheon piles, and the patron is effectively "a relic you didn't pick".

Balance sim (400 runs per patron, current build): Norse 34.8%, Greek 40.5%, Egyptian 36.3% run win rate. The spread comes from the relics and card pools, not from any lasting identity.

Current card pools: 12 cards per pantheon (8 core + 4 archetype), 8 neutral, 4 Divine (shrine only).

## 2. Goals

1. The starting choice should shape the **whole run**, not just floors 1-3.
2. **Hybrid strategies and variety** are a core feature - cross-pantheon combos (Norse deaths feeding Egyptian revives, Greek formations full of Scarabs) are the game's hook.
3. The game should have **its own identity**, not be "Slay the Spire with lanes".
4. Adding a pantheon later should **multiply** the number of distinct runs.
5. Don't significantly complicate battles. They already have lanes, rows, intents, terrain and keywords.

## 3. Options considered

### A. Lock each patron to its pantheon
Rewards, shops and shrines only offer your pantheon plus neutral cards.
- **Pro:** strongest identity; easiest to balance (three closed pools).
- **Con:** nearly identical to Slay the Spire's class model. With 12 cards per pantheon plus 8 neutral, pools are thin and runs repeat. Kills cross-pantheon combos.

### B. Generic bonus for same-pantheon cards
Some reward for having more cards of your patron's pantheon (the exact form is open - see E, F, I).
- **Pro:** keeps mixing possible while making commitment worth something.
- **Con:** if the bonus is too strong, mono-pantheon becomes the only correct play (A by another route).

### D. Drop patrons; pick a starting relic
- **Pro:** simple and honest.
- **Con:** removes identity instead of adding it. Early floors feel the same every run.

### E. Devotion traits (Teamfight Tactics style)
Count your units of each pantheon on the board; thresholds (2 / 4) unlock bonuses. Example: Norse at 2 units - the first ally death each round gives its lane +1 ATK.
- **Pro:** fits the grid and lanes; makes splashing a real trade-off.
- **Con:** very hard to balance in a roguelike, where decks are drafted rather than rebuilt each round. Adds board-state tracking to every battle. **Rejected** for now.

### F. Foreign-card tax
Cards outside your pantheon cost +1 Faith (possibly only Uncommon / Rare). A relic or shop service removes the tax for one pantheon.
- **Pro:** cheap to build, easy to read, splashing becomes a deliberate choice.
- **Con:** with 3 Faith per round, +1 is steep. It feels like a penalty rather than an identity.

### G. Pick two pantheons ("hybrid start") - favoured
At the start you choose **two** pantheons. Rewards, shops and shrines draw from those two plus neutral.
- **Pro:** hybrid identity from turn one. Every pairing has its own flavour (Norse+Egyptian = death and return; Greek+Norse = formation and sacrifice; Greek+Egyptian = endurance walls). Pools stay deep (about 24 pantheon cards plus 8 neutral). Unlike Slay the Spire. Scales well: 3 pantheons give 3 pairings, 4 give 6, 5 give 10.
- **Con:** each pairing needs to be viable, which means balance work per pairing. Reward and shop rules must change.

### H. Patron as a god power - favoured
The patron becomes a god whose **power** is usable once per fight during planning (like a free spell), instead of giving a starting card and relic.
- **Pro:** the patron matters in every fight for the whole run, whatever you draft. Very flavourful. Adds one button to battles, not a new system.
- **Con:** each power needs art, UI and tuning. Powers must be strong enough to feel meaningful but not decide fights.

### I. Patron ascension
At elites or act milestones the patron offers an upgrade. Owning more of its pantheon's cards gives a better upgrade.
- **Pro:** turns commitment into a reward curve instead of a restriction. Happens outside battles.
- **Con:** another reward screen; overlaps with rest sites and relics.

### J. Rival pantheon
Choosing a patron makes one pantheon hostile: its cards appear less often and its shrines are risky.
- **Pro:** light-touch lock that reuses the shrine events.
- **Con:** with only 3 pantheons it becomes "you get two pantheons" (G) with extra steps.

## 4. Comparison

Ratings are relative to each other. For *Work* and *Balancing difficulty*, lower is better. For *Battle complexity*, "None" is best.

| Option | Uniqueness (vs Slay the Spire) | Identity strength | Draft freedom | Work needed | Balancing difficulty | Battle complexity added | Scales with new pantheons |
|---|---|---|---|---|---|---|---|
| A. Pantheon lock | Very low | Very high | Very low | Low | Low | None | Linear (+1 class) |
| B. Same-pantheon bonus (generic) | Medium | Medium | High | Medium | Medium-High | Depends on the bonus | Linear |
| D. Starting relic only | Low | Very low | Very high | Very low | Low | None | None |
| E. Devotion traits | Medium (Teamfight Tactics-like) | High | Medium | High | **Very high** | **High** | Linear, but the trait matrix grows |
| F. Foreign-card tax | Medium | Medium | Medium | Very low | Medium | None (cost only) | Linear |
| **G. Two-pantheon start** | **High** | **High** | **Medium-High** | Medium | Medium-High | None | **Grows with pairings** |
| **H. God power** | **High** | **High** | High | Medium-High | Medium | Low (one button) | Linear (+2 gods per pantheon) |
| I. Patron ascension | Medium-High | Medium | High | Medium | Medium | None | Linear |
| J. Rival pantheon | Medium | Medium | Medium | Low | Low-Medium | None | Weak with few pantheons |

### Between-fight bonuses (replacing devotion)

These reward commitment without touching combat.

| Bonus | What it does | Uniqueness | Identity strength | Work needed | Balancing difficulty | Battle complexity added |
|---|---|---|---|---|---|---|
| Deck resonance | When your deck reaches, e.g., 5 cards of one pantheon, a one-time reward at the next rest site or shrine (a second god-power use, a card upgrade) | Medium | Medium | Low-Medium | Low (one-time, visible) | None |
| **Hybrid signature cards** | 2-3 cards per pairing, offered once you own 3+ cards from each of your two pantheons | **High** | **High** | Medium (grows with pairings) | Medium | None (just cards) |
| Pantheon shrine favour | Shrines of your two pantheons give better outcomes; the third pantheon's are riskier | Low-Medium | Medium | Low | Low | None |
| God-power upgrades at rest sites | Alternative to healing: upgrade the god power (an extra use, a rider effect) | Medium | High | Low-Medium | Medium | None |

### How god powers are offered

| Model | Choices per run start | Content per new pantheon | Pairing identity | Work needed |
|---|---|---|---|---|
| **2 gods per pantheon, pick 1 of the 4 from your pair** | 4 | +2 powers | Medium (from the combination) | Low-Medium |
| Unique powers per pairing | 2-3 | +2-3 powers **per new pairing** | Very high | High, grows with pairings |
| Per-pantheon now, pairing powers later | 4, then more | +2 now, extras later | Medium, then High | Starts low, grows |

## 5. Chosen direction

**H + I: one god power per run, upgraded through a tree. The card pool stays open.**

1. **Pick one god power** at run start from the six (2 per pantheon). The power's pantheon is your **main pantheon** for the run.
2. **All cards stay draftable.** There is no pantheon lock and no second patron.
3. **Upgrade the power through its tree** as you draft cards of your main pantheon (section 6).
4. **Mixing is rewarded, not punished:** each tree has a **pact branch** whose nodes need cards from a specific other pantheon.
5. **Starting deck:** the neutral starter plus the main pantheon's signature card (today's patron cards: Shieldmaiden, Myrmidon, Mummy Guardian).
6. **Starting HP:** a flat 55 for everyone.
7. **Patron relics** (Mead of the Einherjar, Spartan Standard, Scarab Amulet) move into the normal relic pool.
8. **Reward rule:** every set of three card offers contains at least one card from your main pantheon. The other two come from the full pool.

### Why not two patrons (option G)

- **Double push toward one pantheon.** A pool lock plus card-count thresholds would both reward going mono, ending in Slay the Spire classes.
- **Little gain with three pantheons.** Picking two only removes one, but every pairing still needs balancing.
- **Longer runs need deeper pools.** With two more acts planned, a run drafts about 30 cards. Two pantheons plus neutral (about 32 cards) would repeat.
- **The hybrid hook survives through pact branches.** Splashing a second pantheon unlocks some of the best upgrades.

Revisit picking two pantheons once there are 5 or more. Pools will then be big enough that a lock keeps decks coherent instead of thin.

## 6. God powers

### Using a power

- Once per fight, during the plan phase. Costs no Faith.
- Uses spell targeting (a lane, a unit, or an empty tile, depending on the power).
- Shown as a round button with the god's glyph, not a card frame, so it never looks like a drafted card.
- Restart planning restores an unused power.

### Naming

Powers are named as abilities: **"Zeus's Lightning Bolt"**, not "Zeus". This lets the iconic gods be used even when they already exist as cards or bosses (as Hel's Bargain already sits alongside Hel, the Hollow Queen).

- **Lead with the ability.** Where space is tight, show "Lightning Bolt" with "Zeus's" as a smaller prefix or in the tooltip.
- **Echo the card, don't copy it.** If a god's card already does something, the power should do it differently (the Zeus card strikes; Lightning Bolt chains).
- **Avoid names that collide with any item,** not only gods. "Athena's Aegis" would clash with the Aegis relics; "Odin's Ravens" with the Raven of Odin card.

### Tree format

- **Base power:** deliberately weak.
- **Two main branches** of the god's own pantheon, three nodes each. A node needs the one before it in its branch.
- **Pact branch:** one node per other pantheon. A pact node needs 3 cards of that pantheon.
- **Capstone:** needs one completed main branch.
- About 10 nodes per tree. A full three-act run earns about 6, so you fill roughly half and runs differ.

### Earning upgrades

- **Thresholds:** 3, 6, 9, 12 and 15 cards of your main pantheon.
- **Act bosses:** each act boss grants one upgrade, so a deck spread across pantheons still progresses.
- **Counting:** cards **added** to the deck count; removing a card never loses an upgrade, so trimming the deck stays a good move. Option to test: Rare cards count as 2.
- **The pick:** reaching a threshold offers 2-3 nodes you're eligible for; choose one. Unused eligibility carries over.
- **Pacing:** the starting deck is 10 cards. With only Act 1 today, expect 2-3 threshold upgrades plus the boss. With three acts, about 6.

### Roster

| Pantheon | Power | Role |
|---|---|---|
| Norse | Tyr's Oath | Sacrifice an ally for buffs |
| Norse | Thor's Thunderclap | Burst damage to a lane, scaling with ally deaths |
| Greek | Zeus's Lightning Bolt | Single-target strike that learns to chain |
| Greek | Poseidon's Tide | Push and control, building on Rebuke's push |
| Egyptian | Osiris's Return | Revive a fallen ally |
| Egyptian | Sekhmet's Plague | Poison and attrition |

In reserve, for alternatives or a third power per pantheon later: Athena (shields), Freyja (card recursion), Ra (permanent buffs), Hephaestus (forging a unit), Heimdall.

All numbers below are first-pass placeholders for the balance sim.

### Tyr's Oath (Norse)

- **Base:** destroy one of your units. Allies in its lane gain +1 ATK this round.
- **Blood:**
  1. +2 ATK instead.
  2. The buff lasts the whole fight.
  3. The destroyed unit's On-Death triggers twice.
- **Oath:**
  1. Your Core heals by the unit's remaining HP.
  2. Its row neighbours gain Shield 2.
  3. Draw a card for each ATK the unit had.
- **Pacts:**
  - Greek: allies in its lane gain Taunt this round.
  - Egyptian: the unit returns with Revive at the end of the round.
- **Capstone:** usable twice per fight.

### Thor's Thunderclap (Norse)

- **Base:** deal 2 damage to the front enemy in one lane.
- **Storm:**
  1. +1 damage for each ally that died this fight (up to +4).
  2. Hits every enemy in the lane.
  3. Also hits the adjacent lanes for half damage.
- **Hammer:**
  1. The strike Cleaves (also hits the unit behind).
  2. A killing blow refunds the power once per fight.
  3. Your units in the lane gain Frenzy this round.
- **Pacts:**
  - Greek: allies in the lane gain Shield 2.
  - Egyptian: enemies hit gain Poison 1.
- **Capstone:** after 3 ally deaths, Thunderclap can be used again.

### Zeus's Lightning Bolt (Greek)

- **Base:** deal 3 damage to one enemy.
- **Chain:**
  1. Chains to one adjacent enemy for 1 damage.
  2. Chains to two adjacent enemies.
  3. Chains to every adjacent enemy, and chain damage equals the main damage.
- **Sky:**
  1. Ignores Shield.
  2. +2 damage to Airborne and Ranged enemies.
  3. A kill gives +1 Faith this round.
- **Pacts:**
  - Norse: a kill gives a random ally +1 ATK for the fight.
  - Egyptian: the target gains Poison 2.
- **Capstone:** usable twice per fight.

### Poseidon's Tide (Greek)

- **Base:** push one enemy one lane left or right.
- **Wave:**
  1. The push deals 2 damage.
  2. An enemy pushed into another enemy damages both.
  3. Push every enemy in a row.
- **Depths:**
  1. The target lane becomes Quicksand for the fight.
  2. Enemies in it lose Immovable.
  3. Enemies in it have -1 SPD.
- **Pacts:**
  - Norse: your front unit in the new lane immediately strikes the pushed enemy.
  - Egyptian: pushed enemies gain Poison 2.
- **Capstone:** also one free push every round, without using the power.

### Osiris's Return (Egyptian)

- **Base:** return your last dead ally with 1 HP.
- **Life:**
  1. Returns at half HP.
  2. Returns at full HP with Shield 2.
  3. Return your last two dead allies.
- **Wings:**
  1. Place it on any empty tile.
  2. It gains Veil.
  3. Its On-Play triggers again.
- **Pacts:**
  - Norse: its On-Death triggers as it returns.
  - Greek: it returns with Taunt and +1 ATK per adjacent ally.
- **Capstone:** the first ally to die each fight also returns automatically.

### Sekhmet's Plague (Egyptian)

- **Base:** Poison 1 to every enemy in one lane.
- **Plague:**
  1. Poison 2.
  2. Also hits the adjacent lanes.
  3. Poison from the power doesn't decay this fight.
- **Hunt:**
  1. Your units deal +1 damage to poisoned enemies.
  2. A poisoned enemy that dies heals your Core by 2.
  3. Scarabs you summon this fight apply Poison 1 on attack.
- **Pacts:**
  - Greek: front-row allies gain Shield equal to the Poison applied in their lane.
  - Norse: when a poisoned enemy dies, a random ally gains Frenzy.
- **Capstone:** at the start of every round, Poison 1 spreads to one random enemy.

### Scaling

Each new pantheon costs about 16 cards, 2 trees, and one new pact node in every existing tree.

| Pantheons | Powers | Pact nodes per tree |
|---|---|---|
| 3 | 6 | 2 |
| 4 | 8 | 3 |
| 5 | 10 | 4 |

## 7. Risks and open questions

- **Power balance:** some trees may be much stronger. The balance sim should report win rate per power and per capstone, as it does per patron today.
- **Strength curve:** the base must be noticeable but weak; a fully upgraded power must not decide fights alone.
- **Long fights:** once per fight may feel thin in act 2-3 boss fights. Capstones add second uses; a recharge rule (every 4 rounds) is the fallback.
- **Draft pressure:** watch whether players take weak main-pantheon cards just to hit thresholds. If so, lower the thresholds or count Rares as 2.
- **Spellward:** decide whether powers count as spells (blocked by Spellward) or bypass it.
- **Upgrade screen:** a new screen after the card pick, plus a tree view in the sidebar and the deck overlay.
- **Shrines and Divine cards:** shrine events name a random pantheon; they could favour the main pantheon.
- **Existing relics** that assume the patron model (patron relics, Seer's Lens) need new homes.

## 8. Version 1 (implemented)

Act 1 only, so the trees are cut down from section 6. Sections 6-7 stay as the long-term target.

### Flow

1. **Choose a patron** (Norse, Greek, Egyptian): sets the main pantheon, the signature starting card and Core 55. Each patron tile shows its two powers.
2. **Choose a god power** from that patron's two. "Back to patrons" returns to step 1.
3. No starting relic. Mead of the Einherjar, Spartan Standard and Scarab Amulet are Uncommon pool relics.
4. **Rewards:** one card of the three is always from the main pantheon; the other two come from the full pool.
5. **Cooldown:** after a fight where the power was used, it recharges for 3 floors (used on floor 4, ready again on floor 8). Fights without using it cost nothing.

### Tree format (v1)

- **Two branches** of the god's own pantheon, **two tiers** each. Tier 2 needs tier 1 of its branch.
- **One generic Pact node:** needs 3 cards drafted from *any* other pantheon. Because it doesn't name a pantheon, adding a new pantheon changes no existing tree.
- **Thresholds:** an upgrade at 2, 4 and 6 main-pantheon cards drafted, so 3 of the 5 nodes per run. Only cards added (rewards, shop, shrines) count; removing cards never loses progress.
- The pick happens on the map right after a threshold is reached. The sidebar shows the power, upgrades owned and progress, and opens the tree.

### Roster (v1)

| Power | Base | Branch 1 | Branch 2 | Pact |
|---|---|---|---|---|
| Tyr's Oath | Sacrifice an ally; your other units gain +1 ATK this round | Blood: +2 ATK > lasts the fight | Oath: heal Core by its HP > the card returns to hand | +1 Faith |
| Thor's Thunderclap | 3 damage to an enemy | Storm: +1 per ally fallen (max +3) > a kill refunds it once | Hammer: also hits another unit in the lane > 2 damage to the units left and right | Shield 2 to your units in the lane |
| Zeus's Lightning Bolt | 2 damage, then chains to 1 random enemy for 1 | Chain: +2 chains > chains deal 2 | Sky: first hit deals 4 > Faith per kill | Ranged units +1 ATK this round |
| Poseidon's Tide | Push an enemy front unit; impact 2 | Wave: impact 4 > Riptide | Undertow: your front unit in the new lane strikes > +1 move | Draw 1 |
| Osiris's Return | Return the last dead ally to an empty tile at 1 HP | Life: full HP > Shield 3 | Wings: +2 ATK > Revive | Heal Core 3 |
| Sekhmet's Plague | Poison every enemy in a lane | Plague: adjacent lanes too > enemy poison ticks for 2 | Hunt: 1 damage to each > poisoned kills heal Core 2 | Heal your units 1 |

### Growing it later

- **New acts:** append tier 3 nodes and more thresholds (8, 10, ...); add capstones and boss-granted upgrades. Existing nodes keep their ids and effects.
- **New pantheons:** add a patron with two powers. The generic Pact needs no change; pantheon-specific pacts (section 6) can be added as extra nodes later.

### First balance numbers (bot, 60 runs per power)

Bot win rate is 50% with powers versus 28% when it never uses them. Per power: Tyr 30%, Thor 32%, Zeus 53%, Poseidon 58%, Osiris 60%, Sekhmet 68%. The Norse powers likely need a buff (the bot also plays Tyr cautiously).

