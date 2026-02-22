// shaders/amplification.gdshader
// ============================================================
// AMPLITUDE AMPLIFICATION SHADER — QuantumPuzzle Solver
// ============================================================
// Applied to the winning cell when Grover's diffusion amplifies
// its probability. Creates an expanding pulse / "quantum burst".
// Swap onto a cell's material when it becomes the likely winner.
// ============================================================

shader_type canvas_item;

uniform float amplitude : hint_range(0.0, 1.0) = 0.0;   // Set from GDScript: the cell's P(state)
uniform float pulse_speed : hint_range(0.5, 5.0) = 2.0;
uniform vec3 win_color : source_color = vec3(0.2, 1.0, 0.5);    // Quantum green
uniform vec3 base_color : source_color = vec3(0.1, 0.1, 0.3);   // Dark background

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);
	
	// Pulsing rings that expand outward — "amplification wave"
	float pulse = sin(TIME * pulse_speed - dist * 12.0) * 0.5 + 0.5;
	
	// Inner core: always bright when amplitude is high
	float core = 1.0 - smoothstep(0.0, 0.3, dist);
	
	// Outer rings: visible only when amplitude > 0.5
	float ring_mask = smoothstep(0.2, 0.5, dist) * (1.0 - smoothstep(0.5, 0.55, dist));
	float rings = ring_mask * pulse * amplitude;
	
	// Combine: core solid glow + pulsing outer rings
	float brightness = (core + rings) * amplitude;
	
	// Color: lerp from base → win based on amplitude
	vec3 final_color = mix(base_color, win_color, amplitude);
	
	// Chromatic aberration at edges for extra quantum flair
	float aberration = smoothstep(0.0, 0.5, dist) * amplitude * 0.3;
	COLOR.r = final_color.r + aberration;
	COLOR.g = final_color.g;
	COLOR.b = final_color.b - aberration;
	COLOR.a = brightness;
}
