# G3 — benchmark desktop cuối

Windows / RTX 3050 Ti Laptop GPU / Godot 4.7.2 / 640×480 / 4.096 bụi / cap 60fps. Warm 30, lấy 60 frame mỗi case. CPU manager gồm culling và feed; GPU là toàn viewport. Actor chuyển động proxy, không chạy AI. Số đo một lượt; không suy từ FPS hoặc coi là ngân sách điện thoại.

| Renderer | Actor | Upload Hz | Manager CPU p50 ms | Manager CPU p95 ms | GPU p95 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| gl_compatibility | 0 | 30 | 0.049 | 0.076 | 0.468 |
| gl_compatibility | 1 | 30 | 0.065 | 0.104 | 0.086 |
| gl_compatibility | 16 | 30 | 0.100 | 0.174 | 0.544 |
| gl_compatibility | 87 | 30 | 0.159 | 0.437 | 0.136 |
| gl_compatibility | 96 | 30 | 0.076 | 0.559 | 0.331 |
| gl_compatibility | 0 | 60 | 0.050 | 0.087 | 0.280 |
| gl_compatibility | 1 | 60 | 0.074 | 0.118 | 0.087 |
| gl_compatibility | 16 | 60 | 0.115 | 0.201 | 0.393 |
| gl_compatibility | 87 | 60 | 0.315 | 0.519 | 0.156 |
| gl_compatibility | 96 | 60 | 0.393 | 0.671 | 0.145 |
| forward_plus | 0 | 30 | 0.047 | 0.075 | 0.034 |
| forward_plus | 1 | 30 | 0.060 | 0.102 | 0.073 |
| forward_plus | 16 | 30 | 0.069 | 0.245 | 0.218 |
| forward_plus | 87 | 30 | 0.113 | 0.407 | 0.089 |
| forward_plus | 96 | 30 | 0.076 | 0.588 | 0.057 |
| forward_plus | 0 | 60 | 0.055 | 0.085 | 0.077 |
| forward_plus | 1 | 60 | 0.073 | 0.109 | 0.073 |
| forward_plus | 16 | 60 | 0.119 | 0.203 | 0.068 |
| forward_plus | 87 | 60 | 0.308 | 0.610 | 0.060 |
| forward_plus | 96 | 60 | 0.333 | 0.504 | 0.135 |
