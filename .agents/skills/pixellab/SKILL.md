---
name: pixellab
description: Generate pixel art assets (characters, animations, tilesets, icons, foods, props) directly using PixelLab AI MCP tools.
---

# PixelLab AI Pixel Art Generation Skill

PixelLab provides AI-powered pixel art generation via Model Context Protocol (MCP) and REST endpoints.

## Configuration Details
- **Endpoint**: `https://api.pixellab.ai/mcp`
- **Transport**: Streamable HTTP
- **Config locations**:
  - Global: `~/.gemini/config/mcp_config.json`
  - Workspace: `.mcp.json`
- **MCP Tool Schemas Cache**: `~/.gemini/antigravity/mcp/pixellab/` (103 tools)

## Fast Invocation via Node Helper
You can run any tool using the project helper:
```bash
node .agents/skills/pixellab/scripts/pixellab.mjs <toolName> '<jsonArguments>'
```

Example checking balance:
```bash
node .agents/skills/pixellab/scripts/pixellab.mjs get_balance
```

Example listing active background jobs:
```bash
node .agents/skills/pixellab/scripts/pixellab.mjs list_jobs
```

## Workflow Pattern
All generation tools are non-blocking:
1. Submit request -> get job ID instantly.
2. Check job status with `wait_for_jobs` or `get_*` tools.
3. Download resulting image or spritesheet to `res://assets/...`.
