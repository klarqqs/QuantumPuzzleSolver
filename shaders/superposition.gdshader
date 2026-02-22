// shaders/superposition.gdshader
// ============================================================
// SUPERPOSITION SHADER — QuantumPuzzle Solver
// ============================================================
// Creates the "quantum wave" visual: rippling interference pattern
// that represents equal probability superposition.
// Apply to each cell's ShaderMaterial in the qubit grid.
// ============================================================

shader_type canvas_item;

// --- Uniforms exposed to GDScript ---
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float time_scale : hint_range(0.1, 5.0) = 1.5;
uniform float wave_frequency : hint_range(1.0, 20.0) = 8.0;
uniform vec3 base_color : source_color = vec3(0.3, 0.5, 1.0);   // Quantum blue
uniform float cell_idx : hint_range(0.0, 32.0) = 0.0;           // Phase offset per cell

void fragment() {
	vec2 uv = UV - 0.5;                        // Center UV: -0.5 to 0.5
	float dist = length(uv);                    // Radial distance from center
	
	// Wave interference: concentric rings emanating from center
	float wave1 = sin(TIME * time_scale + dist * wave_frequency + cell_idx * 0.7) * 0.5 + 0.5;
	float wave2 = sin(TIME * time_scale * 0.6 + dist * wave_frequency * 1.3 - cell_idx * 0.4) * 0.5 + 0.5;
	
	// Interference pattern (multiply waves)
	float interference = (wave1 * 0.6 + wave2 * 0.4);
	
	// Radial fade — brighter at center
	float radial = 1.0 - smoothstep(0.0, 0.5, dist);
	
	// Final color
	float final_brightness = interference * radial * intensity;
	COLOR.rgb = base_color * final_brightness;
	COLOR.a = final_brightness * 0.85;
}
