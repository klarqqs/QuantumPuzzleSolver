# scripts/GroverEngine.gd
# ============================================================
# QUANTUM SIMULATION CORE — QuantumPuzzle Solver
# ============================================================
# Pure GDScript Grover's Algorithm implementation.
# No external libraries required — runs at 60FPS for up to 8 qubits.
#
# MATH OVERVIEW:
#   1. Init: |ψ⟩ = H⊗n|0⟩  — equal superposition, amp = 1/√N
#   2. Oracle: flips phase of marked state: amp[marked] *= -1
#   3. Diffusion: 2|s⟩⟨s| − I  — amplifies marked, suppresses others
#   4. Repeat ceil(π/4 × √N) times for max probability on marked state
# ============================================================

extends Node

signal grover_step_complete(probabilities: Array, iteration: int)
signal simulation_ready(optimal_iterations: int, num_items: int)

# --- Configuration ---
var num_qubits: int = 2          # 2 qubits = 4 items, 4 qubits = 16 items
var marked_idx: int = -1         # Index of the "secret" marked item
var current_iteration: int = 0
var amplitudes: Array = []       # Complex amplitudes as [real, imag] pairs
var is_running: bool = false

# --- Computed ---
var N: int = 0                   # = 2^num_qubits (database size)
var optimal_iterations: int = 0  # = round(π/4 × √N)

# ============================================================
# PUBLIC API
# ============================================================

func initialize(qubits: int, marked: int) -> void:
	num_qubits = clamp(qubits, 1, 8)
	N = 1 << num_qubits           # Bitshift: 2^n
	marked_idx = clamp(marked, 0, N - 1)
	optimal_iterations = max(1, roundi(PI / 4.0 * sqrt(float(N))))
	current_iteration = 0
	is_running = false
	
	_init_superposition()
	simulation_ready.emit(optimal_iterations, N)
	print("GroverEngine: %d qubits, N=%d items, marked=%d, optimal_iters=%d" 
		% [num_qubits, N, marked_idx, optimal_iterations])

func run_one_iteration() -> Array:
	if marked_idx < 0:
		push_error("GroverEngine: marked_idx not set. Call initialize() first.")
		return []
	
	_apply_oracle()
	_apply_diffusion()
	current_iteration += 1
	
	var probs = get_probabilities()
	grover_step_complete.emit(probs, current_iteration)
	return probs

func run_to_optimal() -> Array:
	_init_superposition()
	current_iteration = 0
	for _i in range(optimal_iterations):
		run_one_iteration()
	return get_probabilities()

func get_probabilities() -> Array:
	# Returns array of floats: prob[i] = |amplitude[i]|²
	var probs = []
	probs.resize(N)
	for i in range(N):
		var re = amplitudes[i][0]
		var im = amplitudes[i][1]
		probs[i] = re * re + im * im
	return probs

func reset() -> void:
	_init_superposition()
	current_iteration = 0

func get_state_label(idx: int) -> String:
	# Returns binary label e.g. idx=3, qubits=2 → "|11⟩"
	var bits = ""
	for q in range(num_qubits - 1, -1, -1):
		bits += "1" if (idx >> q) & 1 else "0"
	return "|%s⟩" % bits

# ============================================================
# PRIVATE: QUANTUM OPERATIONS
# ============================================================

func _init_superposition() -> void:
	# H⊗n|0⟩: equal amplitude 1/√N for all states
	amplitudes.clear()
	var amp = 1.0 / sqrt(float(N))
	for i in range(N):
		amplitudes.append([amp, 0.0])   # [real, imaginary]

func _apply_oracle() -> void:
	# Phase oracle: flips sign of marked state
	# O|x⟩ = -|x⟩ if x == marked, else |x⟩
	amplitudes[marked_idx][0] *= -1.0
	amplitudes[marked_idx][1] *= -1.0

func _apply_diffusion() -> void:
	# Grover diffusion operator: D = 2|s⟩⟨s| − I
	# Equivalent to: amp[i] = 2 * mean_amp - amp[i]
	
	# Step 1: Compute mean amplitude (real part only — all amps stay real after H)
	var mean_re: float = 0.0
	var mean_im: float = 0.0
	for i in range(N):
		mean_re += amplitudes[i][0]
		mean_im += amplitudes[i][1]
	mean_re /= float(N)
	mean_im /= float(N)
	
	# Step 2: Reflect each amplitude around the mean
	for i in range(N):
		amplitudes[i][0] = 2.0 * mean_re - amplitudes[i][0]
		amplitudes[i][1] = 2.0 * mean_im - amplitudes[i][1]

# ============================================================
# UTILITY: PROBABILITY ANALYSIS
# ============================================================

func get_max_probability_index() -> int:
	var probs = get_probabilities()
	var max_prob = -1.0
	var max_idx = 0
	for i in range(probs.size()):
		if probs[i] > max_prob:
			max_prob = probs[i]
			max_idx = i
	return max_idx

func get_marked_probability() -> float:
	if marked_idx < 0:
		return 0.0
	var probs = get_probabilities()
	return probs[marked_idx]

func describe_state() -> String:
	var probs = get_probabilities()
	var desc = "Iteration %d | Marked: %s | P(marked)=%.3f\n" % [
		current_iteration,
		get_state_label(marked_idx),
		probs[marked_idx]
	]
	for i in range(N):
		var bar = ""
		var blocks = int(probs[i] * 20)
		for _b in range(blocks):
			bar += "█"
		desc += "  %s: %.3f %s\n" % [get_state_label(i), probs[i], bar]
	return desc
