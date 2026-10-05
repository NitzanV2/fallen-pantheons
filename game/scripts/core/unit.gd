extends RefCounted
## Runtime state of one unit on the battlefield (player or enemy).

const Data = preload("res://scripts/core/data.gd")

var uid: int
var id: String
var def: Dictionary
var side: int
var lane: int
var row: int
var atk: int
var max_hp: int
var hp: int
var spd: int
var threat: int
var shield := 0
var alive := true
var revive_used := false
var is_token := false
var wide := false
var width := 1
var empowered := false
var card = null
var temp_atk := 0
var moved_round := 0
var deployed_round := 0
## True when it entered the board from your hand (not summoned or returned by an effect).
var from_hand := false
var veil_round := 0
var attacked_round := 0
var poisoned := false
## Keywords granted during the fight, on top of the card's own.
var bonus_kw: Array = []
## Armament cards attached to this unit (card dictionaries).
var armaments: Array = []


func setup(p_uid: int, p_id: String, p_def: Dictionary, p_side: int) -> void:
	uid = p_uid
	id = p_id
	def = p_def
	side = p_side
	atk = def["atk"]
	max_hp = def["hp"]
	hp = max_hp
	spd = def["spd"]
	threat = def.get("threat", 0)
	is_token = def.get("token", false)
	width = def.get("width", 1)
	wide = width > 1


func copy():
	var u = get_script().new()
	for prop in ["uid", "id", "def", "side", "lane", "row", "atk", "max_hp", "hp", "spd", "threat",
			"shield", "alive", "revive_used", "is_token", "wide", "width", "empowered", "card", "temp_atk", "moved_round", "deployed_round",
			"veil_round", "poisoned", "attacked_round", "from_hand"]:
		u.set(prop, get(prop))
	u.bonus_kw = bonus_kw.duplicate()
	u.armaments = armaments.duplicate()
	return u


func has_kw(keyword: String) -> bool:
	if keyword in def.get("keywords", []) or keyword in bonus_kw:
		return true
	for card in armaments:
		if keyword in Data.CARDS[card["id"]]["arm"].get("kw", []):
			return true
	return false


func display_name() -> String:
	return def["name"]
