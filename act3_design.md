# Act 3 and the Fourth Archetypes — Design Scout

Scout only. Nothing here is implemented, and this is not the build plan. It records the direction worth planning next: one new archetype for each pantheon, and a final act. Card stats and boss numbers are first-pass placeholders, in the same spirit as the early Act 2 notes. A battle roster, art list, and phased build come after the direction is settled.

The through-line: the new archetypes are the bindings the gods used, and Act 3 is what those bindings were holding down. The cards are drafted from Act 1 onward, so the player has already learned the verb by the time the finale asks for it.

## 1. What the nine archetypes already own

Each archetype is one rule a paragraph can explain.

| Pantheon | Archetype | Rule |
|---|---|---|
| Norse | The Doomed | Death is the resource. On-Death buffs, sacrifice, Berserker and Odin. |
| Norse | Raiders | Movement during the round. Moving grants ATK, strikes, or both. |
| Norse | The Pack | Wolf bodies in lane pairs. Pack, Flank, tokens. |
| Greek | The Olympians | The formation. Rally, neighbours, shields, a front wall. |
| Greek | The Oracle | Casting spells. Pythia, Hermes, the Tripod, Faith. |
| Greek | The Forge | Armaments attached to a body. Gear returns through the draw pile. |
| Egyptian | The Eternal | Staying and growing. Revive, Growth, Book of the Dead. |
| Egyptian | Swarm | A full front of Scarabs. Width and count. |
| Egyptian | The Sun | A lit slot. Sunlit terrain and Burn on a body. |

The open verb is something that waits, leaves, or marks a place. A fourth death trigger, a fourth token tribe, or a fourth "buff the neighbours" rule would sit on top of a deck that already exists.

Reserved god-power names, still unused as powers: Freyja, Heimdall, Athena, Hephaestus, Ra. Hephaestus and Ra already describe the Forge and the Sun. Athena's shields describe the Olympians. This scout spends Freyja on Runes. Heimdall stays unused.

## 2. Patrons

A patron stays a pantheon, a signature starting card, and a choice of two god powers. The three tiles stay Shieldmaiden, Myrmidon, and Mummy Guardian.

The new cards enter the draft, the shop, and off-pantheon rewards the way Pack, Forge, and Sun did. They are not a fourth pantheon, and they do not add a third power or a nine-button patron screen. Offering the archetype's common unit as an alternate starting card (Volva beside Shieldmaiden, Rower beside Myrmidon, Scribe of Thoth beside Mummy Guardian) waits until the archetype has been played. That choice was already noted at the end of `act2_design.md`.

New pantheons stay possible later. The Pact node is generic on purpose, so a new pantheon would not rewrite the trees. A fourth pantheon would thin the draft before these three rules have been played.

## 3. Rules carried over

From the Act 2 archetype phases:

- About seven cards each: two Commons, three Uncommons, one Rare, and the set includes a spell or a token where the rule needs one.
- One new rule, readable in a single rulebook paragraph.
- The cards appear in every act, Act 1 rewards included.
- A bot that drafts the archetype should land within ±1 HP per fight of that pantheon's other archetypes.
- Each archetype needs a back-row or off-board role, so it does not become another front-row swarm.
- The new cards are not spells unless they say they are. Runes and edicts do not trigger Pythia, Hermes, or Oracle's Tripod, the same way Armaments do not.
- God powers for these archetypes wait. Powers are pantheon-level, and the Act 2 note already deferred a third power until the archetypes had been played.

## 4. Norse: Runes

**Rule.** A rune is a card played onto one of your units, or onto an empty slot of yours. It sits there until its own condition happens, then it exhausts. A unit holds one rune, and a slot holds one. Playing a new rune sends the old one to the discard pile, untriggered. If the bearer dies before the rune triggers, the rune exhausts, so sacrifice cannot replay it. A rune on an empty slot attaches to the next unit deployed or moved onto that slot. Until then, a slot-rune still resolves if its text can fire without a bearer. Runes are not spells.

The back-row role is the Volva, who wants to stay alive and keep inscribing. That is the opposite of the Doomed, who want a death, and of the Pack, who want a pair in the lane. Raidho is the seam with Raiders: the rune pays off a move you were going to make anyway.

| Card | Rarity | Cost | Stats | Text |
|---|---|---|---|---|
| Bindrune | Common | 1 | rune | The bearer has +2 ATK. Spent after it attacks once. |
| Ward Rune | Common | 1 | rune | The first time the bearer would take damage, it gains Shield 4 and the rune is spent. |
| Volva | Common | 1 | 1 / 3 / SPD 2 | Ranged. Your first Rune each round costs 1 less. |
| Kenaz | Uncommon | 1 | rune | End of round: deal 3 to the front enemy in this lane (the back enemy if the front is empty). Spent. Fires from an empty slot. |
| Raidho | Uncommon | 1 | rune | The next time you move the bearer, it may move a second time. Spent. |
| Norn's Warning | Uncommon | 1 | spell | Draw 1. Inscribe a random Common rune onto an ally. That rune costs 0. |
| Freyja | Rare | 3 | 2 / 5 / SPD 2 | Ranged. The first rune you spend each round resolves twice. Whenever one of your runes is spent, Freyja gains +1 ATK. |

A rune shows a small mark on the token or on the empty tile, and the hover names it, the way an Armament shows an anvil.

Later, if a third Norse power is earned: Freyja's Seidr, inscribe a free Common rune. Not part of this scout's build.

**Set aside: the Jotunn.** One slow body that freezes a lane. It is a clean verb, and it mostly replaces the Norse cards you already draw rather than playing with them. Runes are the one to plan.

## 5. Greek: The Voyage

**Rule.** A unit with Embark can leave the board during planning. The card is set aside face up, "at sea." It is not in hand, not in the discard, and not dead, so On-Death, Revive, and Book of the Dead do not see it. Armaments stay on it and come back with it. It misses the battle phase. At the start of the next planning phase it returns to an empty slot you choose, then its Landfall line resolves. If no slot is empty, it stays at sea, still visible. It can embark again on a later planning phase, so the rhythm is away, then ashore and fighting, then away again. Immovable units cannot embark. Embark on a printed keyword is free. The spell is what sends a unit that was never a sailor.

Recall puts a card back in hand and refunds its cost, and the unit can be replayed the same round. Raiders move during the round and still fight. Embark is the third timing: gone for the battle, back next plan, to a slot you pick.

The back-row role is the Argo. It does not sail. It is the harbour a landing wants to reach.

| Card | Rarity | Cost | Stats | Text |
|---|---|---|---|---|
| Rower | Common | 1 | 2 / 3 / SPD 3 | Embark. Landfall: +2 ATK this round. |
| Embarkation | Common | 1 | spell | An ally that is not Immovable embarks. |
| Lookout | Uncommon | 2 | 2 / 4 / SPD 3 | Ranged. When an ally embarks from a lane, deal 2 to the front enemy in that lane. |
| Argo | Uncommon | 2 | 0 / 8 / SPD 1 | Doesn't attack. When an ally's Landfall happens in Argo's lane, that ally gains Shield 3 and +1 ATK this round. |
| Odysseus | Uncommon | 2 | 3 / 4 / SPD 4 | Embark. Landfall: strike the front enemy in his lane for his ATK. |
| Homecoming | Uncommon | 1 | spell | One unit at sea returns now to an empty slot and resolves Landfall. |
| Jason | Rare | 3 | 3 / 5 / SPD 4 | Embark. Landfall: every other unit at sea returns with him, each to the nearest empty slot, and each strikes the front enemy in its lane for its ATK. |

Units at sea are shown beside the board, the way Hades's claimed cards are listed, so the player can see who is coming home.

**Set aside: the Fates.** Setting the next draw is a real deckbuilder verb, and it sits next to Augury and the Oracle. The Voyage is the rule that earns its own paragraph.

## 6. Egyptian: Edicts

**Rule.** An edict is a card played onto a lane. It stays until its own text spends it, or until another edict replaces it (the old one goes to the discard pile). One edict per lane. While it lasts, it affects units on both sides of that lane, yours and the enemy's, and only while they stand there. Leaving the lane drops the effect at once. Edicts are not spells.

Poison sticks to a body until a heal. Burn decays on a body. Flooded is Act 2's terrain. An edict is a mark on a place, and it is a puzzle because it cuts both ways until Thoth is on the board. The back-row role is the Scribe, who writes from a lane he does not want to stand in.

| Card | Rarity | Cost | Stats | Text |
|---|---|---|---|---|
| Writ of Weight | Common | 1 | edict | Units in this lane have -1 ATK. Exhausts after 3 rounds. |
| Writ of Binding | Common | 1 | edict | Units in this lane can't move, be pushed, or embark. Spent when a unit in the lane dies. |
| Scribe of Thoth | Common | 1 | 1 / 3 / SPD 2 | Ranged. Your first Edict each round costs 1 less. |
| Writ of Hours | Uncommon | 2 | edict | End of round: each unit in this lane takes 1. Exhausts after 3 ticks. |
| Writ of the Ba | Uncommon | 1 | edict | When a unit dies in this lane, gain 1 Faith next round and spend the edict. |
| Shifting Papyrus | Uncommon | 1 | spell | Move one of your edicts onto another lane. |
| Thoth | Rare | 3 | 2 / 5 / SPD 2 | Ranged. Your edicts affect only enemy units. When you play an edict, draw 1. |

An edict shows on the lane, under the grid, with its name. Both rows of that lane are marked, so a Binding is visible before you move.

Player-made Flooded is not this archetype. Act 2 already owns that terrain. Another Scarab-style token swarm is not it either.

## 7. Act 3 setting: The Primordial

Act 1, The Dying Stars, is the ruins of the living world, with the Void leaking in. Act 2, The Drowned Underworld, is the afterlife still doing its job: ferries, tolls, weighing, flooded stone. Act 3 is why they fell. Under the drowned world, the bodies these pantheons overthrew are waking. Ymir's flesh, Kronos's gullet, and the waters of Nun.

- **Look:** bruised flesh, starless black water, gold seams where a binding still holds. Act 1 was purple over sandstone. Act 2 was dark teal and bone-white. Act 3 should not be another wash of either.
- **Map:** the same generator and the same 15 floors (`Run.FLOORS`), read as a vast body. Nodes sit on wounds, sealed mouths, and cracks in the gold. The tint wants to be warm and dark, not the Act 2 teal.
- **Board:** the same 4 lanes and 2 rows. New tile art, as Act 2 replaced the courtyard with wet stone. The ground can look like hide and black water. It does not lose slots. Nidhogg already rots slots out of the fight, and a second shrinking board would stack with the handlock problem already noted in `act2_design.md`.

The act's verb is **Sunder**. A colossal enemy occupies more than one lane. The first time it falls to half its HP, it does not die. It leaves the fight and two lesser bodies appear in the lanes it occupied. Sunder is not a death: On-Death, Revive, Devour, Horus's Faith, and "whenever a unit dies" do not see it. The children are new units, and they can die normally. Half HP is the cut, so the fight is the giant and then its pieces, not a giant plus its pieces piled on one HP total.

One boss is the ground itself, in section 9. Ordinary fights use Sunder and heavy bodies. They do not each carry a second Core.

### Enemy sketches

Placeholders, late-Act-2 strength plus a small step. The battle list is deferred.

| Enemy | Sketch | Rule it teaches |
|---|---|---|
| Husk | 3 / 8, one lane | A piece left over from a Sunder. No new rule. |
| Bound Giant | 4 / 16, two lanes | Sunder at half into two Husks. The basic colossus. |
| Gold Seam | 0 / 12, Immovable, one lane | While it lives, the colossus in its battle does not check Sunder. Kill the binding, then the body can be cut. |
| Waking Serpent | 3 / 7, Ranged | Attacks the lane where you have the most units. Punishes the full front. |

Elites and the early/late split wait for the build plan. Three elites is enough if each one teaches Sunder, the gold seam, or the boss's own rule. Act 2 used five because the underworld had more separate verbs.

## 8. Act 3 bosses

One boss per run, picked at setup, never repeating a boss from earlier in that run. The Act 2 pattern holds: a hint and a blurb, and the map shows the boss once the act starts. Numbers are the Act 2 boss band (about 60-70 HP) and will move in the sim.

### Ymir (Norse)

The body the world was cut from. Two or three lanes, slow, huge. Sunder at half into two Jotunn (real units, not tokens that revive).

**The ground bleeds.** After the Sunder, each empty slot on your side deals 1 to the Core at end of round. Slots are not deleted and units are not pushed off them. Emptiness hurts, so a full board is the answer. Pack and Swarm want that shape already. The Doomed, who sacrifice their own bodies, pay for the holes they open. Raiders can step into a hole before the round ends.

This is the boss that is the ground. The bleed is Ymir's phase 2, not a mechanic stapled onto every Act 3 fight.

### Kronos (Greek)

Time with a mouth. He stands behind a line of Husks.

**Devour Tomorrow.** When planning ends, he sets aside the top card of your draw pile for the rest of the fight. It is not in the discard, not in hand, and not claimed the way Hades claims a card you were holding. You can see it beside the board. At half HP he sets aside two cards a round. Sunder is optional here: if he splits, the children inherit the devour for one card between them, so the rule does not double by accident.

Hades takes the expensive card in hand and can be forced to give it back. Kronos takes the future, sight unseen, and does not give it back until the fight is over. Deep combo decks feel it. A deck that can fight with whatever it already drew does not.

He does not shorten the round clock. Spare-round gold stays a reward for winning early. A boss whose trick is "you have fewer rounds" would delete that reward by force.

### Nun (Egyptian)

The water before there was land. Wide, back row, not a Sunder body. She rises instead of splitting.

**The unmarked lane.** At the start of the round, the lane with the fewest of your units is unmarked. Each of your units there takes 3. If that lane is empty, the Core takes 3. At half HP she marks the two emptiest lanes. A tie is the leftmost lane.

Answering her does not require an edict. A unit in the lane is enough, which every deck can do. Runes on a slot, Sunlit, Ley Lines, and edicts make a lane feel claimed, and the hover can call a lane marked when it has one of those, so the new cards are a comfort rather than a requirement. The rulebook line is: a lane with one of your units is marked; terrain and edicts mark an empty lane too.

She must not be Flooded. Act 2 owns the river. Nun is the water that unmakes a lane you left bare.

## 9. The other endings

Kept here so the next plan does not relitigate them from memory.

### The Firmament

Surface, then underworld, then the abandoned palaces in the sky. Falling: a back-row body can be dropped into the front. Constellations: two units linked across lanes share a wound or a buff. The map trilogy is the best version of "where does the journey go."

It overlaps the cards more than the Primordial does. The Solar Barque and the Valkyrie already touch the sky. An eclipse that turns Sunlit off, or a round where Ranged cannot fire, spends a fight deleting one archetype. If the Primordial ever feels wrong in play, the Firmament is the replacement setting. Its verbs would be Falling and linked stars, and it would still refuse a round that switches a drafted archetype off.

### The Void

The title and The Dying Stars already point here. Void rifts, Void Taint, and Void Rot are in the game. An act whose rules are erase a card and silence a unit's keywords spends the finale turning off the deck the player just assembled. The Void stays a spice: shrines, curses, maybe one elite who eats a card for a round and then returns it. It is not the third act.

## 10. How the two halves meet

Runes, the Voyage, and edicts are the bindings. Act 3 enemies are what was bound.

- A Gold Seam is the same idea as a rune or an edict, seen from the other side: a mark on a place that is holding a body shut. Breaking it is the player's version of spending a rune.
- Jason and Homecoming are how a Voyage deck answers Ymir's bleed: the bodies come back from the sea into the empty slots before the round ends.
- Writ of Binding is how an edict deck holds a Husk still long enough to cut the giant behind it.
- Nun rewards a lane that has been written on, without requiring the player to have drafted Thoth.

None of these are Act 3-only cards. A Bindrune is already useful on a Shieldmaiden in Act 1.

## 11. What a third act does to the run

- `Data.ACTS` gains a third entry. Beating the Act 2 boss opens Act 3. Victory is the Act 3 boss. The between-act screen stays the one Act 2 built: heal 75% of missing Core HP, one free power upgrade, cooldown cleared.
- Tier 3 was gated at 16 main-pantheon cards because two acts do not reach it. The Act 2 sim put focused decks around 8-10 by the end of Act 2, with the bot stopping near a 22-card deck. A third act of card rewards is what makes Blood Eagle, Ragnarok, Wrath of Olympus, Field of Reeds, and the other tier-3 nodes a thing a devoted deck can actually pick. Thresholds stay 4, 8, 12, and 16. No new threshold in this scout.
- Shop prices and reward odds take another step toward Rare, the way Act 2 took a 15% step and shifted the odds. The exact multiplier waits for the sim. Act 3 fights should still cost a survivable amount of Core HP across the act. Act 2's lesson was that 8 or more HP per fight ended runs before the boss.
- Continue saves already store the act index. New run fields, if a later plan adds any, need defaults so an old save still loads.
- The balance sim reports Act 3 on its own, and reports the new archetypes against their siblings in every act.

## 12. Decisions in this scout

- A fourth archetype per pantheon, not a fourth pantheon.
- Patrons stay the three tiles and the two powers. Alternate starting cards and third powers come after these archetypes have been played.
- Norse is Runes. Greek is the Voyage. Egyptian is Edicts.
- The Jotunn line, the Fates, player-made Flooded, and another token tribe are not the fourth archetypes.
- Act 3 is the Primordial: Sunder, then Ymir, Kronos, and Nun.
- Ymir punishes empty slots without deleting them. Kronos eats the top of the deck, not the hand, and does not shorten the clock. Nun punishes the emptiest lane, and a single unit marks it.
- The Firmament is the backup setting. The Void stays shrines, curses, and at most one elite.
- New archetype cards are in every act.

## 13. Open questions

- A rune on an empty slot is inherited by the next unit. Confirm that deploying there is always legal, and that Kenaz on an empty slot is the exception that fires with no bearer.
- Jason's Landfall brings the whole crew home and lets them strike. That may be a second Rare's worth of power. The sim will say whether the strikes should be his alone.
- Writ of Binding stops embarking. That is a deliberate cross-pantheon snag, aimed at enemies as much as at the player's Rowers. Worth watching once both exist.
- Whether Act 3 should be shorter than 15 floors. A shorter climax is the main reason to change `FLOORS` per act. This scout keeps one length so the generator does not grow a special case before the fights exist.
- The Act 3 price multiplier and the reward odds.
- Whether Sunder's children should be allowed to Sunder again. This scout says no: one cut, then ordinary bodies.

## 14. Not in this scout

- The battle roster, elite designs beyond the Gold Seam sketch, events, relics, map art, and board art.
- A third god power, capstones, and any change to the 4 / 8 / 12 / 16 thresholds.
- Handlock. Still the deferred note in `act2_design.md`: a full hand plus a full board, made worse by rotted slots. Act 3 does not add another effect that deletes slots.
- Per-branch upgrade conditions, also still deferred.
- Turning the patron screen into an archetype picker.
