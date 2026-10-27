"""Compare unrelated interaction-suite failures against the pre-refactor adapters."""
from pathlib import Path
import subprocess
import re

ROOT = Path(__file__).resolve().parents[2]
FILES = ['components/interaction/interaction_resolver.gd', 'components/interaction/interaction_target.gd', 'components/interaction/interaction_presenter.gd']
current = {p: (ROOT/p).read_bytes() for p in FILES}
log = ROOT/'output/flower_scene_refactor/interaction-baseline.log'
try:
    for p in FILES:
        (ROOT/p).write_bytes((ROOT/'output/flower_scene_refactor_backup'/p).read_bytes())
    with log.open('w', encoding='utf-8') as output:
        subprocess.run([r'C:/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe', '--headless', '--path', str(ROOT), '-s', 'addons/gut/gut_cmdln.gd', '-gconfig=', '-gtest=res://tests/integration/test_unified_interaction.gd', '-gexit'], cwd=ROOT, stdout=output, stderr=subprocess.STDOUT, timeout=120)
finally:
    for p, data in current.items():
        (ROOT/p).write_bytes(data)
text = re.sub(r'\x1b\[[0-9;]*m', '', log.read_text(encoding='utf-8'))
summary = text[text.rfind('= Run Summary'):]
print(summary[-3300:])
assert 'test_badge_has_live_stock_and_auto_fill_without_selecting_feed' in summary
assert 'test_click_trough_remains_explicit_even_when_a_nearby_npc_has_e_priority' in summary
assert 'test_land_price_badge_translation_and_confirm_only_debits' in summary
assert re.search(r'Failing Tests\s+3', summary)
print('BASELINE_CONFIRMED: the same three feed/land fixture failures occur with original interaction adapters; refactored files restored byte-for-byte.')
