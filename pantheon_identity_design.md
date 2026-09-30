# Pantheon Identity: Design Options

Status: **discussion / not implemented**. Captures the options for making the starting choice matter, how they compare, and the direction currently favoured.

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

## 5. Favoured direction

**G + H, with between-fight bonuses instead of devotion.**

1. **Pick two pantheons** at run start. Reward, shop and shrine pools become those two plus neutral.
2. **Pick one god power** from the four gods of your pair (2 per pantheon). Once per fight, used during planning.
3. **Starting deck:** the neutral starter plus one signature card from each chosen pantheon.
4. **Patron relics** (Mead, Spartan Standard, Scarab Amulet) move into the normal relic pool or become god-power upgrades.
5. **Commitment rewards happen outside battles:** hybrid signature cards per pairing, plus some mix of deck resonance, shrine favour and god-power upgrades at rest sites.
6. **Reward rule** becomes: one card from each of your two pantheons, plus one neutral or random card from your pool. Both halves of the hybrid stay alive.

### Example god powers (placeholders)

| Pantheon | God | Power (once per fight, plan phase) |
|---|---|---|
| Norse | Odin | +2 moves this round; each moved unit strikes the enemy front unit in its new lane |
| Norse | Hel | Destroy one of your units; its On-Death triggers twice |
| Greek | Athena | Your front row gains Shield 3 |
| Greek | Zeus | Deal 3 damage to every enemy in one lane |
| Egyptian | Osiris | Return the last dead ally at full HP |
| Egyptian | Ra | One ally gains +3 ATK permanently |

Several of these names are also cards or bosses (Odin, Zeus, Ra, Hel). Final god powers need names that don't collide with the card and enemy lists.

### Example hybrid signature cards (placeholders)

| Pairing | Card | Idea |
|---|---|---|
| Norse + Egyptian | Draugr Pharaoh | Revive; its On-Death triggers again when it returns |
| Norse + Greek | Shield-Oath | Whenever an ally dies, its row neighbours gain Shield 2 |
| Greek + Egyptian | Sunlit Phalanx | Front-row allies heal 1 at end of round while flanked |

### Scaling

| Pantheons | Pairings | Pairing and god-power starts (4 gods per pair) |
|---|---|---|
| 3 | 3 | 12 |
| 4 | 6 | 24 |
| 5 | 10 | 40 |

A new pantheon costs about 16 cards and 2 gods, plus 2-3 hybrid cards for each new pairing.

## 6. Risks and open questions

- **Pairing balance:** some pairings may be much stronger. The balance sim should report win rate per pairing and per god power, as it does per patron today.
- **God-power strength:** once per fight has to be noticeable but not fight-deciding. Charge-based powers (e.g. every 3 rounds) are the fallback if once per fight feels too swingy or too weak in long boss fights.
- **Pool size:** with 12 cards per pantheon, a pair gives 24 plus 8 neutral. That's fine now, and better once each pantheon reaches its planned ~16 cards.
- **Neutral cards:** decide whether they keep their current share of rewards or shrink so the pairing identity is stronger.
- **Shrines and Divine cards:** shrine events name a random pantheon; they should favour the chosen pair.
- **Starting HP:** currently tied to the patron (55). Either a flat value, or a per-god trade-off.
- **Existing relics** that assume the patron model (patron relics, Seer's Lens) need new homes.

## 7. Rough implementation plan (when ready)

1. **Data:** a gods table (id, pantheon, name, power text, art), and pairing definitions with signature card ids.
2. **Run setup:** a two-step start screen (pick two pantheons, then pick a god); starting deck and HP from the choices.
3. **Pools:** filter reward, shop and shrine card pools by the chosen pantheons plus neutral; new reward rule.
4. **Combat:** a god-power button in the plan phase, implemented as a free, once-per-fight spell-like action (reuse spell targeting); state saved for Restart planning.
5. **Between-fight bonuses:** hybrid cards gated on owned-card counts, and whichever of resonance, shrine favour and rest upgrades are chosen.
6. **Tests and sim:** fuzz every pairing and god power; the sim reports win rate by pairing and by power.
7. **Docs:** update the content list, rules text and print sheets.
