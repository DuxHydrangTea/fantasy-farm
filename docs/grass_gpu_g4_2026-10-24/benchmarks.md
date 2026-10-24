# G4 diagnostic samples

Godot 4.7.2; Windows; NVIDIA RTX 3050 Ti Laptop GPU; 1280×720; cap 60fps.

Short diagnostic only. Values are milliseconds, p95 from raw samples. Viewport CPU/GPU includes the whole scene. Fixed-motion cases freeze AI/animation/TIME and use 30 warmup + 60 measured frames; the real-AI case uses 60 measured frames. Zero GPU samples mean unavailable timing, not zero GPU work. These samples do not establish mobile or browser performance.

| Renderer | Case | Render CPU p95 | GPU p95 | Grass manager CPU p95 | Instances / leaves |
|---|---|---:|---:|---:|---|
| compatibility | real_world_86_animals_AI | 4.7290 | 2.0120 | not measured | 10 / 7 |
| compatibility | fixed_motion_source | 6.6860 | 1.9500 | 0.0010 | 0 / 0 |
| compatibility | fixed_motion_gpu | 5.4100 | 2.0950 | 0.6480 | 10 / 7 |
| forward-plus | real_world_86_animals_AI | 1.9990 | 1.2100 | not measured | 10 / 7 |
| forward-plus | fixed_motion_source | 2.3800 | 0.4230 | 0.0010 | 0 / 0 |
| forward-plus | fixed_motion_gpu | 2.5260 | 0.4600 | 0.6590 | 10 / 7 |

Raw arrays, cache/feed counters and source/GPU screenshots are in each renderer directory. Only 10 clumps are converted; three overlapping clumps remain authored TileMap cells. Full herd is 86 animals plus player. Fallback cases and native pixel comparisons are recorded in g4-checks.json. Browser runtime and physical phones remain untested.
