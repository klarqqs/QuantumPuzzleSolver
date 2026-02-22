# Grover's Algorithm — Educator's Guide
### QuantumPuzzle Solver | `docs/grover_math.md`

---

## What is Grover's Algorithm?

Grover's algorithm (1996) is a quantum search algorithm that finds a marked item in an **unstructured database of N items** using only **O(√N) queries** — compared to classical O(N).

For N=16 items (4 qubits): classical needs ~8 guesses on average. Grover needs ~3. For N=1,000,000: classical needs ~500,000. Grover needs ~785. **That's a quadratic speedup.**

---

## The Game ↔ Math Mapping

| What students see | What it means mathematically |
|---|---|
| All cells glow equally | **Superposition**: ψ = (1/√N) Σ\|x⟩, all amplitudes equal |
| "Oracle marks the target" | **Phase kickback**: O\|x⟩ = −\|x⟩ if x = marked, else \|x⟩ |
| Other cells dim | **After oracle**: marked state has negative amplitude |
| One cell pulses bright | **Diffusion**: amplitudes reflected about their mean |
| Click the brightest cell | **Measurement**: collapse wavefunction to most probable state |

---

## The Math (Step by Step)

### 1. Initialization
Apply Hadamard to all qubits:

```
H⊗n|0...0⟩ = (1/√N) Σ_{x=0}^{N-1} |x⟩
```

Every state has amplitude `a = 1/√N`. The database is "loaded" in superposition.

### 2. Oracle (Phase Flip)
The oracle marks the target by flipping its amplitude sign:

```
O|x⟩ = { -|x⟩  if x = marked
         {  |x⟩  otherwise
```

After this, the marked state has amplitude `−1/√N`, others `+1/√N`. The mean amplitude shifts slightly negative.

### 3. Diffusion (Inversion About Mean)
The Grover diffusion operator reflects ALL amplitudes about their mean:

```
D = 2|s⟩⟨s| − I     where |s⟩ = H⊗n|0⟩
```

This is equivalent to: `a_new[i] = 2·mean(a) − a[i]`

**Why this amplifies the marked state:**
- Mean amplitude after oracle ≈ slightly below `1/√N`
- Non-marked amplitudes: close to mean → barely changed
- Marked amplitude: far below mean (it's negative) → reflected to far **above** mean

After one iteration, marked amplitude ≈ `(3/√N)`. Others ≈ `(1/√N) × (N-1)/N`.

### 4. Repeat
Each iteration amplifies the marked state further. After `k` iterations:

```
P(marked) = sin²((2k+1)θ/2)     where θ = 2·arcsin(1/√N)
```

This peaks at k* = **floor(π/4 × √N)** iterations.

**Critical insight:** Run too many iterations and P(marked) *decreases* again — the quantum "resonance" overshoots. This is why the game uses the optimal count.

---

## Classroom Exercises

**Exercise 1 — Superposition Intuition**
> Ask students: if you have 16 cells and no information, what's your classical success probability? (1/16 = 6.25%). Now play the superposition phase. "The quantum computer checks all 16 simultaneously."

**Exercise 2 — Counting Iterations**
> For a 4-qubit grid (N=16): optimal iterations = floor(π/4 × √16) = floor(π) = 3.
> Run the Python sim with 1, 2, 3, 4, 5 iterations. Plot P(marked). What do students notice?

**Exercise 3 — Scaling Law**
> Fill in the table:

| N (items) | Classical avg | Grover iterations | Speedup |
|---|---|---|---|
| 4 | 2 | 1 | 2× |
| 16 | 8 | 3 | 2.7× |
| 64 | 32 | 6 | 5.3× |
| 256 | 128 | 12 | 10.7× |
| 1,000,000 | 500,000 | 785 | 637× |

> Pattern: Grover scales as √N, classical scales as N. For large N, quantum wins enormously.

---

## Why Can't Grover Break Encryption?

A common misconception: Grover's algorithm "breaks AES" by searching the key space.

**Reality:** AES-128 has N = 2^128 possible keys.
- Classical brute force: 2^127 operations
- Grover search: √(2^128) = 2^64 operations

This does reduce security, but 2^64 operations on a quantum computer with millions of logical qubits is still computationally intractable with current and near-future hardware. The solution is AES-256, which Grover reduces to 2^128 equivalent — still safe.

---

## Further Reading
- [Grover's original paper (1996)](https://arxiv.org/abs/quant-ph/9605043)
- [IBM Quantum Learning](https://learning.quantum.ibm.com)
- [Qiskit Textbook — Grover's Algorithm](https://qiskit.org/learn/course/algorithm-design/grovers-algorithm)
- [Nielsen & Chuang, Ch.6](http://www.michaelnielsen.org/qcqi/) — standard textbook reference
