import copy
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from compare_offline_states import compare


class OfflineStateComparisonTest(unittest.TestCase):
    def test_generated_pickup_ids_and_references_are_semantic(self):
        left = {'animals': [{'id': 'hen', 'pickup': 'old'}], 'pickups': [{'id': 'old', 'item': 'egg', 'position': [1, 2], 'amount': 7}], 'task': {'kind': 'pickup', 'id': 'old'}}
        right = copy.deepcopy(left)
        right['animals'][0]['pickup'] = right['pickups'][0]['id'] = right['task']['id'] = 'new'
        self.assertTrue(compare(left, right)['ok'])
        right['pickups'][0]['amount'] = 6
        self.assertFalse(compare(left, right)['ok'])

    def test_inventory_order_tiers_and_wages_are_not_normalized(self):
        left = {'coins': 100, 'slots': [{'item': 'apple', 'count': 2, 'tiers': [1, 1, 0]}, {'item': '', 'count': 0, 'tiers': [0, 0, 0]}]}
        for mutation in ['coins', 'tiers', 'slots']:
            right = copy.deepcopy(left)
            if mutation == 'coins':
                right['coins'] -= 1
            elif mutation == 'tiers':
                right['slots'][0]['tiers'] = [2, 0, 0]
            else:
                right['slots'].reverse()
            self.assertFalse(compare(left, right)['ok'])

    def test_float_roundoff_is_allowed_but_task_phase_changes_fail(self):
        left = {'task': {'kind': 'patrol', 'finish_at': 1234.56789}, 'patrol_index': 2}
        right = copy.deepcopy(left)
        right['task']['finish_at'] += 0.000001
        self.assertTrue(compare(left, right)['ok'])
        right['patrol_index'] = 3
        self.assertFalse(compare(left, right)['ok'])
        right = copy.deepcopy(left)
        right['task']['finish_at'] += 0.01
        self.assertFalse(compare(left, right)['ok'])


if __name__ == '__main__':
    unittest.main()
