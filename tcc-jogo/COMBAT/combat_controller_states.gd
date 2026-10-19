extends Control

## Combat state machine controller. Orchestrates battle phases.
## Rules are in CombatRules. UI is in Combat_UI_states.
## Balloons (HP/Energy following 3D alchemons) are in Hud: CombatBalloons.

@onready var ui: Combat_UI_states = $VBoxContainer
@onready var hud: CombatBalloons = $Hud

@export var database: AlchemonDatabase
@export var player_species_ids: Array[AlchemonInstance] = []
@export var enemy_species_ids: Array[int] = []
@export var enemy_level: int = -1

## BattlefieldSlot -> Node3D. Set by CombatSceneManager BEFORE add_child,
## because _ready() hands it to the balloons.
var anchors: Dictionary = {}

var state: CombatState
var _selection_order: Array[int] = []
var _current_player_index := 0

## Horizontal command bar (top left). Old text UI is pushed below it.
const COMMANDS_AREA_HEIGHT := 130.0
## Set by CombatSceneManager BEFORE add_child (player's bag + item names).
var inventory: InventoryData
var item_database: ItemDatabase
var commands: BattleCommands
var _command_actor_id := -1
var captured_storage: CapturedStorage   # set by CombatSceneManager BEFORE add_child
## BattlefieldSlot -> Node3D of that creature (mesh to highlight when targeted).
## Set by CombatSceneManager BEFORE add_child.
var actor_nodes: Dictionary = {}
var _highlighted: Node3D = null


func _ready() -> void:
	state = CombatStateFactory.build(database, player_species_ids, enemy_species_ids, enemy_level)
	if state.player_ids.is_empty():
		push_error("Time do jogador: time vazio. Confere database e os arrays de species ids.")
		ui.set_turn_text("Erro de configuracao - veja o console.")
		return

	if state.enemy_ids.is_empty():
		push_error("Time do inimigo: time vazio. Confere database e os arrays de species ids.")
		ui.set_turn_text("Erro de configuracao - veja o console.")
		return
		
	CombatRules.roll_initiative(state)
	state.phase = BattlePhaseRules.ENCOUNTER_START
	_log_initiative_order()

	hud.anchors = anchors
	_refresh_hp_display() #tanto o Hp como a Temperatura habitam aqui.
	ui.log_message("Combate comecou!")

	ui.position.y = COMMANDS_AREA_HEIGHT
	commands = BattleCommands.new()                          # 1. create
	add_child(commands)                                      # 2. add to tree
	commands.attack_confirmed.connect(_on_command_attack)    # 3. connect
	commands.item_confirmed.connect(_on_command_item)
	commands.capture_confirmed.connect(_on_command_capture)
	commands.flee_confirmed.connect(_on_flee_pressed)
	commands.target_hovered.connect(_on_target_hovered)

	_start_action_selection()



func _name_of(id: int) -> String:
	var c := state.get_combatant(id)
	return database.get_by_id(c.species_id).creature_name


func _log_initiative_order() -> void:
	var text := ""
	for id in state.turn_order_ids:
		text += "%s (%d)  " % [_name_of(id), state.get_combatant(id).initiative]
	ui.log_message("Ordem de iniciativa: " + text)


func _bond_tag(c: CombatantState) -> String:
	match c.bond_kind:
		BondRules.NONE:
			return "Cagao"
		BondRules.MIXTURE:
			return " [Mistura c/ %s]" % _name_of(c.bond_partner_id)
		BondRules.COMPOUND:
			if c.is_bond_cation:
				return " [Cátion - invisível]"
			elif c.is_bond_inactive:
				return " [Ânion → %s]" % _name_of(c.bond_partner_id)
			else:
				return " [Composto ativo]"
		_:
			return ""


## One display-ready dict per combatant. UI never touches CombatantState.
## Energy = valence electrons (what attacks spend), NOT the action_energy stat.
func _build_entry(id: int) -> Dictionary:
	var c := state.get_combatant(id)
	return {
		"id": id,
		"slot": c.slot,
		"name": _name_of(id) + _bond_tag(c),
		"hp": c.hp, "max_hp": c.max_hp,
		"energy": c.valence_electrons, "max_energy": c.max_valence_electrons,
		"level": c.level, "xp": c.experience, "xp_max": AlchemonGrowth.XP_TO_LEVEL_UP,
		"visible": c.alive and not c.is_bond_cation,
	}


func _refresh_hp_display() -> void:
	var player_entries: Array[Dictionary] = []
	var arena_temperature: float = state.arena_temperature
	for id in state.player_ids:
		var c := state.get_combatant(id)
		player_entries.append(_build_entry(id))
		if arena_temperature > c.temperature:
			state.get_temperature(c.id)

	var enemy_entries: Array[Dictionary] = []
	for id in state.enemy_ids:
		var c := state.get_combatant(id)
		enemy_entries.append(_build_entry(id))
		if arena_temperature > c.temperature:
			state.get_temperature(c.id)

	ui.update_temperature(arena_temperature)
	ui.update_hp_dict(player_entries, enemy_entries)

	var all_entries: Array[Dictionary] = []
	all_entries.append_array(player_entries)
	all_entries.append_array(enemy_entries)
	hud.update_all(all_entries)


func _advance_phase(next_phase: String) -> bool:
	if not BattlePhaseRules.is_valid_transition(state.phase, next_phase):
		push_error("Invalid battle transition: %s -> %s" % [state.phase, next_phase])
		return false
	state.phase = next_phase
	state.battle_phase.transition(next_phase)
	return true


## Opens the SELECTING_ACTIONS window. Both living players AND enemy AI
## choose commands inside this same window - AI commands are queued up
## front so resolution never depends on player pick order. Round only
## advances to RESOLVING_ACTIONS once CombatRules.has_all_commands is true.
func _start_action_selection() -> void:
	if state.combat_over:
		return
	if state.phase == BattlePhaseRules.ENCOUNTER_START:
		_advance_phase(BattlePhaseRules.SELECTING_ACTIONS)
	elif state.phase == BattlePhaseRules.END_OF_ROUND:
		_advance_phase(BattlePhaseRules.SELECTING_ACTIONS)

	state.pending_actions.clear()
	_queue_enemy_commands()

	_selection_order = state.get_active_ids(state.player_ids)
	_current_player_index = 0
	_prompt_action_for_current()


func _prompt_action_for_current() -> void:
	if _current_player_index >= _selection_order.size():
		_try_resolve_round()
		return

	var actor_id := _selection_order[_current_player_index]
	_command_actor_id = actor_id
	ui.clear_options()
	ui.set_turn_text("Acao de %s:" % _name_of(actor_id))
	commands.open_for(
		_name_of(actor_id),
		_build_attack_entries(actor_id),
		_build_item_entries(),
		_build_target_entries(state.get_active_ids(state.enemy_ids)),   # attack targets
		_build_target_entries(state.get_active_ids(state.player_ids)))  # item targets


## Display-ready attacks (max 4). Index = position in template.attacks, which is
## what ActionCommand.attack_index expects.
func _build_attack_entries(actor_id: int) -> Array:
	var template := database.get_by_id(state.get_combatant(actor_id).species_id)
	var entries: Array = []
	for i in mini(template.attacks.size(), 4):
		var a: AttackData = template.attacks[i]
		entries.append({
			"name": a.attack_name,
			"damage": a.power,
			"type": AlchemonType.type_name(a.element_type),
		})
	return entries


## Display-ready usable items: name + effect text.
func _build_item_entries() -> Array:
	var entries: Array = []
	if inventory == null or item_database == null:
		return entries
	for stack in inventory.get_stacked_view(item_database):
		var data := item_database.get_item(stack.index)
		entries.append({
			"index": stack.index,
			"name": "%s x%d" % [stack.nome, stack.quantidade],
			"effect": data.descricao if data != null else "",
			"capture": data != null and data.is_capture_method,
		})
	return entries


## Display-ready targets: id, name, hp, max_hp, creature type.
func _build_target_entries(ids: Array[int]) -> Array:
	var entries: Array = []
	for id in ids:
		var c := state.get_combatant(id)
		var template := database.get_by_id(c.species_id)
		entries.append({
			"id": id,
			"name": _name_of(id),
			"hp": c.hp,
			"max_hp": c.max_hp,
			"type": AlchemonType.type_name(template.element_type),
		})
	return entries


func _on_command_attack(attack_index: int, target_id: int) -> void:
	_confirm_action(_command_actor_id, "attack", target_id, attack_index)

func _on_command_capture(item_index: int, target_id: int) -> void:
	_confirm_action(_command_actor_id, "capture", target_id, -1, item_index)

func _on_command_item(item_index: int, target_id: int) -> void:
	_confirm_action(_command_actor_id, "item", target_id, -1, item_index)


## Highlight the mesh of the creature under the target cursor. -1 = clear.
func _on_target_hovered(target_id: int) -> void:
	TargetHighlight.set_on(_highlighted, false)
	_highlighted = null
	if target_id < 0:
		return
	var c := state.get_combatant(target_id)
	if c == null:
		return
	_highlighted = actor_nodes.get(c.slot)
	TargetHighlight.set_on(_highlighted, true)


func _exit_tree() -> void:
	TargetHighlight.set_on(_highlighted, false)


func _confirm_action(actor_id: int, kind: String, target_id: int, attack_index: int, item_index: int = -1) -> void:
	state.pending_actions.append(ActionCommand.new(actor_id, kind, target_id, attack_index, item_index))
	_current_player_index += 1
	_prompt_action_for_current()


func _queue_enemy_commands() -> void:
	for enemy_id in state.get_active_ids(state.enemy_ids):
		var target_id := CombatRules.pick_random_alive_target_id(state, state.player_ids)
		if target_id == -1:
			continue
		var enemy := state.get_combatant(enemy_id)
		var attack_index := CombatRules.pick_random_attack_index(database, enemy.species_id)
		if attack_index == -1:
			continue
		state.pending_actions.append(ActionCommand.new(enemy_id, "attack", target_id, attack_index))


## Round can only leave SELECTING_ACTIONS once every alive actor (players
## AND AI) has a queued command - see CombatRules.has_all_commands.
func _try_resolve_round() -> void:
	if not CombatRules.has_all_commands(state):
		push_error("Round tentando resolver com comandos faltando.")
		return
	_resolve_round()


func _resolve_round() -> void:
	if not _advance_phase(BattlePhaseRules.RESOLVING_ACTIONS):
		return
	ui.clear_options()
	commands.hide_menu()

	for actor_id in state.turn_order_ids:
		if state.combat_over:
			break

		var actor := state.get_combatant(actor_id)
		if not actor.alive:
			continue

		var command := CombatRules.find_command_for(state, actor_id)
		if command == null:
			continue

		ui.set_turn_text("Turno: %s" % _name_of(actor_id))
		# two actors may queue the same item while the bag has only one
		var uses_bag_item := command.kind == "item" or command.kind == "capture"
		if uses_bag_item and (inventory == null or inventory.get_quantity(command.item_index) <= 0):
			ui.log_message("Sem esse item na mochila! Acao cancelada.")
			await get_tree().create_timer(0.5).timeout
			continue
		var result := CombatRules.resolve_action(state, command, database, item_database)
		if command.kind == "item" and result.outcome == CombatResult.Outcome.ITEM_USED:
			inventory.remove_item(command.item_index)
		if command.kind == "capture" and _capture_was_attempted(result):
			inventory.remove_item(command.item_index)   # spent on success AND fail
		CombatResultApplier.apply(state, result, database)
		_log_event(CombatEvent.from_result(result))
		_refresh_hp_display()

		if not state.combat_over:
			await get_tree().create_timer(0.5).timeout

	if state.combat_over:
		_show_combat_end()
	else:
		_advance_phase(BattlePhaseRules.END_OF_ROUND)
		_start_action_selection()


func _on_flee_pressed() -> void:
	if state.combat_over or state.phase == BattlePhaseRules.RESOLVING_ACTIONS:
		return
	_resolve_flee()

func _resolve_flee() -> void:
	if not _advance_phase(BattlePhaseRules.RESOLVING_ACTIONS):
		return
	ui.clear_options()
	commands.hide_menu()
	ui.set_turn_text("Equipe tenta fugir...")

	var flee_result := CombatRules.resolve_flee()
	CombatResultApplier.apply(state, flee_result, database)
	if flee_result.outcome == CombatResult.Outcome.FLEE_SUCCESS:
		ui.log_message("Fugimos! Escapamos do combate.")
		_sync_party_state()
		CombatSignal.combat_ended.emit()
		queue_free()
		return
	
	ui.log_message("Tentativa de fuga falhou!")

	for enemy_id in state.get_active_ids(state.enemy_ids):
		if state.combat_over:
			break
		var target_id := CombatRules.pick_random_alive_target_id(state, state.player_ids)
		if target_id == -1:
			continue
		var enemy := state.get_combatant(enemy_id)
		var attack_index := CombatRules.pick_random_attack_index(database, enemy.species_id)
		if attack_index == -1:
			continue

		ui.set_turn_text("Turno: %s" % _name_of(enemy_id))
		var command := ActionCommand.new(enemy_id, "attack", target_id, attack_index)
		var result := CombatRules.resolve_action(state, command, database)
		CombatResultApplier.apply(state, result, database)
		_log_event(CombatEvent.from_result(result))
		_refresh_hp_display()
		if state.combat_over:
			break
		await get_tree().create_timer(0.5).timeout

	if state.combat_over:
		_show_combat_end() # already emits combat_ended

	else:
		_advance_phase(BattlePhaseRules.END_OF_ROUND)
		_start_action_selection()

func _capture_was_attempted(result: CombatResult) -> bool:
	return result.outcome == CombatResult.Outcome.CAPTURE_SUCCESS \
		or result.outcome == CombatResult.Outcome.CAPTURE_FAIL


## Copy this battle's captures into the persistent array. Drains, so no double add.
func _sync_captures() -> void:
	if captured_storage != null:
		for species_id in state.captured_species_ids:
			captured_storage.add(species_id)
	state.captured_species_ids.clear()


func _show_combat_end() -> void:
	commands.hide_menu()
	_sync_party_state()
	ui.show_combat_end(state.player_won)
	CombatSignal.combat_ended.emit()
	
	# Give the player time to see the outcome screen before despawning combat
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _log_event(event: CombatEvent) -> void:
	match event.kind:
		CombatEvent.Kind.ATTACK_MISS:
			ui.log_message("%s usa %s em %s... e erra!" % [_name_of(event.actor_id), event.attack_name, _name_of(event.target_id)])
		CombatEvent.Kind.ATTACK_HIT:
			var crit_text := " CRITICO!" if event.critical else ""
			var eff_text := ""
			if event.effectiveness > AlchemonType.NEUTRAL:
				eff_text = " Super efetivo!"
			elif event.effectiveness < AlchemonType.NEUTRAL:
				eff_text = " Nao muito efetivo..."
			ui.log_message("%s usa %s em %s! %d de dano.%s%s" % [_name_of(event.actor_id), event.attack_name, _name_of(event.target_id), event.damage, crit_text, eff_text])
		CombatEvent.Kind.ITEM_USED:
			var effect_text := "Recupera %d HP." % event.amount if event.amount > 0 else "Nada acontece."
			ui.log_message("%s usa um item em %s! %s" % [_name_of(event.actor_id), _name_of(event.target_id), effect_text])
		CombatEvent.Kind.CAPTURE_SUCCESS:
			ui.log_message("%s captura %s! Retirado do combate." % [_name_of(event.actor_id), _name_of(event.target_id)])
		CombatEvent.Kind.CAPTURE_FAIL:
			ui.log_message("Tentativa de capturar %s falhou!" % _name_of(event.target_id))
		CombatEvent.Kind.INVALID_TARGET, CombatEvent.Kind.ALREADY_DEAD, CombatEvent.Kind.INVALID_ACTION:
			ui.log_message("Acao cancelada (%s)." % event.reason)

func _sync_party_state() -> void:
	_sync_captures()
	for i in range(min(player_species_ids.size(), state.player_ids.size())):
		var combatant_id: int = state.player_ids[i]
		var c: CombatantState = state.get_combatant(combatant_id)
		var persistent_alchemon: AlchemonInstance = player_species_ids[i]

		if c != null and persistent_alchemon != null:
			persistent_alchemon.current_hp = maxi(c.hp, 0)
			persistent_alchemon.level = c.level
			persistent_alchemon.defense = c.defense
			persistent_alchemon.mechanical_speed = c.mechanical_speed
			persistent_alchemon.action_energy = c.action_energy
			persistent_alchemon.experience = c.experience
