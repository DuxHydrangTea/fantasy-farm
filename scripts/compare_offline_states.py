"""Compare save DTOs, normalizing only pickup identities and collection ordering."""
import argparse
import copy
import json
from pathlib import Path


def canonical_state(snapshot):
    state = copy.deepcopy(snapshot)
    identities = {}
    for animal in state.get('animals', []):
        if animal.get('pickup'):
            identities[animal['pickup']] = 'animal-product:' + animal['id']
    piles = sorted(state.get('pickups', []), key=lambda row: json.dumps({k: v for k, v in row.items() if k != 'id'}, sort_keys=True))
    occurrences = {}
    for pile in piles:
        key = json.dumps([pile.get('parent'), pile.get('pen'), pile.get('item'), pile.get('position')], sort_keys=True)
        occurrences[key] = occurrences.get(key, 0) + 1
        identities.setdefault(pile['id'], 'pickup:' + key + '#' + str(occurrences[key]))

    def walk(value):
        if isinstance(value, str):
            return identities.get(value, value)
        if isinstance(value, dict):
            return {key: walk(item) for key, item in value.items()}
        if isinstance(value, list):
            items = [walk(item) for item in value]
            if items and all(isinstance(item, dict) and 'id' in item for item in items):
                items.sort(key=lambda item: item['id'])
            elif items and all(isinstance(item, dict) and 'cell' in item for item in items):
                items.sort(key=lambda item: item['cell'])
            return items
        return value
    return walk(state)


def compare(left, right, tolerance=0.0001):
    differences = []
    max_float_error = 0.0
    def visit(a, b, path):
        nonlocal max_float_error
        if isinstance(a, dict) and isinstance(b, dict):
            for key in sorted(a.keys() | b.keys()):
                if key not in a or key not in b:
                    differences.append({'path': path + '.' + key, 'reason': 'missing key'})
                else:
                    visit(a[key], b[key], path + '.' + key)
        elif isinstance(a, list) and isinstance(b, list):
            if len(a) != len(b):
                differences.append({'path': path, 'left_size': len(a), 'right_size': len(b)})
            for index, (first, second) in enumerate(zip(a, b)):
                visit(first, second, f'{path}[{index}]')
        elif isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool) and not isinstance(b, bool):
            error = abs(a - b)
            if isinstance(a, float) or isinstance(b, float):
                max_float_error = max(max_float_error, error)
                if error <= tolerance:
                    return
            if a != b:
                differences.append({'path': path, 'left': a, 'right': b})
        elif a != b or type(a) is not type(b):
            differences.append({'path': path, 'left': a, 'right': b})
    visit(canonical_state(left), canonical_state(right), '$')
    return {'ok': not differences, 'difference_count': len(differences), 'max_float_error': max_float_error,
            'float_absolute_tolerance': tolerance, 'differences': differences[:100],
            'normalization': 'Pickup UUIDs and id/cell collection order only; inventory slot order, tiers, quantities, wages and task timestamps retained.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('left', type=Path)
    parser.add_argument('right', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = compare(json.loads(args.left.read_text()), json.loads(args.right.read_text()))
    encoded = json.dumps(result, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded)
    print(encoded)
    return 0 if result['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
