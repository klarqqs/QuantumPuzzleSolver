# scripts/PuzzleManager.gd
# ============================================================
# PUZZLE MANAGER — QuantumPuzzle Solver
# ============================================================
# Owns the game loop. Sequences: Superposition → Oracle → Diffusion → Win.
# Drives GroverEngine and signals UIManager for visual feedback.
# ============================================================

extends Node

signal phase_changed(phase: String)        # "superposition" | "oracle" | "diffusion" | "win" | "fail"
signal probabilities_updated(probs: Array)
signal level_started(level_data: Dictionary)
signal score_updated(score: int, combo: int)
signal hint_available(hint_text: String)

# --- Dependencies (set via @onready or inject) ---
@onready var grover_engine: Node = $GroverEngine

# --- Game State ---
enum Phase { SUPERPOSITION, ORACLE_HINT, AWAITING_CLICK, WIN, FAIL }
var current_phase: Phase = Phase.SUPERPOSITION
var current_level: int = 1
var score: int = 0
var combo: int = 0
var marked_idx: int = -1
var num_qubits: int = 2
var player_selected_idx: int = -1
var hints_used: int = 0

# --- Level Definitions ---
# Each level increases qubits (database size) and adds mechanics
const LEVELS = [
	{ "qubits": 2, "items": 4,  "label": "2 Qubits",  "desc": "Find 1 item in 4. Classic Grover!", "iterations": 1 },
	{ "qubits": 3, "items": 8,  "label": "3 Qubits",  "desc": "1 in 8. Superposition deepens.", "iterations": 2 },
	{ "qubits": 4, "items": 16, "label": "4 Qubits",  "desc": "1 in 16. The oracle grows stronger.", "iterations": 3 },
	{ "qubits": 5, "items": 32, "label": "5 Qubits",  "desc": "1 in 32. Only Grover survives.", "iterations": 4 },
]

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	grover_engine.grover_step_complete.connect(_on_grover_step)
	grover_engine.simulation_ready.connect(_on_simulation_ready)
	start_level(1)

func start_level(level: int) -> void:
	current_level = clamp(level, 1, LEVELS.size())
	var data = LEVELS[current_level - 1]
	num_qubits = data["qubits"]
	hints_used = 0
	combo = 0
	
	# Pick a random marked item
	marked_idx = randi() % (1 << num_qubits)
	
	grover_engine.initialize(num_qubits, marked_idx)
	_set_phase(Phase.SUPERPOSITION)
	level_started.emit(data)
	
	print("PuzzleManager: Level %d started. Marked=%d (%s)" % [
		current_level, marked_idx, grover_engine.get_state_label(marked_idx)
	])

func restart_level() -> void:
	start_level(current_level)

func next_level() -> void:
	start_level(current_level + 1)

# ============================================================
# PHASE SEQUENCING
# ============================================================

func begin_oracle_phase() -> void:
	# Triggered by UI "Run Oracle" button or auto-sequence
	if current_phase != Phase.SUPERPOSITION:
		return
	_set_phase(Phase.ORACLE_HINT)
	
	# Run ONE Grover iteration — oracle + diffusion combined
	var probs = grover_engine.run_one_iteration()
	probabilities_updated.emit(probs)
	
	# After a short delay, enter awaiting-click phase
	await get_tree().create_timer(1.2).timeout
	_set_phase(Phase.AWAITING_CLICK)
	
	var marked_prob = grover_engine.get_marked_probability()
	hint_available.emit("The brightest cell is your quantum answer. P(correct) = %.0f%%" % (marked_prob * 100))

func player_click_cell(cell_idx: int) -> void:
	if current_phase != Phase.AWAITING_CLICK:
		return
	
	player_selected_idx = cell_idx
	
	if cell_idx == marked_idx:
		_handle_win()
	else:
		_handle_fail()

func request_hint() -> void:
	# Costs score, runs another Grover iteration for clearer signal
	if current_phase != Phase.AWAITING_CLICK:
		return
	hints_used += 1
	score = max(0, score - 50)
	score_updated.emit(score, combo)
	
	var level_data = LEVELS[current_level - 1]
	var remaining_iters = level_data["iterations"] - grover_engine.current_iteration
	if remaining_iters > 0:
		var probs = grover_engine.run_one_iteration()
		probabilities_updated.emit(probs)
		hint_available.emit("Extra iteration! P(correct) = %.0f%%" % (grover_engine.get_marked_probability() * 100))
	else:
		hint_available.emit("Max iterations reached. Trust the brightest cell! ✨")

# ============================================================
# WIN / FAIL
# ============================================================

func _handle_win() -> void:
	combo += 1
	var base_score = 100 * current_level
	var hint_penalty = hints_used * 25
	var combo_bonus = (combo - 1) * 20
	var earned = max(10, base_score - hint_penalty + combo_bonus)
	score += earned
	
	score_updated.emit(score, combo)
	_set_phase(Phase.WIN)
	print("PuzzleManager: WIN! Score+%d, Combo×%d" % [earned, combo])

func _handle_fail() -> void:
	combo = 0
	score_updated.emit(score, combo)
	_set_phase(Phase.FAIL)
	print("PuzzleManager: FAIL. Clicked %d, marked was %d" % [player_selected_idx, marked_idx])
	
	# Auto-restart after delay
	await get_tree().create_timer(2.0).timeout
	restart_level()

# ============================================================
# SIGNAL HANDLERS
# ============================================================

func _on_grover_step(probs: Array, iteration: int) -> void:
	print("Grover step %d complete. P(marked)=%.3f" % [iteration, probs[marked_idx]])
	# State is logged; UIManager listens to probabilities_updated signal

func _on_simulation_ready(optimal_iters: int, num_items: int) -> void:
	print("Simulation ready: %d items, %d optimal iterations" % [num_items, optimal_iters])

# ============================================================
# HELPERS
# ============================================================

func _set_phase(phase: Phase) -> void:
	current_phase = phase
	var label = ["superposition", "oracle", "awaiting_click", "win", "fail"][phase]
	phase_changed.emit(label)

func get_level_data() -> Dictionary:
	return LEVELS[current_level - 1]

func get_probability_at(idx: int) -> float:
	var probs = grover_engine.get_probabilities()
	if idx >= 0 and idx < probs.size():
		return probs[idx]
	return 0.0

func is_final_level() -> bool:
	return current_level >= LEVELS.size()
