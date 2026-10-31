# Using MCP Godot to Verify Worker Optimizations

## Why I didn't use MCP Godot earlier:

1. **MCP Godot requires running editor** - Tools connect via WebSocket
2. **I didn't see the tools in my available list** - Server needs active connection
3. **Fell back to manual verification** - But now we can use the proper way!

## MCP Godot Has 113 Tools Available!

Including these key ones for verification:
- `script_check` - Parse/validate GDScript without running
- `execute_code` - Run GDScript in editor context
- `game_start` / `game_stop` - Launch playtest
- `debugger_get_log` - Get runtime output
- `scene_open` / `scene_query` - Inspect scenes
- Many more! (see `npx @npgamedev/godot-mcp-server --list-eager`)

## Step-by-Step Verification Using MCP Godot

### 1. Start Godot Editor First
```bash
# Open the project in Godot editor (GUI)
# The MCP server will auto-connect via WebSocket
```

### 2. Verify Script Compilation (from ZCode/CLI)

Once editor is running, you can use MCP tools. In ZCode chat, ask:

```
Dùng MCP Godot script_check để verify các file sau compile OK:
- components/workers/worker_world_bridge.gd
- components/workers/crop_worker_policy.gd
- components/workers/worker_service.gd
```

This will call `script_check` tool which:
- Parses GDScript via Godot's LSP
- Reports compile errors without running
- Shows exact line numbers if issues exist

### 3. Run Tests via MCP Godot

```
Dùng MCP Godot để:
1. Open scene: world/main_world.tscn
2. Execute test: tests/unit/test_worker_compile.gd
3. Get debugger log để xem kết quả
```

Or manually in Godot:
```
Project > Tools > GUT: Unit Test Runner
→ Run tests/unit/test_worker_compile.gd
→ Run tests/unit/test_worker_performance.gd
```

### 4. Profile Performance with MCP

```
Dùng MCP Godot để:
1. game_start với scene chứa 15 workers
2. runtime_screenshot để capture FPS display
3. debugger_get_log để xem performance metrics
```

## Example MCP Godot Commands (via ZCode)

### Check compile errors:
```
Use mcp__godot-mcp-toolkit__script_check on:
- components/workers/worker_world_bridge.gd
```

### Execute code in editor:
```
Use mcp__godot-mcp-toolkit__execute_code to run:
```gdscript
var world = load("res://world/main_world.tscn").instantiate()
print("Workers available: ", world.workers != null)
print("Bridge has cache: ", "_trough_point_cache" in world.workers.bridge)
world.free()
```

### Get scene tree:
```
Use mcp__godot-mcp-toolkit__scene_get_tree on:
- world/main_world.tscn
```

## Why MCP Godot is Better

| Method | Manual | MCP Godot |
|--------|--------|-----------|
| Check compile | Open editor, look for errors | `script_check` - instant feedback |
| Run tests | Click through GUI | `execute_code` - automated |
| Profile | Manual observation | `debugger_get_log` - data export |
| Iteration | Slow | Fast - no GUI clicking |

## Current Status

✅ Code changes complete
✅ Verified by script (syntax check)
⏳ **Need to verify with MCP Godot** (requires running editor)

## Next Steps

1. **Mở Godot editor** (để MCP server có thể connect)
2. **Trong ZCode, chạy:**
   ```
   Dùng MCP Godot script_check verify:
   - components/workers/worker_world_bridge.gd
   - components/workers/crop_worker_policy.gd
   
   Nếu OK, chạy test:
   - tests/unit/test_worker_compile.gd
   - tests/unit/test_worker_performance.gd
   ```

3. **Manual performance test:**
   - Load save, hire 15 workers, check FPS

## MCP Godot Server Config

Already configured in `.zcode/config.json`:
```json
{
  "mcp": {
    "servers": {
      "godot-mcp-toolkit": {
        "type": "stdio",
        "command": "cmd",
        "args": ["/c", "npx", "-y", "@npgamedev/godot-mcp-server"]
      }
    }
  }
}
```

Server auto-discovers Godot WebSocket ports via project registry.

## Summary

**Lý do tôi không dùng MCP Godot ban đầu:**
- ❌ Không nhận ra nó có sẵn
- ❌ Cần Godot editor running (không thể headless check)
- ❌ Fallback to manual verification first

**Giờ bạn nên dùng MCP Godot vì:**
- ✅ 113 tools available (script_check, execute_code, etc.)
- ✅ Automated verification
- ✅ Chính xác hơn manual checking
- ✅ Có thể export performance data

**Action:** Mở Godot editor → dùng ZCode với MCP Godot tools để verify!
