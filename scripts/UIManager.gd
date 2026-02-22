# scripts/UIManager.gd
# ============================================================
# UI MANAGER — QuantumPuzzle Solver
# ============================================================
# Drives ALL visual feedback: glow intensity, pulse animations,
# shader parameters, labels, phase banners, score display.
# Listens to PuzzleManager signals — zero game logic here.
# ============================================================

extends CanvasLayer

# --- Node References (link in scene inspector) ---
@onready var grid_container: GridContainer = $GridContainer
@onready var phase_banner: Label = $PhaseBanner
@onready var score_label: Label = $HUD/ScoreLabel
@onready var combo_label: Label = $HUD/ComboLabel
@onready var level_label: Label = $HUD/LevelLabel
@onready var hint_label: Label = $HintLabel
@onready var oracle_btn: Button = $Controls/OracleButton
@onready var hint_btn: Button = $Controls/HintButton
@onready var restart_btn: Button = $Controls/RestartButton

# --- Dependencies ---
@onready var puzzle_manager: Node = $"../PuzzleManager"

# --- Cell tracking ---
var cells: Array = []
var current_probs: Array = []
var num_cells: int = 4    # Updated per level

# --- Visual constants ---
const COLOR_SUPERPOSITION := Color(0.3, 0.5, 1.0, 0.4)    # Cool blue glow
const COLOR_ORACLE        := Color(0.8, 0.2, 1.0, 0.6)    # Purple oracle hint
const COLOR_AMPLIFIED     := Color(0.2, 1.0, 0.5, 1.0)    # Bright green winner
const COLOR_DIM           := Color(0.1, 0.1, 0.3, 0.2)    # Dark suppressed
const COLOR_WIN           := Color(1.0, 0.9, 0.2, 1.0)    # Gold win flash
const COLOR_FAIL          := Color(1.0, 0.2, 0.2, 0.8)    # Red fail flash

# ============================================================
# SETUP
# ============================================================

func _ready() -> void:
	# Connect PuzzleManager signals
	puzzle_manager.phase_changed.connect(_on_phase_changed)
	puzzle_manager.probabilities_updated.connect(_on_probabilities_updated)
	puzzle_manager.level_started.connect(_on_level_started)
	puzzle_manager.score_updated.connect(_on_score_updated)
	puzzle_manager.hint_available.connect(_on_hint_available)
	
	# Connect button presses
	oracle_btn.pressed.connect(puzzle_manager.begin_oracle_phase)
	hint_btn.pressed.connect(puzzle_manager.request_hint)
	restart_btn.pressed.connect(puzzle_manager.restart_level)

func build_grid(cell_count: int) -> void:
	# Clear existing cells
	for child in grid_container.get_children():
		child.queue_free()
	cells.clear()
	num_cells = cell_count
	
	# Determine grid columns
	var cols = int(sqrt(float(cell_count)))
	grid_container.columns = cols
	
	# Spawn cells
	for i in range(cell_count):
		var cell = _create_cell(i)
		grid_container.add_child(cell)
		cells.append(cell)
	
	_apply_superposition_visuals()

func _create_cell(idx: int) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(80, 80)
	panel.name = "Cell_%d" % idx
	
	# Create shader material for glow
	var mat = ShaderMaterial.new()
	# Note: In production, load from res://shaders/superposition.gdshader
	# mat.shader = preload("res://shaders/superposition.gdshader")
	# panel.material = mat
	
	# Label showing state |00⟩, |01⟩ etc
	var lbl = Label.new()
	lbl.text = _get_state_label(idx)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(lbl)
	
	# Probability bar (visual only)
	var prob_bar = ColorRect.new()
	prob_bar.name = "ProbBar"
	prob_bar.color = COLOR_SUPERPOSITION
	prob_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(prob_bar)
	prob_bar.move_to_front()
	lbl.move_to_front()
	
	# Click handler
	var btn = Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(func(): puzzle_manager.player_click_cell(idx))
	panel.add_child(btn)
	btn.move_to_front()
	
	return panel

# ============================================================
# VISUAL PHASE STATES
# ============================================================

func _apply_superposition_visuals() -> void:
	for i in range(cells.size()):
		_set_cell_color(i, COLOR_SUPERPOSITION)
		_animate_pulse(i, 0.3, 0.5, 2.0 + i * 0.1)  # Staggered breathing

func _apply_oracle_visuals() -> void:
	# All cells dim slightly — oracle is working...
	for i in range(cells.size()):
		_set_cell_color(i, COLOR_DIM)
	
	phase_banner.text = "⚛ Oracle marking target..."
	phase_banner.modulate = COLOR_ORACLE

func _apply_diffusion_visuals(probs: Array) -> void:
	# Cells glow proportional to their probability
	for i in range(min(cells.size(), probs.size())):
		var p = probs[i]
		var col = COLOR_DIM.lerp(COLOR_AMPLIFIED, p)
		col.a = 0.2 + p * 0.8
		_set_cell_color(i, col)
		
		# Pulse the high-probability cells
		if p > 0.5:
			_animate_pulse(i, 0.8, 1.0, 0.6)
		
	phase_banner.text = "✨ Amplitude amplified! Click the brightest cell."
	phase_banner.modulate = COLOR_AMPLIFIED

func _apply_win_visuals(winning_idx: int) -> void:
	for i in range(cells.size()):
		if i == winning_idx:
			_flash_cell(i, COLOR_WIN)
		else:
			_set_cell_color(i, COLOR_DIM)
	
	phase_banner.text = "🎉 QUANTUM WIN! You found the marked state!"
	phase_banner.modulate = COLOR_WIN
	_shake_label(phase_banner)

func _apply_fail_visuals(clicked_idx: int) -> void:
	_flash_cell(clicked_idx, COLOR_FAIL)
	phase_banner.text = "❌ Wrong state! Grover tried to help... try again."
	phase_banner.modulate = COLOR_FAIL

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_phase_changed(phase: String) -> void:
	match phase:
		"superposition":
			_apply_superposition_visuals()
			oracle_btn.disabled = false
			hint_btn.disabled = true
			phase_banner.text = "🌊 Superposition: All states equally probable"
			phase_banner.modulate = COLOR_SUPERPOSITION
		"oracle":
			_apply_oracle_visuals()
			oracle_btn.disabled = true
			hint_btn.disabled = true
		"awaiting_click":
			hint_btn.disabled = false
			# Diffusion visuals already applied via probabilities_updated
		"win":
			_apply_win_visuals(puzzle_manager.player_selected_idx)
			oracle_btn.disabled = true
			hint_btn.disabled = true
		"fail":
			_apply_fail_visuals(puzzle_manager.player_selected_idx)
			oracle_btn.disabled = true
			hint_btn.disabled = true

func _on_probabilities_updated(probs: Array) -> void:
	current_probs = probs
	_apply_diffusion_visuals(probs)

func _on_level_started(data: Dictionary) -> void:
	var cell_count = data["items"]
	build_grid(cell_count)
	level_label.text = "Level %d — %s" % [puzzle_manager.current_level, data["label"]]
	hint_label.text = data["desc"]
	score_label.text = "Score: %d" % puzzle_manager.score
	combo_label.text = ""
	oracle_btn.disabled = false
	hint_btn.disabled = true

func _on_score_updated(score: int, combo: int) -> void:
	score_label.text = "Score: %d" % score
	if combo > 1:
		combo_label.text = "🔥 ×%d COMBO!" % combo
		combo_label.modulate = COLOR_WIN
	else:
		combo_label.text = ""

func _on_hint_available(hint_text: String) -> void:
	hint_label.text = "💡 " + hint_text
	hint_label.modulate = Color(1.0, 1.0, 0.5, 1.0)

# ============================================================
# ANIMATION HELPERS
# ============================================================

func _set_cell_color(idx: int, color: Color) -> void:
	if idx >= cells.size():
		return
	var bar = cells[idx].get_node_or_null("ProbBar")
	if bar:
		bar.color = color

func _animate_pulse(idx: int, min_alpha: float, max_alpha: float, duration: float) -> void:
	if idx >= cells.size():
		return
	var bar = cells[idx].get_node_or_null("ProbBar")
	if not bar:
		return
	var tween = create_tween().set_loops()
	tween.tween_property(bar, "modulate:a", max_alpha, duration * 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(bar, "modulate:a", min_alpha, duration * 0.5).set_ease(Tween.EASE_IN_OUT)

func _flash_cell(idx: int, color: Color) -> void:
	if idx >= cells.size():
		return
	var bar = cells[idx].get_node_or_null("ProbBar")
	if not bar:
		return
	bar.color = color
	var tween = create_tween()
	tween.tween_property(bar, "modulate:a", 1.0, 0.1)
	tween.tween_property(bar, "modulate:a", 0.3, 0.15)
	tween.tween_property(bar, "modulate:a", 1.0, 0.1)
	tween.tween_property(bar, "modulate:a", 0.3, 0.15)
	tween.tween_property(bar, "modulate:a", 1.0, 0.2)

func _shake_label(label: Label) -> void:
	var origin = label.position
	var tween = create_tween()
	for _i in range(6):
		tween.tween_property(label, "position", origin + Vector2(randf_range(-5, 5), randf_range(-3, 3)), 0.05)
	tween.tween_property(label, "position", origin, 0.05)

# ============================================================
# UTILITY
# ============================================================

func _get_state_label(idx: int) -> String:
	# Returns "|00⟩" style labels
	if puzzle_manager and puzzle_manager.grover_engine:
		return puzzle_manager.grover_engine.get_state_label(idx)
	return "|%d⟩" % idx
