extends CanvasLayer

class_name MonsterCollection

signal monster_collection_menu_summoned()
signal toggle_encounters()
const NONE = -1

var slimes = [] # Enhanced & Primaries
var greys = [0, 0, 0] # Number owned of each grey difficulty
var allowed_greys = range(0, 3)
var curr_selection_1ST = NONE # Some actions require 2 choices, e.g. merging
var curr_selection_2ND = NONE
var prev_result = NONE

onready var grpParty = $Background/Columns/Col1/Party
onready var grpCollection = $Background/Columns/Col2/Collection
onready var grpArtifacts = $Background/Columns/Col1/Artifacts
onready var grpActions = $Background/Columns/Actions
onready var grpGreys = $Background/Columns/Col3/Greys
onready var grpPrimaries = $Background/Columns/Col3/Primaries/PrimHeadings
onready var grpReds = $Background/Columns/Col3/Primaries/PrimCols/Reds
onready var grpBlues = $Background/Columns/Col3/Primaries/PrimCols/Blues
onready var grpYellows = $Background/Columns/Col3/Primaries/PrimCols/Yellows
var selected = Data.getTexture("assets/theme/button/", "selected", ".png")
var game

# Array interface functions
func add_slime(new_slime: Slime) -> void:
	slimes.resize(slimes.size() + 1)
	slimes[slimes.size() - 1] = new_slime
func remove_slime(target_pos: int) -> Slime:
	var rv = slimes[target_pos]
	slimes.remove(target_pos)
	return rv
func get_slime(target_pos: int) -> Slime:
	var rv = slimes[target_pos]
	return rv
func add_grey(g: int) -> void:
	assert(g in allowed_greys)
	greys[g] += 1
func remove_grey(g: int) -> void:
	assert(g in allowed_greys)
	assert(greys[g] >= 1)
	greys[g] -= 1
func get_primary_list(colour : int):
	return get_slimes_filtered(false, false, colour)
func get_enhanced_list():
	return get_slimes_filtered(false, true, -1)
func get_party_list():
	return get_slimes_filtered(true, true, -1)

func get_slimes_filtered(wants_party : bool, wants_enhanced : bool, wants_colour : int):
	var arr = []
	for s in slimes:
		if wants_party and s.is_in_party():
			arr.append(s) # We don't care in this case if primary or not
		elif not s.is_in_party():
			if wants_enhanced != s.is_primary() and wants_colour in [s.colour, -1]:
				arr.append(s)
	return arr

# Main functions
func _ready():
	 game = Util.getParent(self, "Game")

func _process(_delta):
	if(Input.is_action_just_released("ui_select")):
		emit_signal("monster_collection_menu_summoned")
	if(Input.is_action_just_released("ui_toggle_encs")):
		emit_signal("toggle_encounters")

const ARTIFACTS = [ "Fang", "Eye", "Scale" ]
var artifact_path = "assets/sprites/artifacts/"
var artifact_ext = "_128.png"

func reset():
	curr_selection_1ST = NONE
	curr_selection_2ND = NONE
	# FOR TESTING!
	#add_slime(game.create_slime(0))
	#add_slime(game.create_slime(0))
	#add_slime(game.create_slime(1))
	reload()

func reload():
	grpActions.get_node("AscendButton").visible = checkAscendPossible()
	grpActions.get_node("AscendLabel").visible = checkAscendPossible()
	grpActions.get_node("MergeButton").visible = checkMergePossible()
	grpActions.get_node("MergeLabel").visible = checkMergePossible()
	# Party
	Util.deleteExtraChildren(grpParty, 3)
	var party = get_party_list()
	for i in range(0, min(party.size(), game.party.PARTY_SIZE)):
		var t = grpParty.get_node("PartyMember/PartyContainer").duplicate()
		var s = party[i]
		#print(s.name)
		#t.add_child(s, true)
		t.get_child(0).texture = s.sprite_small
		var stats = t.get_child(1)
		labelCell(stats, 0, s.get_name())
		labelCell(stats, 1, "Level: " + str(s.stats.level))
		labelCell(stats, 2, "Strength: " + str(s.stats.strength))
		var abilities = t.get_node("Abilities")
		for a in range(0, s.ABILITIES.size()):
			for tier in range(0, 4): #FIXME use a constant
				var icon_name = "none"
				if s.ability_tiers[a] > tier:
					icon_name = "Track%sTier%s" % [a, tier]
				icon_name += "_Tiny"
				var ab_icon = Data.getTexture("assets/sprites/abilities", icon_name, ".png")
				var ab_node = TextureRect.new()
				ab_node.set_texture(ab_icon)
				ab_node.set_size(Vector2(32,32))
				ab_node.visible = true
				abilities.add_child(ab_node)
		t.get_node("Icons/FavFavourite").visible = s.favourite
		t.get_node("Icons/FavNormal").visible = !s.favourite
		t.visible = true
		grpParty.add_child(t)
	#FIXME Why doesn't this work?
	#grpParty.get_node("AddPartyMember").visible = game.party.get_size() < game.party.PARTY_SIZE
	# Artifacts
	Util.deleteExtraChildren(grpArtifacts, 3)
	for i in range(0, 3):
		if Data.hasArtifact(i):
			var t = grpArtifacts.get_node("ArtifactMember/ArtifactContainer").duplicate()
			t.get_child(0).texture = Data.getTexture(artifact_path, ARTIFACTS[i], artifact_ext)
			labelCell(t, 1, ARTIFACTS[i])
			t.visible = true
			grpArtifacts.add_child(t)
	# Collection (enhanced)
	Util.deleteExtraChildren(grpCollection, 3)
#	var coll = get_enhanced_list()
#	for s in range(0, coll.size()):
#		var t = grpCollection.get_node("CollMember/CollContainer").duplicate()
#		var name = s.display_name
#		var img_file = s.sprite#"Red" + "_Slime_128"#FLAVOURS[i]
#		t.get_child(TEMPLATE.IMG).texture = Data.getTexture(battler_path, img_file, battler_ext)
#		labelCell(t, TEMPLATE.NAME, name)
#		t.visible = true
#		grpCollection.add_child(t)
	# Primaries
	var grps = [ grpReds, grpBlues, grpYellows ]
	for g in range(0, grps.size()):
		if Data.hasSlime(g):
			grpPrimaries.get_child(g).modulate = Color(1,1,1,1)
		else:
			grpPrimaries.get_child(g).modulate = Color(1,1,1,0.125)
		var list = grps[g]#.get_node("List")
		Util.deleteExtraChildren(list, 1)
		for s in get_primary_list(g):
			var b = list.get_node("Button").duplicate()
			handleButton(b, s)
			var m = b.get_node("Member")
			labelCell(m, 0, s.get_name().substr(0, 8))
			labelCell(m, 1, s.current_xp)
			m.get_node("FavFavourite").visible = s.favourite
			m.get_node("FavNormal").visible = !s.favourite
			b.visible = true
			list.add_child(b)
	# Greys
	var greyCont = grpGreys.get_node("GreyMember/GreyContainer")
	greyCont.get_node("ValGreySolo").text = str(greys[0])
	greyCont.get_node("ValGreyDuo").text = str(greys[1])
	greyCont.get_node("ValGreyTrio").text = str(greys[2])

func labelCell(t, posn, data):
	var lbl : Label = t.get_child(posn)
	lbl.text = str(data)

func handleButton(button, slime):
	# Every button's first child is a label with instance ID of corresponding slime
	labelCell(button, 0, slime.get_instance_id())
	# If this slime is selected, the button should reflect that
	var sel = slime.get_instance_id() in [curr_selection_1ST, curr_selection_2ND]
	button.texture_pressed = selected
	button.toggle_mode = sel
	button.pressed = sel

func clickButton(button):
	var inst = int(button.get_node("InstanceID").text)
	if curr_selection_1ST == NONE:
		curr_selection_1ST = inst
	elif curr_selection_2ND == NONE:
		curr_selection_2ND = inst
	else:
		curr_selection_2ND = curr_selection_1ST
		curr_selection_1ST = inst
	reload()

func ascend(i):
	Data.setSlime(i, false)
	Data.setArtifact(i, false)
	Data.setMonster(i, true)

func checkAscendPossible():
	return curr_selection_1ST != NONE
	#var poss = false
	#for i in range(0, 3):
	#	if Data.hasSlime(i) and Data.hasArtifact(i) and not Data.hasMonster(i):
	#		poss = true
	#return poss
func checkMergePossible():
	return curr_selection_1ST != NONE
	#return (Data.hasSlime(0) or Data.hasMonster(0)) and slimes.size() > 0

func _on_AscendButton_button_down():
	for i in range(0, 3):
		if Data.hasSlime(i) and Data.hasArtifact(i) and not Data.hasMonster(i):
			ascend(i)
			reload()
			break

func merge():
	if checkMergePossible():
		# first collection item
		var m : Slime = slimes.pop_front()
		# merges into appropriate party member
		var game = Util.getParent(self, "Game")
		var member = game.party.get_party_member(0)
		member.stats.level += 1
		reload()

func _on_MergeButton_button_down():
	merge()
