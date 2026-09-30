extends RefCounted
## Battle rules shown in the in-fight help panel, one entry per tab: [title, BBCode text].
## Keep in sync with combat.gd.

const SECTIONS := [
	["Basics", """[font_size=22][b]Goal[/b][/font_size]
Destroy every enemy before the round limit. If time runs out, each surviving enemy hits your [b]Reliquary Core[/b] for its [b]Threat[/b].
The run is lost only when the Core reaches 0 HP. Losing all your units does [b]not[/b] lose the fight - you can deploy again next round.

[font_size=22][b]The battlefield[/b][/font_size]
Both sides have [b]4 lanes[/b] and [b]2 rows[/b] (front and back). Units fight across their lane: your lane 1 faces enemy lane 1.

[font_size=22][b]A round has two phases[/b][/font_size]
[b]1. Plan[/b] - you get Faith, draw cards and see what every enemy intends to do. Play cards and move units. Nothing fights yet, and [i]Restart planning[/i] undoes everything you did this phase.
[b]2. Resolve[/b] - press [i]End planning[/i]. Everything then happens automatically, in this order:
    [color=#ffd966]a.[/color] Start-of-round effects (Support, Rally, Zeus, Scarab Queen, ...)
    [color=#ffd966]b.[/color] Every unit attacks once, in [b]initiative[/b] order (see Attacking)
    [color=#ffd966]c.[/color] End-of-round effects (Growth, Apollo, Scarab Amulet, the Herald's Void Tide)

[font_size=22][b]Round limit[/b][/font_size]
Normal and elite fights last [b]3 rounds[/b]. Deeper floors add rounds (noted in the fight title), and Golden Fleece adds 1. The boss fight has no limit, but its Void Tide hits your Core every round."""],

	["Attacking", """[font_size=22][b]Initiative: who acts first[/b][/font_size]
Units act from [b]highest SPD to lowest[/b]. Ties are broken in this order:
    [color=#ffd966]1.[/color] Your units before enemies
    [color=#ffd966]2.[/color] Lower lane number first
    [color=#ffd966]3.[/color] Front row before back row
A unit killed before its turn does not act.

[font_size=22][b]Who can attack[/b][/font_size]
Front-row units always attack. Back-row units attack only if they are [b]Ranged[/b]. Melee units in the back row wait, but their Support, Rally and Reinforce still work.
There is [b]no counter-damage[/b]: only the attacker deals damage.

[font_size=22][b]Choosing a target[/b][/font_size] (checked top to bottom)
    [color=#ffd966]1. Taunt.[/color] An enemy with Taunt in the attacker's lane or an adjacent lane must be attacked - own lane first, then the lane to the left, then the right. A back-row Taunt unit only counts if nothing stands in front of it.
    [color=#ffd966]2. Own lane.[/color] The front unit, or the back unit if the front slot is empty.
    [color=#ffd966]3. Empty lane.[/color] [b]Your[/b] units attack the nearest lane that has an enemy (left before right when equally close), front unit first. [b]Enemies[/b] hit your Core instead.

Ranged attackers cannot target a unit standing on [b]Ruins[/b], and melee attackers cannot target [b]Airborne[/b] enemies. Units they can't target are skipped as if the slot were empty.
With [b]Eye of Horus[/b], your Ranged units check the back row before the front row.
Some enemies have their own rule, shown in their text: the Void Wisp snipes your lowest-HP unit, and the Hollow Archer and Carrion Harpy hit your back row first."""],

	["Keywords", """Hover over any unit or card to see its full text. Keywords mean:

[table=2]
[cell][b]Shield X[/b]   [/cell][cell]Absorbs the next X damage before HP. Stacks and lasts the whole fight.[/cell]
[cell][b]Taunt[/b][/cell][cell]Enemies attacking from its lane or an adjacent lane must target it (see Attacking).[/cell]
[cell][b]Ranged[/b][/cell][cell]Can attack from the back row. Can't target units on Ruins.[/cell]
[cell][b]Cleave[/b][/cell][cell]Also hits the units in the lanes on both sides of the target, in the same row, for full damage.[/cell]
[cell][b]Pierce[/b][/cell][cell]Damage beyond what kills the target carries to the unit behind it. An enemy's Pierce continues into your Core.[/cell]
[cell][b]Rally X[/b][/cell][cell]Start of round: its row neighbours gain +X ATK for the rest of the fight. Stacks every round.[/cell]
[cell][b]Support[/b][/cell][cell]Start of round: helps the ally directly in front of it (same lane). Works from the back row.[/cell]
[cell][b]Reinforce[/b][/cell][cell]When the ally in front of it dies, it immediately steps into the front slot.[/cell]
[cell][b]On-Death[/b][/cell][cell]Triggers when the unit dies (and also when it Revives).[/cell]
[cell][b]Revive[/b][/cell][cell]Once per fight: when it dies, its On-Death and other units' "whenever an ally dies" effects trigger, then it returns in the same slot with 1 HP.[/cell]
[cell][b]Growth[/b][/cell][cell]End of round: gains the listed stats.[/cell]
[cell][b]Summon[/b][/cell][cell]Creates a token (like a 1/1 Scarab) in an empty slot. Tokens never join your deck.[/cell]
[cell][b]Exhaust[/b][/cell][cell]After you cast it, the card is gone for the rest of this fight.[/cell]
[cell][b]Immovable[/b][/cell][cell]Can't be pushed or swapped and takes no collision damage.[/cell]
[cell][b]Threat[/b][/cell][cell]Damage the enemy deals to your Core if it survives until time runs out.[/cell]
[cell][b]Empowered[/b][/cell][cell]On deeper floors, one enemy per fight gets bonus ATK and HP. It is marked on the board.[/cell]
[/table]

[font_size=22][b]Enemy keywords[/b][/font_size]
[table=2]
[cell][b]Thorns X[/b]   [/cell][cell]Melee units that attack it take X damage. Ranged attacks and spells are safe.[/cell]
[cell][b]Airborne[/b][/cell][cell]Melee attacks can't target it (Cleave splash skips it too). Use Ranged units and spells.[/cell]
[cell][b]Veil[/b][/cell][cell]Ignores the first damage it takes each round, however small. Open with a weak hit, then strike hard.[/cell]
[cell][b]Split[/b][/cell][cell]When it dies, two smaller copies appear in its slot and the nearest empty slot in its row (left first).[/cell]
[cell][b]Frenzy[/b][/cell][cell]Gains +1 ATK each time it takes damage and survives. Kill it in one burst.[/cell]
[cell][b]Poison[/b][/cell][cell]Units it hits are Poisoned: they take 1 damage at the end of every round. Any heal cures it, even at full HP.[/cell]
[cell][b]Spellward[/b][/cell][cell]Your spells can't target it or the enemies next to it (left, right, in front, behind). It gains Shield 2 whenever you cast a spell.[/cell]
[/table]"""],

	["Cards & moves", """[font_size=22][b]Faith[/b][/font_size]
You get [b]3 Faith[/b] each Plan phase to pay for cards. Unspent Faith is lost.

[font_size=22][b]Drawing and your hand[/b][/font_size]
Draw [b]5 cards[/b] in round 1 and [b]2[/b] in each later round. Your hand carries over between rounds, up to [b]7 cards[/b] - with a full hand, extra draws stay in the deck. When the deck runs out, the discard pile is shuffled into a new deck.

[font_size=22][b]Playing cards[/b][/font_size]
[b]Units[/b] deploy into any empty slot on your grid. When a unit dies, its card goes to the discard pile and can be drawn again this fight.
[b]Spells[/b] go to the discard pile after casting, unless they Exhaust.
Dimmed cards can't be played right now (not enough Faith, or no legal target).

[font_size=22][b]Moving units[/b][/font_size]
Once per round, click one of your units, then an empty slot on your grid, to move it. Some cards give extra moves (Loki, Longship). The status panel shows your moves left.
Units that entered the board this round - deployed, returned by Book of the Dead, or summoned by a spell - can't move until the next round. Units on Quicksand can't move at all.

[font_size=22][b]Curses and statuses[/b][/font_size]
They can't be played and just take up space. They leave your hand at the start of the next round: curses go to the discard pile, statuses are exhausted. Some also cost Faith or Core HP - read the card.
Enemies marked [color=#ff9a9a](+Void Web)[/color] or similar shuffle a status card into your draw pile each time they attack."""],

	["Enemies & terrain", """[font_size=22][b]Intents[/b][/font_size]
Each enemy shows its plan for the round. Intents are chosen at the start of the Plan phase and [b]lock onto a lane[/b], so you can move units out of a targeted lane to dodge.
    [color=#ffd966]Attack lane X[/color] - a normal attack, using the targeting rules.
    [color=#ffd966]Wait[/color] - a melee enemy in the back row. It does nothing unless it Reinforces.
    [color=#ffd966]CHARGE lane X[/color] - moves into that front slot (swapping with any enemy there), then attacks.
    [color=#ffd966]PETRIFY lane X[/color] - your units in that lane skip their action this round.
    [color=#ffd966]SANDSTORM[/color] - your units in that row have -1 ATK this round.
    [color=#ffd966]TARGET / STRIKE[/color] - the Void Herald's attacks. STRIKE deals 5 to both slots of a lane and to the front units beside it.
    [color=#ffd966]HARVEST[/color] - Hel attacks your lowest-HP unit.
    [color=#ffd966]CONSTRICT lane X[/color] - Apep hits both of your slots in that lane.
    [color=#ffd966]AIM / SIEGE lane X[/color] - the Siege Engine aims one round, then hits both of your slots in that lane for its ATK the next. The lane is marked on your side - move out before it fires.
    [color=#ffd966]QUICKSAND[/color] - the Geomancer turns that slot of yours into Quicksand at the end of the round.
    [color=#ffd966]TRANSFORM[/color] - Circe turns that unit into a Swine for the round: it can't attack or use start-of-round effects.

[font_size=22][b]Bosses[/b][/font_size]
Each run faces one of three bosses, shown on the map from the start (hover the boss node). Boss fights have no round limit, and each boss favours some strategies and punishes others:
    [color=#ffd966]Void Herald[/color] - fills lanes 2-3. Its Void Tide deals 5 to your Core every round, so slow decks suffer.
    [color=#ffd966]Hel[/color] - hides behind Draugr that rise again each round. HARVEST hits your lowest-HP unit, and every unit you lose for good heals her 2 and costs the Core 2. She grows stronger each round. Keep your units alive.
    [color=#ffd966]Apep[/color] - coils across the whole back row. Shield is useless while it lives, units it kills can't Revive, and CONSTRICT crushes whole lanes - move out of them.
When Hel or Apep falls, their minions go with them.

[font_size=22][b]Terrain[/b][/font_size]
    [color=#ffd966]Ley Line[/color] (gold border) - the unit in this slot has +2 ATK.
    [color=#ffd966]Ruins[/color] (brown border) - cover: Ranged attacks can't target the unit in this slot.
    [color=#ffd966]Quicksand[/color] (sand border) - the unit in this slot can't be moved and has -1 SPD. Only enemy Geomancers create it.
Terrain can appear on either side of the board - enemy archers sometimes shelter in Ruins, and enemies on a Ley Line hit harder. Terrain belongs to the slot, not the unit: moving a unit off it loses the effect. A slot holds one terrain at a time. Channel Ley Line creates a Ley Line on a front slot and Raise Ruins creates Ruins on a back slot, for the rest of the fight - only on slots without terrain, but a unit may already stand there.

[font_size=22][b]Pushing and collisions[/b][/font_size]
Rebuke pushes an enemy front unit one lane. If it hits another unit, both take 3 damage. If it hits the edge of the board, it takes 3."""],
]
