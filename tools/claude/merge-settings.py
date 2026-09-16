#!/usr/bin/env python3
"""Merge the repo's durable preferences into a machine's Claude settings.

Additive and key-by-key: a key named in settings.stable.json is set, one that
isn't is left untouched, so machine-owned settings (model, modelSettings) and
anything Claude Code writes at runtime survive. Nested objects merge one level
deep, so `permissions.allow` is preserved while `permissions.defaultMode` is set.

Usage: merge-settings.py <stable.json> <target.json> [--dry-run]
"""
import json, sys, collections, io, os

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    dry = '--dry-run' in sys.argv
    if len(args) != 2:
        print(__doc__); return 2
    stable_path, target_path = args

    stable = {k: v for k, v in json.load(io.open(stable_path, encoding='utf-8')).items()
              if not k.startswith('//')}
    if os.path.exists(target_path):
        target = json.load(io.open(target_path, encoding='utf-8'),
                           object_pairs_hook=collections.OrderedDict)
    else:
        target = collections.OrderedDict()

    changes = []
    for key, want in stable.items():
        have = target.get(key)
        if isinstance(want, dict) and isinstance(have, dict):
            for sub, subwant in want.items():          # merge one level down
                if have.get(sub) != subwant:
                    changes.append(f"{key}.{sub}: {have.get(sub)!r} -> {subwant!r}")
                    have[sub] = subwant
        elif have != want:
            changes.append(f"{key}: {have!r} -> {want!r}")
            target[key] = json.loads(json.dumps(want))  # deep copy

    if not changes:
        print("      already matches the repo's durable preferences")
        return 0
    for c in changes:
        print(f"      {'would set' if dry else 'set'} {c}")
    if not dry:
        io.open(target_path, 'w', encoding='utf-8').write(json.dumps(target, indent=2) + "\n")
    return 0

if __name__ == '__main__':
    sys.exit(main())
