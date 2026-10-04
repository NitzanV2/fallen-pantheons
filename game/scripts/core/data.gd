extends RefCounted
## Static game content. Mirrors fallen_pantheons_content.md.
## Lanes are 0-3 internally (shown to the player as 1-4). Rows: 0 = front, 1 = back.

# Spell "target" values:
#   none            - no target
#   ally            - one of your units
#   ally_card       - one of your units that came from a card (not a token)
#   ally_slot       - a slot on your grid in the card's "row" with no terrain (units there are fine)
#   enemy           - any enemy unit
#   enemy_front     - an enemy front-row unit (plus a push direction)
#   enemy_pair      - two enemy units in the same row
#   empty_ally_slot - an empty slot on your grid

const CARDS := {
	# Neutral
	"ark_sentinel": {"name": "Ark Sentinel", "faction": "neutral", "rarity": "Starter", "type": "unit", "cost": 1, "atk": 2, "hp": 4, "spd": 2, "keywords": [], "text": "Plain melee unit."},
	"echo_archer": {"name": "Echo Archer", "faction": "neutral", "rarity": "Starter", "type": "unit", "cost": 1, "atk": 2, "hp": 2, "spd": 3, "keywords": ["ranged"], "text": "Ranged."},
	"rebuke": {"name": "Rebuke", "faction": "neutral", "rarity": "Starter", "type": "spell", "cost": 1, "target": "enemy_front", "text": "Push an enemy front unit one lane. If it hits a unit or the edge, both take 3. Immovable units are immune."},
	"warding": {"name": "Warding", "faction": "neutral", "rarity": "Starter", "type": "spell", "cost": 1, "target": "ally", "text": "Give an ally Shield 4."},
	"transposition": {"name": "Transposition", "faction": "neutral", "rarity": "Uncommon", "type": "spell", "cost": 0, "target": "enemy_pair", "exhaust": true, "text": "Swap two enemy units in the same row (not Immovable). Their locked intents move with them. Exhaust."},
	"faith_surge": {"name": "Faith Surge", "faction": "neutral", "rarity": "Uncommon", "type": "spell", "cost": 0, "target": "none", "exhaust": true, "text": "Gain 2 Faith. Exhaust."},
	"channel_ley_line": {"name": "Channel Ley Line", "faction": "neutral", "rarity": "Uncommon", "type": "spell", "cost": 2, "target": "ally_slot", "terrain": "ley_line", "row": 0, "exhaust": true, "text": "Turn one of your front slots without terrain into a Ley Line for this fight (+2 ATK there). Exhaust."},
	"raise_ruins": {"name": "Raise Ruins", "faction": "neutral", "rarity": "Common", "type": "spell", "cost": 1, "target": "ally_slot", "terrain": "ruins", "row": 1, "exhaust": true, "text": "Turn one of your back slots without terrain into Ruins for this fight (Ranged attacks can't target it). Exhaust."},

	# Divine - never offered as rewards or in shops. Only rare shrine events grant them.
	"divine_insight": {"name": "Divine Insight", "faction": "divine", "rarity": "Divine", "type": "spell", "cost": 0, "target": "none", "text": "Draw 2 cards."},
	"ambrosia": {"name": "Ambrosia", "faction": "divine", "rarity": "Divine", "type": "spell", "cost": 0, "target": "none", "text": "Gain 2 Faith."},
	"aegis_of_olympus": {"name": "Aegis of Olympus", "faction": "divine", "rarity": "Divine", "type": "spell", "cost": 1, "target": "none", "text": "All allies gain Shield 3."},
	"thread_of_fate": {"name": "Thread of Fate", "faction": "divine", "rarity": "Divine", "type": "spell", "cost": 0, "target": "ally_card", "text": "Return one of your units to your hand. Redeploy it later at full HP."},

	# Norse - The Doomed
	"einherjar": {"name": "Einherjar", "faction": "norse", "rarity": "Common", "type": "unit", "cost": 1, "atk": 3, "hp": 2, "spd": 3, "keywords": [], "text": "On-Death: allies in its lane gain +2 ATK."},
	"shieldmaiden": {"name": "Shieldmaiden", "faction": "norse", "rarity": "Common", "type": "unit", "cost": 2, "atk": 2, "hp": 5, "spd": 2, "keywords": ["taunt"], "text": "Taunt. On-Death: row-adjacent allies gain Shield 3."},
	"raven_of_odin": {"name": "Raven of Odin", "faction": "norse", "rarity": "Common", "type": "unit", "cost": 1, "atk": 1, "hp": 1, "spd": 5, "keywords": ["ranged"], "text": "Ranged. On-Death: draw 1 card."},
	"berserker": {"name": "Berserker", "faction": "norse", "rarity": "Uncommon", "type": "unit", "cost": 2, "atk": 3, "hp": 4, "spd": 4, "keywords": [], "text": "Gains +1 ATK whenever an ally dies."},
	"valkyrie": {"name": "Valkyrie", "faction": "norse", "rarity": "Uncommon", "type": "unit", "cost": 2, "atk": 1, "hp": 4, "spd": 3, "keywords": ["reinforce"], "text": "Reinforce. When she steps forward, she gains the fallen ally's ATK."},
	"ragnarok": {"name": "Ragnarok", "faction": "norse", "rarity": "Uncommon", "type": "spell", "cost": 2, "target": "ally", "text": "Destroy one of your units. Deal damage equal to its current HP to every enemy in its lane."},
	"thor": {"name": "Thor", "faction": "norse", "rarity": "Rare", "type": "unit", "cost": 3, "atk": 4, "hp": 6, "spd": 3, "keywords": ["cleave"], "text": "Cleave."},
	"odin": {"name": "Odin", "faction": "norse", "rarity": "Rare", "type": "unit", "cost": 3, "atk": 2, "hp": 5, "spd": 2, "keywords": ["ranged"], "text": "Ranged. Whenever an ally dies, deal 2 damage to the enemy front unit in that ally's lane."},
	# Norse Raiders - moving units
	"raider": {"name": "Raider", "faction": "norse", "rarity": "Common", "type": "unit", "cost": 1, "atk": 2, "hp": 3, "spd": 4, "keywords": [], "text": "Whenever you move it, it gains +1 ATK."},
	"longship": {"name": "Longship", "faction": "norse", "rarity": "Common", "type": "spell", "cost": 1, "target": "none", "text": "Gain 2 extra moves this round. Units you move this round gain Shield 2."},
	"ulfhednar": {"name": "Ulfhednar", "faction": "norse", "rarity": "Uncommon", "type": "unit", "cost": 2, "atk": 3, "hp": 4, "spd": 4, "keywords": [], "text": "When you move it to a new lane, it deals its ATK to the enemy front unit there."},
	"loki": {"name": "Loki", "faction": "norse", "rarity": "Rare", "type": "unit", "cost": 3, "atk": 2, "hp": 5, "spd": 3, "keywords": ["ranged"], "text": "Ranged. +1 move each round. When you move a unit, deal 1 damage to each enemy in its new lane."},

	# Greek - The Olympians
	"hoplite": {"name": "Hoplite", "faction": "greek", "rarity": "Common", "type": "unit", "cost": 1, "atk": 2, "hp": 4, "spd": 2, "keywords": [], "rally": 1, "text": "Rally 1."},
	"peltast": {"name": "Peltast", "faction": "greek", "rarity": "Common", "type": "unit", "cost": 1, "atk": 2, "hp": 2, "spd": 4, "keywords": ["ranged"], "text": "Ranged. +1 ATK while both row-neighbors are allies."},
	"myrmidon": {"name": "Myrmidon", "faction": "greek", "rarity": "Common", "type": "unit", "cost": 2, "atk": 3, "hp": 5, "spd": 3, "keywords": [], "text": "Start of round: gains Shield 1 for each row-adjacent ally."},
	"athena": {"name": "Athena", "faction": "greek", "rarity": "Uncommon", "type": "unit", "cost": 2, "atk": 1, "hp": 5, "spd": 2, "keywords": [], "text": "Support: the ally in front gains Shield 3."},
	"apollo": {"name": "Apollo", "faction": "greek", "rarity": "Uncommon", "type": "unit", "cost": 3, "atk": 3, "hp": 4, "spd": 3, "keywords": ["ranged"], "text": "Ranged. End of round: heal all allies in his row by 2."},
	"phalanx_formation": {"name": "Phalanx Formation", "faction": "greek", "rarity": "Uncommon", "type": "spell", "cost": 1, "target": "none", "text": "Front-row allies gain Shield 2 and +1 ATK."},
	"achilles": {"name": "Achilles", "faction": "greek", "rarity": "Rare", "type": "unit", "cost": 3, "atk": 5, "hp": 5, "spd": 4, "keywords": [], "text": "Takes no damage from melee attacks. Takes double damage from Ranged, Cleave, and Pierce."},
	"zeus": {"name": "Zeus", "faction": "greek", "rarity": "Rare", "type": "unit", "cost": 3, "atk": 3, "hp": 6, "spd": 2, "keywords": ["ranged"], "text": "Ranged. Start of round: deal 2 damage to each enemy in every lane where you have a front unit."},
	# Greek Oracle - casting spells
	"divine_favor": {"name": "Divine Favor", "faction": "greek", "rarity": "Common", "type": "spell", "cost": 0, "target": "ally", "text": "An ally gains +2 ATK this round."},
	"pythia": {"name": "Pythia", "faction": "greek", "rarity": "Common", "type": "unit", "cost": 1, "atk": 1, "hp": 3, "spd": 3, "keywords": ["ranged"], "text": "Ranged. Whenever you cast a spell, deal 1 damage to the first enemy in her lane."},
	"olympian_ichor": {"name": "Olympian Ichor", "faction": "greek", "rarity": "Uncommon", "type": "spell", "cost": 1, "target": "ally", "text": "Heal an ally by 4. It gains +1 ATK."},
	"hermes": {"name": "Hermes", "faction": "greek", "rarity": "Rare", "type": "unit", "cost": 3, "atk": 3, "hp": 4, "spd": 5, "keywords": ["ranged"], "text": "Ranged. Your first spell each round costs 0. Whenever you cast a spell, Hermes gains Shield 1."},

	# Egyptian - The Eternal
	"mummy_guardian": {"name": "Mummy Guardian", "faction": "egypt", "rarity": "Common", "type": "unit", "cost": 2, "atk": 2, "hp": 5, "spd": 1, "keywords": ["taunt", "revive"], "text": "Taunt. Revive."},
	"scarab_swarm": {"name": "Scarab Swarm", "faction": "egypt", "rarity": "Common", "type": "unit", "cost": 1, "atk": 1, "hp": 2, "spd": 4, "keywords": [], "text": "On-Death: Summon a 1/1 Scarab in its slot (if it Revives, in the other row of its lane)."},
	"priest_of_ra": {"name": "Priest of Ra", "faction": "egypt", "rarity": "Common", "type": "unit", "cost": 1, "atk": 0, "hp": 3, "spd": 2, "keywords": [], "text": "Support: heal the ally in front by 2."},
	"sphinx": {"name": "Sphinx", "faction": "egypt", "rarity": "Uncommon", "type": "unit", "cost": 2, "atk": 2, "hp": 6, "spd": 1, "keywords": [], "text": "Growth: +1 ATK / +1 HP."},
	"anubis": {"name": "Anubis", "faction": "egypt", "rarity": "Uncommon", "type": "unit", "cost": 3, "atk": 3, "hp": 5, "spd": 3, "keywords": [], "text": "Whenever any unit dies (either side), gain +1 ATK / +1 HP."},
	"book_of_the_dead": {"name": "Book of the Dead", "faction": "egypt", "rarity": "Uncommon", "type": "spell", "cost": 2, "target": "empty_ally_slot", "text": "Return the last ally that died this fight to an empty slot at full HP."},
	"ra": {"name": "Ra", "faction": "egypt", "rarity": "Rare", "type": "unit", "cost": 3, "atk": 2, "hp": 6, "spd": 2, "keywords": ["ranged"], "text": "Ranged. Growth: +2 ATK."},
	"osiris": {"name": "Osiris", "faction": "egypt", "rarity": "Rare", "type": "unit", "cost": 3, "atk": 3, "hp": 6, "spd": 2, "keywords": [], "text": "Allies that Revive return at full HP and gain +2 ATK."},
	# Egyptian Swarm - Scarabs
	"sandswarm": {"name": "Sandswarm", "faction": "egypt", "rarity": "Common", "type": "spell", "cost": 1, "target": "none", "text": "Summon a 1/1 Scarab in every empty front-row slot."},
	"scarab_queen": {"name": "Scarab Queen", "faction": "egypt", "rarity": "Uncommon", "type": "unit", "cost": 2, "atk": 1, "hp": 5, "spd": 2, "keywords": [], "text": "Start of round: summon a 1/1 Scarab in the nearest empty slot in her row."},
	"plague_of_locusts": {"name": "Plague of Locusts", "faction": "egypt", "rarity": "Uncommon", "type": "spell", "cost": 2, "target": "enemy", "text": "Deal damage to an enemy equal to the number of units you have."},
	"khepri": {"name": "Khepri", "faction": "egypt", "rarity": "Rare", "type": "unit", "cost": 3, "atk": 3, "hp": 5, "spd": 2, "keywords": [], "text": "Your Scarabs have +1 ATK. Whenever one of your Scarabs dies, heal the Core by 1."},

	# Tokens
	"scarab": {"name": "Scarab", "faction": "token", "rarity": "Token", "type": "unit", "cost": 0, "atk": 1, "hp": 1, "spd": 4, "keywords": [], "token": true, "text": "Summoned token."},

	# Curses - only added by shrines. They can't be played and leave the hand at the start of the next round.
	"void_taint": {"name": "Void Taint", "faction": "curse", "rarity": "Curse", "type": "curse", "cost": 0, "token": true, "text": "Unplayable. Discarded at the start of the next round."},
	"void_rot": {"name": "Void Rot", "faction": "curse", "rarity": "Curse", "type": "curse", "cost": 0, "token": true, "core_damage": 2, "text": "Unplayable. At the start of the next round, discard it and lose 2 Core HP (never lethal)."},

	# Statuses - shuffled into your draw pile by enemy attacks during a fight. They can't be played
	# and exhaust at the start of the round after they're drawn, so each one wastes a draw.
	"void_web": {"name": "Void Web", "faction": "status", "rarity": "Status", "type": "status", "cost": 0, "token": true, "text": "Unplayable. Exhausts at the start of the next round."},
	"hex": {"name": "Hex", "faction": "status", "rarity": "Status", "type": "status", "cost": 0, "token": true, "draw_faith": -1, "text": "Unplayable. When drawn, lose 1 Faith this round. Exhausts at the start of the next round."},
	"ashes": {"name": "Ashes", "faction": "status", "rarity": "Status", "type": "status", "cost": 0, "token": true, "core_damage": 1, "text": "Unplayable. At the start of the next round, it exhausts and the Core takes 1 (never lethal)."},
}

## One-line effect shown on compact non-unit cards; the full text appears on hover.
const CARD_SHORT := {
	"rebuke": "Push 1 lane, 3 on impact", "warding": "Shield 4", "transposition": "Swap two enemies",
	"faith_surge": "+2 Faith", "channel_ley_line": "Create a Ley Line", "raise_ruins": "Create Ruins",
	"divine_insight": "Draw 2", "ambrosia": "+2 Faith", "aegis_of_olympus": "All allies Shield 3",
	"thread_of_fate": "Return a unit to hand", "ragnarok": "Sacrifice: blast its lane", "longship": "+2 moves, Shield 2",
	"phalanx_formation": "Front row +1 ATK, Shield 2", "divine_favor": "+2 ATK this round", "olympian_ichor": "Heal 4, +1 ATK",
	"book_of_the_dead": "Return the last fallen ally", "sandswarm": "Scarabs fill the front row",
	"plague_of_locusts": "Damage = your unit count", "void_taint": "Unplayable", "void_rot": "Unplayable, Core -2",
	"void_web": "Unplayable", "hex": "Unplayable, Faith -1", "ashes": "Unplayable, Core -1",
}

const ENEMIES := {
	"void_spawn": {"name": "Void Spawn", "kind": "enemy", "atk": 2, "hp": 3, "spd": 2, "threat": 1, "keywords": [], "text": "Attacks its own lane."},
	"void_wisp": {"name": "Void Wisp", "kind": "enemy", "atk": 1, "hp": 2, "spd": 5, "threat": 1, "keywords": ["ranged"], "text": "Ranged. Targets the player unit with the lowest current HP."},
	"hollowed_zealot": {"name": "Hollowed Zealot", "kind": "enemy", "atk": 3, "hp": 5, "spd": 3, "threat": 2, "keywords": [], "text": "Attacks its own lane."},
	"hollowed_bulwark": {"name": "Hollowed Bulwark", "kind": "enemy", "atk": 1, "hp": 8, "spd": 1, "threat": 1, "keywords": ["taunt"], "text": "Taunt."},
	"hollow_archer": {"name": "Hollow Archer", "kind": "enemy", "atk": 2, "hp": 3, "spd": 3, "threat": 1, "keywords": ["ranged"], "text": "Ranged. Targets the back unit in its lane, then the front unit, then the Core."},
	"void_weaver": {"name": "Void Weaver", "kind": "enemy", "atk": 1, "hp": 4, "spd": 3, "threat": 1, "keywords": ["ranged"], "status_card": "void_web", "text": "Ranged. Whenever it attacks, shuffles a Void Web into your draw pile."},
	"hollow_hexer": {"name": "Hollow Hexer", "kind": "enemy", "atk": 2, "hp": 5, "spd": 2, "threat": 1, "keywords": [], "status_card": "hex", "text": "Whenever it attacks, shuffles a Hex into your draw pile (lose 1 Faith when drawn)."},
	"ashen_wraith": {"name": "Ashen Wraith", "kind": "enemy", "atk": 3, "hp": 4, "spd": 4, "threat": 2, "keywords": [], "status_card": "ashes", "text": "Whenever it attacks, shuffles Ashes into your draw pile (the Core takes 1 when it exhausts)."},
	"void_charger": {"name": "Void Charger", "kind": "enemy", "atk": 4, "hp": 5, "spd": 4, "threat": 3, "keywords": ["pierce"], "text": "Pierce. Odd rounds: attacks its own lane. Even rounds: CHARGE to the lane with the fewest player units, then attack."},
	"echo_of_fenrir": {"name": "Echo of Fenrir", "kind": "elite", "atk": 4, "hp": 10, "spd": 4, "threat": 3, "keywords": ["cleave"], "text": "Cleave. Gains +1 ATK whenever a player unit dies."},
	"echo_of_medusa": {"name": "Echo of Medusa", "kind": "elite", "atk": 2, "hp": 10, "spd": 2, "threat": 3, "keywords": ["ranged"], "text": "Ranged. PETRIFY the lane with the highest total player ATK (round 1: lane 2). Units there skip their action."},
	"echo_of_set": {"name": "Echo of Set", "kind": "elite", "atk": 3, "hp": 8, "spd": 3, "threat": 3, "keywords": ["revive"], "text": "Revive. SANDSTORM: odd rounds front row, even rounds back row. Player units there get -1 ATK this round."},
	"void_herald": {"name": "Void Herald", "kind": "boss", "atk": 10, "hp": 42, "spd": 3, "threat": 0, "void_tide": 5, "keywords": ["immovable"], "width": 2, "text": "Immovable. Occupies lanes 2-3. Void Tide: the Core takes 5 at the end of every round. Phase 1: TARGET the lane with your highest-ATK unit; summons a Void Spawn each round, plus a Void Wisp in the back row every second round. Phase 2 (half HP or less): STRIKE a lane for 5 to both slots, and 5 to the front units in adjacent lanes."},
	"hel": {"name": "Hel, the Hollow Queen", "kind": "boss", "atk": 5, "hp": 52, "spd": 2, "threat": 0, "keywords": ["ranged", "immovable"], "width": 2, "text": "Ranged. Immovable. Occupies back lanes 2-3. HARVEST: attacks your lowest-HP unit. Toll of the Dead: whenever one of your units dies and stays dead, Hel heals 2 and the Core takes 2. End of round: gains +1 ATK and raises a Draugr in each empty front slot in lanes 2-3. When Hel falls, her Draugr crumble."},
	"draugr": {"name": "Draugr", "kind": "enemy", "atk": 3, "hp": 6, "spd": 2, "threat": 0, "keywords": [], "text": "Attacks its own lane. Raised by Hel."},
	"apep": {"name": "Apep, the Coiled Chaos", "kind": "boss", "atk": 4, "hp": 40, "spd": 3, "threat": 0, "void_tide": 3, "keywords": ["immovable"], "width": 4, "text": "Immovable. Coils across the whole back row. CONSTRICT: crushes both slots of the lane with the most of your units for 4 (two lanes at half HP or less). Units it kills can't Revive. Devour Light: while Apep lives, Shield blocks no damage to your units, and it is stripped at the end of every round. Void Tide: the Core takes 3 at the end of every round. End of round: a Serpent Brood hatches in an empty front slot. When Apep falls, its Brood die."},
	"serpent_brood": {"name": "Serpent Brood", "kind": "enemy", "atk": 1, "hp": 2, "spd": 5, "threat": 0, "keywords": [], "text": "Attacks its own lane. Hatched by Apep."},
	"thorned_husk": {"name": "Thorned Husk", "kind": "enemy", "atk": 1, "hp": 6, "spd": 1, "threat": 1, "keywords": ["taunt"], "thorns": 1, "text": "Taunt. Thorns 1: melee units that attack it take 1 damage."},
	"carrion_harpy": {"name": "Carrion Harpy", "kind": "enemy", "atk": 2, "hp": 2, "spd": 5, "threat": 1, "keywords": ["airborne"], "text": "Airborne: melee attacks can't target it. Attacks the back unit in its lane first."},
	"veiled_acolyte": {"name": "Veiled Acolyte", "kind": "enemy", "atk": 2, "hp": 4, "spd": 3, "threat": 1, "keywords": ["veil"], "text": "Veil: ignores the first damage it takes each round."},
	"void_ooze": {"name": "Void Ooze", "kind": "enemy", "atk": 2, "hp": 5, "spd": 2, "threat": 1, "keywords": [], "split": "oozeling", "text": "Split: when it dies, two 1/2 Oozelings appear in its slot and the nearest empty slot in its row."},
	"oozeling": {"name": "Oozeling", "kind": "enemy", "atk": 1, "hp": 2, "spd": 2, "threat": 1, "keywords": [], "text": "Attacks its own lane. Split from a Void Ooze."},
	"frenzied_ghoul": {"name": "Frenzied Ghoul", "kind": "enemy", "atk": 2, "hp": 5, "spd": 3, "threat": 2, "keywords": ["frenzy"], "text": "Frenzy: gains +1 ATK each time it takes damage and survives."},
	"plague_bearer": {"name": "Plague Bearer", "kind": "enemy", "atk": 1, "hp": 4, "spd": 2, "threat": 1, "keywords": ["ranged", "poison"], "text": "Ranged. Poison: units it hits take 1 damage at the end of every round until healed."},
	"null_idol": {"name": "Null Idol", "kind": "enemy", "atk": 0, "hp": 6, "spd": 1, "threat": 1, "keywords": ["spellward"], "text": "Spellward: your spells can't target it or the enemies next to it (left, right, in front, behind). Gains Shield 2 whenever you cast a spell. Doesn't attack."},
	"siege_engine": {"name": "Siege Engine", "kind": "enemy", "atk": 6, "hp": 7, "spd": 1, "threat": 2, "keywords": ["immovable"], "text": "Immovable. Odd rounds: LOADING. Even rounds: SIEGE the lane with the most of your units at the moment it fires, dealing its ATK to both of your slots there."},
	"hollow_geomancer": {"name": "Hollow Geomancer", "kind": "enemy", "atk": 1, "hp": 4, "spd": 2, "threat": 1, "keywords": ["ranged"], "text": "Ranged. End of round: turns the slot of your highest-ATK unit (not already on terrain) into Quicksand."},
	"echo_of_hydra": {"name": "Echo of the Hydra", "kind": "elite", "atk": 3, "hp": 10, "spd": 3, "threat": 3, "keywords": [], "split": "hydra_head", "text": "Split: when it dies, two 2/4 Hydra Heads grow in its slot and the nearest empty slot in its row."},
	"hydra_head": {"name": "Hydra Head", "kind": "enemy", "atk": 2, "hp": 4, "spd": 3, "threat": 2, "keywords": [], "text": "Attacks its own lane. Grown from the Hydra."},
	"echo_of_circe": {"name": "Echo of Circe", "kind": "elite", "atk": 2, "hp": 7, "spd": 3, "threat": 3, "keywords": ["ranged"], "text": "Ranged. TRANSFORM: each round, your highest-cost unit becomes a Swine and can't act (no attack or start-of-round effect)."},
}

const RELICS := {
	"ember_of_faith": {"name": "Ember of Faith", "rarity": "Common", "combat": true, "text": "+1 Faith in round 1 of each fight."},
	"wardens_plate": {"name": "Warden's Plate", "rarity": "Common", "combat": true, "text": "Each enemy hit on the Core deals 2 less damage (minimum 1)."},
	"flanking_banner": {"name": "Flanking Banner", "rarity": "Common", "combat": true, "text": "Units in lanes 1 and 4 gain +1 ATK."},
	"mjolnir_shard": {"name": "Mjolnir Shard", "rarity": "Uncommon", "combat": true, "text": "Cleave also hits the unit behind each target."},
	"gjallarhorn": {"name": "Gjallarhorn", "rarity": "Uncommon", "combat": true, "text": "When a unit Reinforces, it gains Shield 4."},
	"laurel_wreath": {"name": "Laurel Wreath", "rarity": "Uncommon", "combat": true, "text": "Rally effects are doubled."},
	"aegis_fragment": {"name": "Aegis Fragment", "rarity": "Uncommon", "combat": true, "text": "The first time each fight a front unit would die, it survives at 1 HP."},
	"eye_of_horus": {"name": "Eye of Horus", "rarity": "Uncommon", "combat": true, "text": "Your Ranged units target the enemy back row first and deal +1 damage to back-row enemies."},
	"valhallas_gate": {"name": "Valhalla's Gate", "rarity": "Rare", "combat": true, "text": "When an ally dies, return its card to your hand (once per card per fight)."},
	"ankh_of_eternity": {"name": "Ankh of Eternity", "rarity": "Rare", "combat": true, "text": "All allies have Revive. Each time an ally Revives, the Core takes 2 damage."},
	"golden_fleece": {"name": "Golden Fleece", "rarity": "Rare", "combat": true, "text": "Fights last 1 extra round."},
	"void_touched_heart": {"name": "Void-Touched Heart", "rarity": "Rare", "combat": true, "text": "+1 Faith every round. The Core takes 3 damage at the start of each fight."},
	"mead_of_the_einherjar": {"name": "Mead of the Einherjar", "rarity": "Uncommon", "combat": true, "text": "The first time an ally dies each fight, all other allies gain +1 ATK."},
	"spartan_standard": {"name": "Spartan Standard", "rarity": "Uncommon", "combat": true, "text": "Start of each round: front-row allies with allies on both sides gain Shield 1."},
	"dragon_prow": {"name": "Dragon Prow", "rarity": "Uncommon", "combat": true, "text": "Units you move gain +2 ATK for the rest of the round."},
	"oracles_tripod": {"name": "Oracle's Tripod", "rarity": "Uncommon", "combat": true, "text": "When you cast your second spell in a round, gain 1 Faith."},
	"sacred_hive": {"name": "Sacred Hive", "rarity": "Uncommon", "combat": true, "text": "Start of each fight: summon two 1/1 Scarabs in your back row."},
	"scarab_amulet": {"name": "Scarab Amulet", "rarity": "Uncommon", "combat": true, "text": "End of each round: heal every ally by 1."},
	"seers_lens": {"name": "Seer's Lens", "rarity": "Common", "combat": false, "pool": false, "text": "At the start of each fight, see enemy intents for rounds 1 and 2."},
	"pilgrims_pouch": {"name": "Pilgrim's Pouch", "rarity": "Common", "combat": false, "text": "+8 gold after each won fight."},
	"healing_ampoule": {"name": "Healing Ampoule", "rarity": "Common", "combat": false, "text": "After each won fight, heal the Core by 3."},
}

const TERRAIN := {
	"ley_line": {"name": "Ley Line", "text": "The unit in this slot has +2 ATK."},
	"ruins": {"name": "Ruins", "text": "Cover: Ranged attacks cannot target the unit in this slot."},
	"quicksand": {"name": "Quicksand", "text": "The unit in this slot can't be moved and has -1 SPD."},
}

const STARTER := ["ark_sentinel", "ark_sentinel", "ark_sentinel", "ark_sentinel", "echo_archer", "echo_archer", "echo_archer", "rebuke", "warding"]

const DECKS := {
	"starter_norse": {"name": "Starter + Shieldmaiden", "extra": ["shieldmaiden"]},
	"starter_greek": {"name": "Starter + Myrmidon", "extra": ["myrmidon"]},
	"starter_egypt": {"name": "Starter + Mummy Guardian", "extra": ["mummy_guardian"]},
	"norse": {"name": "Norse test deck", "extra": ["shieldmaiden", "einherjar", "einherjar", "valkyrie", "thor"]},
	"greek": {"name": "Greek test deck", "extra": ["myrmidon", "hoplite", "hoplite", "athena", "zeus"]},
	"egypt": {"name": "Egyptian test deck", "extra": ["mummy_guardian", "priest_of_ra", "scarab_swarm", "sphinx", "ra"]},
	"sandbox": {"name": "Sandbox: one of every card", "extra": [], "all_cards": true},
}

# Enemy placement: [enemy_id, lane, row]. Terrain: [type, side, lane, row] (side 0 = player).
const BATTLES := [
	{"id": "first_contact", "name": "1. First Contact", "deck": "starter_norse", "core": 50, "relics": [],
		"enemies": [["void_spawn", 0, 0], ["void_spawn", 1, 0]], "terrain": [],
		"blurb": "Learn the flow against two Void Spawn."},
	{"id": "hollow_procession", "name": "2. Hollow Procession", "deck": "greek", "core": 50, "relics": [],
		"enemies": [["hollowed_zealot", 1, 0], ["hollowed_bulwark", 2, 0], ["hollow_archer", 1, 1]],
		"terrain": [["ley_line", 0, 2, 0]],
		"blurb": "Formation play, a Taunt wall, and a Ley Line."},
	{"id": "breach", "name": "3. Breach", "deck": "norse", "core": 50, "relics": [],
		"enemies": [["void_charger", 0, 0], ["void_spawn", 2, 0], ["hollow_archer", 3, 1]],
		"terrain": [["ruins", 0, 1, 1], ["ruins", 1, 3, 1]],
		"blurb": "A Charger with Pierce that charges in even rounds. The archer shelters in Ruins."},
	{"id": "medusa", "name": "4. Echo of Medusa (elite)", "deck": "egypt", "core": 40, "relics": ["eye_of_horus"],
		"enemies": [["hollowed_bulwark", 1, 0], ["void_spawn", 2, 0], ["echo_of_medusa", 1, 1]], "terrain": [],
		"blurb": "Petrify punishes stacking one lane. Includes Eye of Horus."},
	{"id": "herald", "name": "5. Void Herald (boss)", "deck": "norse", "core": 55, "relics": [],
		"enemies": [["void_herald", 1, 0]], "terrain": [], "boss": true, "short": "Herald",
		"hint": "Its Void Tide drains the Core every round and it hammers your strongest lane. Hurts slow, scaling decks.",
		"blurb": "No round limit, but the Void Tide drains the Core. Pick relics in the menu."},
	{"id": "hel", "name": "Boss: Hel, the Hollow Queen", "deck": "egypt", "core": 55, "relics": [],
		"enemies": [["hel", 1, 1], ["draugr", 1, 0], ["draugr", 2, 0]], "terrain": [], "boss": true, "short": "Hel",
		"hint": "Every unit you lose heals her and hurts the Core, and she picks off your weakest unit. Hurts sacrifice and swarm decks; rewards keeping units alive.",
		"blurb": "Every unit you lose heals her and hurts you. Keep your units alive."},
	{"id": "apep", "name": "Boss: Apep, the Coiled Chaos", "deck": "norse", "core": 55, "relics": [],
		"enemies": [["apep", 0, 1], ["serpent_brood", 1, 0], ["serpent_brood", 2, 0]], "terrain": [], "boss": true, "short": "Apep",
		"hint": "Crushes whole lanes, makes Shield useless, and stops Revive. Hurts shield and revive decks; rewards moving units.",
		"blurb": "Shields and Revive fail against Apep. Move out of the constricted lanes."},
	{"id": "swarm", "name": "Extra: The Swarm", "deck": "greek", "core": 50, "relics": [],
		"enemies": [["void_spawn", 0, 0], ["void_spawn", 1, 0], ["void_spawn", 2, 0], ["void_spawn", 3, 0], ["void_wisp", 0, 1], ["void_wisp", 3, 1]],
		"terrain": [], "blurb": "Four Spawn and two Wisps that snipe low-HP units."},
	{"id": "shield_wall", "name": "Extra: Shield Wall", "deck": "egypt", "core": 50, "relics": [],
		"enemies": [["hollowed_bulwark", 1, 0], ["hollowed_bulwark", 2, 0], ["hollow_archer", 1, 1], ["void_wisp", 2, 1]],
		"terrain": [["ruins", 0, 0, 1], ["ruins", 1, 1, 1]], "blurb": "Two Bulwarks protect the ranged backline, and the archer hides in Ruins."},
	{"id": "double_charge", "name": "Extra: Double Charge", "deck": "norse", "core": 50, "relics": [],
		"enemies": [["void_charger", 0, 0], ["hollowed_zealot", 1, 0], ["void_charger", 3, 0]],
		"terrain": [["ley_line", 0, 2, 0]], "blurb": "Two Chargers. Hold your lanes."},
	{"id": "fenrir", "name": "Extra: Echo of Fenrir (elite)", "deck": "greek", "core": 40, "relics": [],
		"enemies": [["void_spawn", 0, 0], ["echo_of_fenrir", 1, 0], ["void_spawn", 3, 0]], "terrain": [],
		"blurb": "Fenrir grows every time one of your units dies."},
	{"id": "set", "name": "Extra: Echo of Set (elite)", "deck": "norse", "core": 40, "relics": [],
		"enemies": [["hollowed_zealot", 0, 0], ["echo_of_set", 2, 0], ["hollow_archer", 3, 1]], "terrain": [],
		"blurb": "Sandstorm weakens a row each round, and Set revives once."},
	{"id": "tangled_ruins", "name": "Extra: Tangled Ruins", "deck": "starter_greek", "core": 50, "relics": [],
		"enemies": [["void_spawn", 0, 0], ["void_spawn", 2, 0], ["void_weaver", 1, 1]], "terrain": [["ruins", 1, 1, 1]],
		"blurb": "A Void Weaver hides in Ruins and clogs your draws with Void Webs."},
	{"id": "hex_coven", "name": "Extra: Hex Coven", "deck": "egypt", "core": 50, "relics": [],
		"enemies": [["hollow_hexer", 0, 0], ["hollowed_bulwark", 1, 0], ["hollow_hexer", 3, 0], ["void_weaver", 2, 1]], "terrain": [],
		"blurb": "Hexers drain your Faith behind a Taunt wall. Kill them fast."},
	{"id": "ashen_tide", "name": "Extra: Ashen Tide", "deck": "norse", "core": 50, "relics": [],
		"enemies": [["ashen_wraith", 0, 0], ["hollowed_zealot", 1, 0], ["ashen_wraith", 3, 0], ["void_weaver", 1, 1]],
		"terrain": [["ley_line", 0, 2, 0]], "blurb": "Wraiths fill your deck with Ashes that burn the Core."},
	{"id": "carrion_flock", "name": "Extra: Carrion Flock", "deck": "starter_norse", "core": 50, "relics": [],
		"enemies": [["carrion_harpy", 0, 0], ["void_spawn", 1, 0], ["carrion_harpy", 3, 0]], "terrain": [],
		"blurb": "Airborne Harpies can only be hit by Ranged units and spells."},
	{"id": "plague_pit", "name": "Extra: Plague Pit", "deck": "egypt", "core": 50, "relics": [],
		"enemies": [["thorned_husk", 1, 0], ["frenzied_ghoul", 2, 0], ["plague_bearer", 1, 1], ["plague_bearer", 2, 1]], "terrain": [],
		"blurb": "Poison needs healing, Thorns punish swarms, and the Ghoul grows if you chip at it."},
	{"id": "sieging_host", "name": "Extra: The Sieging Host", "deck": "norse", "core": 50, "relics": [],
		"enemies": [["hollowed_zealot", 1, 0], ["hollowed_zealot", 2, 0], ["siege_engine", 1, 1]],
		"terrain": [["ley_line", 1, 1, 0]], "blurb": "The Siege Engine loads, then fires at your most crowded lane. Spread out, or break it first."},
	{"id": "ooze_tide", "name": "Extra: Ooze Tide", "deck": "norse", "core": 50, "relics": [],
		"enemies": [["void_ooze", 0, 0], ["veiled_acolyte", 1, 0], ["void_ooze", 3, 0]], "terrain": [],
		"blurb": "Oozes split when killed and Veils blank the first hit. Cleave and big hits shine."},
	{"id": "silent_chapel", "name": "Extra: Silent Chapel", "deck": "greek", "core": 50, "relics": [],
		"enemies": [["veiled_acolyte", 0, 0], ["null_idol", 1, 0], ["void_spawn", 2, 0], ["void_weaver", 1, 1]], "terrain": [],
		"blurb": "The Null Idol wards its neighbours from spells. Break it with units."},
	{"id": "sinking_sands", "name": "Extra: Sinking Sands", "deck": "egypt", "core": 50, "relics": [],
		"enemies": [["void_spawn", 0, 0], ["hollowed_zealot", 2, 0], ["hollow_geomancer", 1, 1], ["carrion_harpy", 3, 0]], "terrain": [],
		"blurb": "The Geomancer sinks your strongest unit into Quicksand each round."},
	{"id": "hydra", "name": "Extra: Echo of the Hydra (elite)", "deck": "norse", "core": 40, "relics": [],
		"enemies": [["void_spawn", 0, 0], ["echo_of_hydra", 1, 0], ["hollow_archer", 3, 1]], "terrain": [],
		"blurb": "Cut off one head and two grow back. Cleave and area damage shine."},
	{"id": "circe", "name": "Extra: Echo of Circe (elite)", "deck": "greek", "core": 40, "relics": [],
		"enemies": [["void_spawn", 0, 0], ["hollowed_zealot", 1, 0], ["void_spawn", 2, 0], ["echo_of_circe", 1, 1]], "terrain": [],
		"blurb": "Circe turns your most expensive unit into a Swine each round. Go wide."},
]


# Run-level balance knobs. scaling_every_floors = 0 turns floor scaling off.
# Each scaling step Empowers empowered_per_step more random enemies per fight (each gains
# empower_atk / empower_hp) and adds scaling_rounds to the round limit.
const BALANCE := {
	"core_hp": 50,
	"win_gold": 15,
	"elite_gold": 30,
	"timeout_gold": 0,
	"rest_heal": 15,
	"shop_heal_amount": 10,
	"shop_heal_price": 40,
	"remove_price": 50,
	"relic_price": 70,
	"scaling_every_floors": 6,
	"empowered_per_step": 1,
	"empower_atk": 2,
	"empower_hp": 6,
	"scaling_rounds": 1,
}

const FACTION_NAMES := {"neutral": "Neutral", "norse": "Norse", "greek": "Greek", "egypt": "Egyptian", "token": "Token", "curse": "Curse", "status": "Status", "divine": "Divine"}
const FACTION_TITLES := {"norse": "The Doomed", "greek": "The Olympians", "egypt": "The Eternal"}

const PATRONS := [
	{"card": "shieldmaiden", "powers": ["tyrs_oath", "thors_thunderclap"], "hp": 55, "label": "Shieldmaiden (Norse)"},
	{"card": "myrmidon", "powers": ["zeus_lightning_bolt", "poseidons_tide"], "hp": 55, "label": "Myrmidon (Greek)"},
	{"card": "mummy_guardian", "powers": ["osiris_return", "sekhmets_plague"], "hp": 55, "label": "Mummy Guardian (Egyptian)"},
]

# God powers: one is chosen at run start and used once per fight during planning, for free,
# then recharges for POWER_COOLDOWN_FLOORS floors.
# "target" uses the spell target values at the top of this file. Powers respect Spellward but
# are not spells (they don't trigger Pythia, Hermes or Oracle's Tripod).
#
# Upgrade trees: two branches of tiers 1-2 plus one Pact node. Drafting cards of the power's
# pantheon earns a pick at each POWER_THRESHOLDS count; a tier-2 node needs its tier-1 node.
# The Pact node needs PACT_CARDS drafted cards from any other pantheon, so new pantheons never
# change a tree. Later acts add thresholds and deeper tiers on top of these nodes.
const POWER_THRESHOLDS := [4, 8, 12]
const PACT_CARDS := 3
# After a fight where the power was used, it sits out the next POWER_COOLDOWN_FLOORS floors.
const POWER_COOLDOWN_FLOORS := 3
const GOD_POWERS := {
	"tyrs_oath": {"name": "Tyr's Oath", "short": "Oath", "god": "Tyr", "pantheon": "norse", "target": "ally",
		"text": "Sacrifice one of your units (On-Death and Revive still trigger). Your other units gain +1 ATK this round.",
		"nodes": {
			"blood_1": {"branch": "Blood", "tier": 1, "name": "Blood Price", "text": "Your other units gain +2 ATK instead of +1."},
			"blood_2": {"branch": "Blood", "tier": 2, "name": "Undying Oath", "text": "The ATK bonus lasts the whole fight."},
			"oath_1": {"branch": "Oath", "tier": 1, "name": "Hand of Tyr", "text": "Heal the Core by the sacrificed unit's HP."},
			"oath_2": {"branch": "Oath", "tier": 2, "name": "Sworn Return", "text": "If the unit stays dead, its card returns to your hand."},
			"pact": {"branch": "Pact", "tier": 1, "name": "Blood Pact", "text": "Also gain 1 Faith."},
		}},
	"thors_thunderclap": {"name": "Thor's Thunderclap", "short": "Thunderclap", "god": "Thor", "pantheon": "norse", "target": "enemy",
		"text": "Deal 3 damage to an enemy.",
		"nodes": {
			"storm_1": {"branch": "Storm", "tier": 1, "name": "Wrath of the Fallen", "text": "+1 damage for each time one of your units fell this fight (up to +3)."},
			"storm_2": {"branch": "Storm", "tier": 2, "name": "Thunder Returns", "text": "If it kills, you can use it again this fight (once)."},
			"hammer_1": {"branch": "Hammer", "tier": 1, "name": "Mjolnir's Arc", "text": "Also hits the other enemy in the target's lane."},
			"hammer_2": {"branch": "Hammer", "tier": 2, "name": "Shockwave", "text": "Also deals 2 damage to the enemies left and right of the target."},
			"pact": {"branch": "Pact", "tier": 1, "name": "Storm Shield", "text": "Your units in the target's lane gain Shield 2."},
		}},
	"zeus_lightning_bolt": {"name": "Zeus's Lightning Bolt", "short": "Lightning Bolt", "god": "Zeus", "pantheon": "greek", "target": "enemy",
		"text": "Deal 2 damage to an enemy, then the bolt chains to one random other enemy for 1.",
		"nodes": {
			"chain_1": {"branch": "Chain", "tier": 1, "name": "Forked Bolt", "text": "Chains to two more enemies."},
			"chain_2": {"branch": "Chain", "tier": 2, "name": "Storm Chain", "text": "Chains deal 2 damage."},
			"sky_1": {"branch": "Sky", "tier": 1, "name": "Thunderhead", "text": "The first hit deals 4."},
			"sky_2": {"branch": "Sky", "tier": 2, "name": "Divine Spark", "text": "Gain 1 Faith for each enemy the bolt kills."},
			"pact": {"branch": "Pact", "tier": 1, "name": "Charged Ranks", "text": "Your Ranged units gain +1 ATK this round."},
		}},
	"poseidons_tide": {"name": "Poseidon's Tide", "short": "Tide", "god": "Poseidon", "pantheon": "greek", "target": "enemy_front",
		"text": "Push an enemy front unit one lane. If it hits a unit or the edge, both take 2. Immovable units are immune.",
		"nodes": {
			"wave_1": {"branch": "Wave", "tier": 1, "name": "Crashing Wave", "text": "Impacts deal 4 instead of 2."},
			"wave_2": {"branch": "Wave", "tier": 2, "name": "Riptide", "text": "The pushed enemy takes the impact damage even when nothing stops it."},
			"undertow_1": {"branch": "Undertow", "tier": 1, "name": "Ambush Current", "text": "Your front unit in the lane where it ends up strikes it for its ATK."},
			"undertow_2": {"branch": "Undertow", "tier": 2, "name": "Flowing Ranks", "text": "Gain 1 extra move this round."},
			"pact": {"branch": "Pact", "tier": 1, "name": "Sea Spray", "text": "Draw a card."},
		}},
	"osiris_return": {"name": "Osiris's Return", "short": "Return", "god": "Osiris", "pantheon": "egypt", "target": "empty_ally_slot",
		"text": "Return the last ally that died this fight to an empty tile with 1 HP.",
		"nodes": {
			"life_1": {"branch": "Life", "tier": 1, "name": "Breath of Life", "text": "It returns at full HP."},
			"life_2": {"branch": "Life", "tier": 2, "name": "Embalmed", "text": "It also gains Shield 3."},
			"wings_1": {"branch": "Wings", "tier": 1, "name": "Risen Fury", "text": "It gains +2 ATK."},
			"wings_2": {"branch": "Wings", "tier": 2, "name": "Undying", "text": "It gains Revive."},
			"pact": {"branch": "Pact", "tier": 1, "name": "Gift of the Nile", "text": "Also heal the Core by 3."},
		}},
	"sekhmets_plague": {"name": "Sekhmet's Plague", "short": "Plague", "god": "Sekhmet", "pantheon": "egypt", "target": "enemy",
		"text": "Poison every enemy in the chosen enemy's lane. Poisoned units take 1 damage at the end of every round until healed.",
		"nodes": {
			"plague_1": {"branch": "Plague", "tier": 1, "name": "Spreading Sickness", "text": "Also poisons the lanes on either side."},
			"plague_2": {"branch": "Plague", "tier": 2, "name": "Virulence", "text": "Poison deals 2 damage to enemies each round."},
			"hunt_1": {"branch": "Hunt", "tier": 1, "name": "Lion's Bite", "text": "Also deal 1 damage to each enemy hit."},
			"hunt_2": {"branch": "Hunt", "tier": 2, "name": "Feast", "text": "Whenever a poisoned enemy dies this fight, heal the Core by 2."},
			"pact": {"branch": "Pact", "tier": 1, "name": "Sun's Mercy", "text": "Also heal each of your units by 1 (curing their Poison)."},
		}},
}

# Which run encounters each battle can appear as.
const BATTLE_POOLS := {
	"first_contact": "early", "hollow_procession": "early", "swarm": "early", "tangled_ruins": "early", "carrion_flock": "early",
	"breach": "late", "shield_wall": "late", "double_charge": "late", "hex_coven": "late", "ashen_tide": "late",
	"plague_pit": "late", "sieging_host": "late", "ooze_tide": "late", "silent_chapel": "late", "sinking_sands": "late",
	"medusa": "elite", "fenrir": "elite", "set": "elite", "hydra": "elite", "circe": "elite",
	"herald": "boss", "hel": "boss", "apep": "boss",
}

# Shrine events. "{pantheon}" is replaced with a random pantheon name.
#
# An option has a "label", an optional up-front "cost" ({"hp", "gold", "max_hp"}; the option is
# disabled if it can't be paid), and either fixed "fx" + "text" or weighted "outcomes"
# ([{"weight", "text", "fx"}], one is rolled). Effects (fx):
#   gold / hp: gain (positive) or lose (negative). Shrine HP loss never drops the Core below 1.
#   max_hp: raise or lower max Core HP.   card: add a random card ("Common", "Uncommon", "Rare", "Divine", "any").
#   curse: add that curse card.   relic: add a random relic (40 gold if none are left).
#   remove: choose a card to remove.   remove_random: remove that many random cards.
#   choose: pick 1 of 3 cards ("pantheon" or a rarity; "Divine" offers 2).   goto: continue to another stage of the event.
# Events with "stages" continue there after a "goto"; each stage has its own "text" and "options".
# An event's "weight" sets how often it's picked (default EVENT_WEIGHT); rare events use less.
const EVENT_WEIGHT := 10
const LEAVE := {"label": "Leave.", "text": "You move on."}
const CANOPIC_JAR := [
	{"weight": 22, "text": "The jar holds a sacred relic, perfectly preserved.", "fx": {"relic": true}},
	{"weight": 28, "text": "The jar is packed with gold funeral offerings.", "fx": {"gold": 45}},
	{"weight": 17, "text": "A papyrus of forgotten power is rolled inside.", "fx": {"card": "Rare"}},
	{"weight": 8, "text": "Wrapped in gold leaf lies the relic of a god older than Egypt itself.", "fx": {"card": "Divine"}},
	{"weight": 25, "text": "A cloud of black dust bursts out. Something was sealed in here for a reason.", "fx": {"hp": -5, "curse": "void_rot"}},
]

const EVENTS := {
	"altar_of_sacrifice": {"name": "Altar of Sacrifice",
		"text": "A blood-stained altar hums with old power. The gods it served still answer offerings.",
		"options": [
			{"label": "Offer your essence: lose 6 Core HP, gain a random rare card.", "cost": {"hp": 6},
				"fx": {"card": "Rare"}, "text": "The altar drinks deeply, and a gift takes shape on the stone."},
			{"label": "Offer your life itself: lose 6 max Core HP, gain a random relic.", "cost": {"max_hp": 6},
				"fx": {"relic": true}, "text": "Something in you goes cold forever. The altar yields a relic."},
			LEAVE]},
	"forgotten_library": {"name": "Forgotten Library",
		"text": "Scrolls from a dead civilization line the shelves. Some hold wisdom, some hold gold leaf.",
		"options": [
			{"label": "Study the scrolls: remove a card from your deck.", "fx": {"remove": true}, "text": "The scrolls teach you what to let go of."},
			{"label": "Strip the gilded covers: gain 25 gold.", "fx": {"gold": 25}, "text": "You peel away the gold leaf."},
			{"label": "Open the sealed black tome: 50% choose 1 of 3 uncommon cards, 50% it curses you.", "outcomes": [
				{"weight": 50, "text": "Its pages hold forgotten tactics.", "fx": {"choose": "Uncommon"}},
				{"weight": 50, "text": "The ink crawls off the page and into your mind.", "fx": {"curse": "void_taint", "hp": -4}}]}]},
	"wandering_echo": {"name": "Wandering Echo",
		"text": "The faded echo of a merchant-god offers a relic from its hoard.",
		"options": [
			{"label": "Pay 30 gold: gain a random relic.", "cost": {"gold": 30}, "fx": {"relic": true}, "text": "The echo bows and hands over its wares."},
			{"label": "Rob it: 50% take a relic for free, 50% it curses you as it fades.", "outcomes": [
				{"weight": 50, "text": "The echo fades before it can react.", "fx": {"relic": true}},
				{"weight": 50, "text": "The echo screams a curse as it fades.", "fx": {"hp": -10, "curse": "void_taint"}}]},
			LEAVE]},
	"void_rift": {"name": "Void Rift",
		"text": "A tear in space leaks Void and treasure alike. You could reach in, if you dare.",
		"options": [
			{"label": "Reach into the rift: lose 4 Core HP and grab whatever you touch.", "cost": {"hp": 4}, "outcomes": [
				{"weight": 50, "text": "Your fingers close on a pile of coins.", "fx": {"gold": 45}},
				{"weight": 25, "text": "You pull out a whole hoard of gold!", "fx": {"gold": 90}},
				{"weight": 25, "text": "Something in the rift grabs back.", "fx": {"hp": -8, "curse": "void_rot"}}]},
			LEAVE]},
	"pantheon_shrine": {"name": "Shrine of the {pantheon}",
		"text": "A shrine to the {pantheon} gods still glows faintly among the ruins.",
		"options": [
			{"label": "Pray: choose 1 of 3 {pantheon} cards.", "fx": {"choose": "pantheon"}, "text": "The {pantheon} gods answer."},
			{"label": "Desecrate it: gain 40 gold, add a Void Taint to your deck.", "fx": {"gold": 40, "curse": "void_taint"},
				"text": "You pry the gold from the altar. The glow dies, and something follows you out."},
			LEAVE]},
	"sacred_spring": {"name": "Sacred Spring",
		"text": "Clear water flows from a ruined temple, surrounded by old offerings. A deeper pool glimmers further in.",
		"options": [
			{"label": "Drink: heal 10 Core HP.", "fx": {"hp": 10}, "text": "The water is cool and clean."},
			{"label": "Collect the offerings: gain 20 gold.", "fx": {"gold": 20}, "text": "The old gods won't miss them."},
			{"label": "Bathe in the deep pool: 60% gain 6 max Core HP, 40% it's tainted.", "outcomes": [
				{"weight": 60, "text": "The water is pure. You feel stronger than before.", "fx": {"max_hp": 6}},
				{"weight": 40, "text": "The depths were not as pure as they looked.", "fx": {"hp": -4, "curse": "void_taint"}}]}]},

	"dice_of_the_norns": {"name": "Dice of the Norns",
		"text": "Three weavers sit at a loom of fate, rolling bone dice. \"Wager with us, little god. Stop whenever you like.\"",
		"options": [
			{"label": "Roll: 65% win 20 gold and keep playing, 35% lose 5 Core HP.", "outcomes": [
				{"weight": 65, "text": "The dice favor you.", "fx": {"gold": 20, "goto": "second"}},
				{"weight": 35, "text": "The dice turn against you. The Norns laugh.", "fx": {"hp": -5}}]},
			LEAVE],
		"stages": {
			"second": {"text": "The Norns smile thinly. \"Again? The stakes rise with every throw.\"",
				"options": [
					{"label": "Roll again: 55% win 35 gold, 45% lose 20 gold and 6 Core HP.", "outcomes": [
						{"weight": 55, "text": "Another winning throw!", "fx": {"gold": 35, "goto": "third"}},
						{"weight": 45, "text": "Your luck runs out.", "fx": {"gold": -20, "hp": -6}}]},
					{"label": "Walk away with your winnings.", "text": "You pocket your gold and leave the Norns to their weaving."}]},
			"third": {"text": "\"One final throw,\" they whisper, \"and your thread is yours to weave.\"",
				"options": [
					{"label": "Final roll: 45% win a relic (or rarely a Divine card) and 30 gold, 55% lose 55 gold and 10 Core HP.", "outcomes": [
						{"weight": 35, "text": "The thread of fate bends to your will!", "fx": {"relic": true, "gold": 30}},
						{"weight": 10, "text": "The Norns fall silent, then bow. They weave you a thread of pure divinity.", "fx": {"card": "Divine", "gold": 30}},
						{"weight": 55, "text": "Your thread frays. The Norns take their due.", "fx": {"gold": -55, "hp": -10}}]},
					{"label": "Walk away with your winnings.", "text": "You quit while you're ahead."}]},
		}},
	"canopic_jars": {"name": "Canopic Jars",
		"text": "Four sealed jars rest in a tomb niche, each capped with a different head. The priests who knew their contents are long gone. You have time to open only one.",
		"options": [
			{"label": "Open the jackal-headed jar.", "outcomes": CANOPIC_JAR},
			{"label": "Open the falcon-headed jar.", "outcomes": CANOPIC_JAR},
			{"label": "Open the baboon-headed jar.", "outcomes": CANOPIC_JAR},
			{"label": "Open the human-headed jar.", "outcomes": CANOPIC_JAR},
			LEAVE]},
	"cursed_idol": {"name": "Cursed Idol",
		"text": "A golden idol of a forgotten god sits on a pedestal, pulsing with Void corruption.",
		"options": [
			{"label": "Take the idol: gain a random relic and a Void Rot.", "fx": {"relic": true, "curse": "void_rot"},
				"text": "The idol is warm in your hands. Too warm."},
			{"label": "Pry out its jewelled eyes: gain 30 gold, 30% chance of a Void Taint.", "outcomes": [
				{"weight": 70, "text": "The jewels come loose cleanly.", "fx": {"gold": 30}},
				{"weight": 30, "text": "The empty sockets glare at you as you leave.", "fx": {"gold": 30, "curse": "void_taint"}}]},
			LEAVE]},
	"hels_bargain": {"name": "Hel's Bargain",
		"text": "Hel, queen of the dead, extends a pale hand. \"Your vitality for my gifts. Or something else you hold dear.\"",
		"options": [
			{"label": "Give your vitality: lose 10 max Core HP, choose 1 of 3 rare cards.", "cost": {"max_hp": 10},
				"fx": {"choose": "Rare"}, "text": "Hel smiles. Her gifts are always generous."},
			{"label": "Give her a random card from your deck: gain 40 gold.", "fx": {"remove_random": 1, "gold": 40},
				"text": "Hel reaches into your deck without looking."},
			{"label": "Refuse.", "text": "\"We will meet again,\" she says. \"Everyone does.\""}]},

	"void_ambush": {"name": "Void Ambush",
		"text": "Void spawn burst from the rubble all around you. There is no avoiding this.",
		"options": [
			{"label": "Fight your way out: lose 8 Core HP.", "fx": {"hp": -8}, "text": "You cut your way free, but not unharmed."},
			{"label": "Throw them your gold: lose 35 gold.", "cost": {"gold": 35}, "text": "The spawn scramble after the coins and you slip away."},
			{"label": "Run for it: 50% escape unharmed, 50% lose 14 Core HP.", "outcomes": [
				{"weight": 50, "text": "You outrun them!", "fx": {}},
				{"weight": 50, "text": "They catch you in a dead end.", "fx": {"hp": -14}}]}]},
	"collapsing_temple": {"name": "Collapsing Temple",
		"text": "The ruined temple groans. Cracks race across the ceiling, and a reliquary glints on the far side of the hall.",
		"options": [
			{"label": "Shield yourself: lose 6 Core HP.", "fx": {"hp": -6}, "text": "Stone rains down around you, but you make it out."},
			{"label": "Dive for the reliquary: 50% gain a relic and lose 6 Core HP, 50% lose 14 Core HP.", "outcomes": [
				{"weight": 50, "text": "You snatch the reliquary as the roof comes down!", "fx": {"relic": true, "hp": -6}},
				{"weight": 50, "text": "The ceiling comes down before you reach it.", "fx": {"hp": -14}}]}]},
	"hall_of_the_forgotten_god": {"name": "Hall of the Forgotten God", "weight": 3,
		"text": "Behind a sealed door lies a shrine to a god no pantheon remembers. Its name is lost, but its power is undiminished.",
		"options": [
			{"label": "Offer your life: lose 8 max Core HP, choose 1 of 2 Divine cards.", "cost": {"max_hp": 8},
				"fx": {"choose": "Divine"}, "text": "The nameless god accepts. Two gifts shimmer on the altar."},
			{"label": "Offer gold: pay 60 gold, gain a random Divine card.", "cost": {"gold": 60},
				"fx": {"card": "Divine"}, "text": "The gold melts into the altar, and a gift rises in its place."},
			LEAVE]},
}


static func deck_cards(deck_key: String) -> Array:
	var deck: Dictionary = DECKS[deck_key]
	if deck.get("all_cards", false):
		var all: Array = []
		for id in CARDS:
			if not CARDS[id].get("token", false):
				all.append(id)
		return all
	return STARTER + deck["extra"]


static func battle(id: String) -> Dictionary:
	for b in BATTLES:
		if b["id"] == id:
			return b
	return {}


## A power's rules text with each owned upgrade appended on its own line.
static func power_text(id: String, nodes: Array) -> String:
	var power: Dictionary = GOD_POWERS[id]
	var text: String = power["text"]
	for n in power["nodes"]:
		if nodes.has(n):
			text += "\n+ %s: %s" % [power["nodes"][n]["name"], power["nodes"][n]["text"]]
	return text


static func patron(card: String) -> Dictionary:
	for p in PATRONS:
		if p["card"] == card:
			return p
	return {}


static func unit_def(id: String) -> Dictionary:
	if CARDS.has(id):
		return CARDS[id]
	return ENEMIES[id]
