extends PartyMember
class_name Slime

# Variables that need to be saved
export(int, "Red", "Blue", "Yellow") onready var colour
var ability_tiers = []
var favourite : bool = false
var party_slot : int = NONE
var equipped_artifact : Artifact = null

# Variables that can be calculated
var sprite_large : Texture
var sprite_small : Texture
var artifact_boosts : CharacterStats # Can be equipped & unequipped

# Constants
const NONE = -1
enum ABILITIES { RED=0, BLUE, YELLOW }
enum COLOURS { RED=0, BLUE, YELLOW, PURPLE, ORANGE, GREEN }
enum ARTIFACTS { FANG=0, EYE, SCALE }
const artifact_names = [ "Fang", "Eye", "Scale" ]
const NUM_TIERS = 5
var battler_path = "assets/sprites/battlers/"
var battler_ext = ".png"
const growth_curve = preload("res://src/combat/battlers/jobs/SlimeJob.tres")
const skills_all = [preload("res://src/combat/battlers/actions/Flee.tscn")]

func _ready():
	pass

func _init(c):
	update_battler(c)
	_set_experience(1)
	ability_tiers = []
	for a in range(0, ABILITIES.size()):
		if a == colour:
			ability_tiers.append(1)
		else:
			ability_tiers.append(0)
	update_skills()

func get_class():
	return "Slime"

func get_name():
	if not battler or not battler.display_name:
		return Data.generate_slime_name()
	else:
		return battler.display_name

func update_battler(c):
	var old_xp = experience
	colour = c
	var colour_text = Data.COLOURS[colour]
	var new_slime_resource = "res://src/combat/battlers/enemies/AllyTemplate.tscn"
	var my_name = get_name() # save name so we can reassign it
	battler = load(new_slime_resource).instance()
	growth = growth_curve
	pawn_anim_path = "Anim"
	var file_name = "%s_%s" % [colour_text, get_evolution_string()]
	sprite_large = Data.getTexture(battler_path, file_name, battler_ext)
	sprite_small = Data.getTexture(battler_path, file_name + "_128", battler_ext)
	initialize_pm()
	battler.get_node("Skin/AllyAnim/body").texture = sprite_large
	battler.turn_order_icon = sprite_small
	battler._ready()
	battler.initialize()
	battler.display_name = my_name
	if old_xp > 0:
		_set_experience(old_xp)
	visible = true

func update_skills():
	var skill_node = battler.get_node("Actions")
	Util.deleteExtraChildren(skill_node, 1)
	for sk in skills_all: # Skills that everyone has
		var action : CombatAction = sk.instance()
		skill_node.add_child(action)
	# Abilities by tier
	for a in TierAbility.get_abilities(battler):
		var action : TierAbility
		action = load("res://src/combat/battlers/actions/TierAbility.tscn").instance()
		action.init(a)
		#action.init(ABILITIES.RED, a, red_tier) # Set each ability at the strength owned
		skill_node.add_child(action)
	battler.update_actions() # Skills learned by level

func get_colour():
	return Data.COLOURS[colour]
func is_evolved():
	if equipped_artifact:
		return true
	return false
	#return not equipped_artifact == null
func get_evolution_string():
	if is_evolved():
		return "%sMonster" % equipped_artifact.name
	else:
		return "Slime"

func add_to_party(slot : int):
	party_slot = slot
func remove_from_party():
	party_slot = -1
func is_in_party():
	return party_slot >= 0

func get_battler_copy(game):
	# Used for the turn order.  So here is where we add the artifact stats
	var hp = battler.stats.health
	var mp = battler.stats.mana
	var b = clone(game).battler
	b.stats.health = hp
	b.stats.mana = mp
	if is_evolved():
		b.stats.max_health += equipped_artifact.stats.max_health
		b.stats.max_mana += equipped_artifact.stats.max_mana
		b.stats.strength += equipped_artifact.stats.strength
		b.stats.defense += equipped_artifact.stats.defense
		b.stats.speed += equipped_artifact.stats.speed
	return b

func clone(game):
	var st = battler.stats
	var result = get_script().new(colour)#game.create_slime(colour)
	for a in range(0, ABILITIES.size()):
		result.ability_tiers[a] = ability_tiers[a]
	result.battler.display_name = battler.display_name
	result.party_slot = party_slot
	result.equipped_artifact = equipped_artifact
	result.experience = experience
	result.battler.stats = st.duplicate() # before, so it does PM init
	result.update_battler(result.colour)
	result.battler.stats.health = st.health # and after, since that updates stats
	result.battler.stats.mana = st.mana
	result.update_skills()
	result.battler.parent = battler.parent
	#TODO
	#for m in range(0, stats.size()):
	#	merged_boosts[m] += s.stats[m]
	return result

func merge(game, s : Slime, testonly : bool = false):
	# I used to start this function with a clone(), but since battler
	# gets cleared out when the colour changes (we must instance a new
	# e.g. OrangeSlime.tscn), forcing update of all variables kept there,
	# and we have to recalc the abilities and XP and everything anyway,
	# I think it best to just explicitly recalculate absolutely everything
	var result = get_script().new(colour)
	var colours = 0 # If you get to 3, this is invalid
	for a in range(0, ABILITIES.size()):
		result.ability_tiers[a] = ability_tiers[a] + s.ability_tiers[a]
		if result.ability_tiers[a] > 1:
			colours += 1
		if result.ability_tiers[a] > NUM_TIERS: # Anything above max is invalid
			return false
	if colours > 2:
		return false
	# Save artifact, unequip, update battler, and re-equip
	var eq
	if equipped_artifact and not testonly:
		eq = equipped_artifact
		eq.unassign()
	elif s.equipped_artifact and not testonly:
		eq = s.equipped_artifact
		eq.unassign()
	# Battler & re-equip
	result.update_battler(result.get_colour_from_abilities())
	result.battler.display_name = battler.display_name # battler just got cleared
	result.experience = experience + s.experience
	result.battler.stats = growth.create_stats(result.experience)
	if eq:
		eq.assign(result)
	# Place in the party
	var slot = party_slot
	if slot == -1 or (s.party_slot >= 0 and s.party_slot < slot):
		slot = s.party_slot
	result.party_slot = slot
	return result

func ascend(a):
	if not equipped_artifact:
		# Calculate before resetting stats
		equipped_artifact = a
		var max_hp = battler.stats.max_health + equipped_artifact.stats.max_health
		var max_mp = battler.stats.max_mana + equipped_artifact.stats.max_mana
		var hp_ratio : float = battler.stats.health / battler.stats.max_health
		var mp_ratio : float = battler.stats.mana / battler.stats.max_mana
		# Reset from base & then fix
		update_battler(colour)
		battler.stats.max_health = max_hp
		battler.stats.max_mana = max_mp
		battler.stats.health = hp_ratio * max_hp
		battler.stats.mana = mp_ratio * max_mp
func descend():
	if equipped_artifact:
		var b = battler.stats #temp for debugging
		# Calculate before resetting stats
		var max_hp = battler.stats.max_health - equipped_artifact.stats.max_health
		var max_mp = battler.stats.max_mana - equipped_artifact.stats.max_mana
		var hp = battler.stats.health / battler.stats.max_health
		var mp = battler.stats.mana / battler.stats.max_mana
		equipped_artifact = null
		# Reset from base & then fix
		update_battler(colour)
		battler.stats.max_health = max_hp
		battler.stats.max_mana = max_mp
		hp *= battler.stats.max_health
		mp *= battler.stats.max_mana
		battler.stats.health = round(max(hp, 1))
		battler.stats.mana = round(max(mp, 0))

func get_battle_anim():
	var colour_text = Data.COLOURS[colour]
	var new_anim_resource = "res://src/combat/animation/%s%sAnim.tscn" % [colour_text, get_evolution_string()]
	return load(new_anim_resource).instance()

func is_primary():
	# a primary has exactly one ability at 1 and both others at 0
	var s_total = 0
	#print("Abilities is size %s" %[ABILITIES.size()])
	for a in range(0, ABILITIES.size()):
		s_total += ability_tiers[a]
	return s_total == 1

func get_tier_shorthand():
	var tiers = []
	for a in range(0, ABILITIES.size()):
		for t in ability_tiers[a]:
			tiers.append(a)
	# It will look something like 0 0 0 2 (three reds, one yellow)
	return tiers
	
func get_colour_from_abilities():
	var colours_as_strings = [ "100", "010", "001", "110", "101", "011" ]
	var my_colour_as_string = ""
	for a in ability_tiers:
		#colours.append(a > 0)
		my_colour_as_string += str(int(a > 0))
	for s in range(0, colours_as_strings.size()):
		if my_colour_as_string == colours_as_strings[s]:
			return s
	return -1
	
