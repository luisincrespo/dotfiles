#!/usr/bin/env python3
"""Merge the repo's durable preferences into one of a machine's Claude Code JSON files.

Additive and key-by-key: a key named in the stable file is set, one that isn't
is left untouched, so machine-owned settings (model, modelSettings) and
anything Claude Code writes at runtime survive. Nested objects merge one level
deep, so `permissions.allow` is preserved while `permissions.defaultMode` is set.

The target is replaced atomically, keeping its permissions: a running Claude
Code session reads these files at any moment, and must see the old version or
the new one, never half of one.

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
        tmp = f"{target_path}.merge-{os.getpid()}"
        with io.open(tmp, 'w', encoding='utf-8') as f:
            f.write(json.dumps(target, indent=2) + "\n")
        if os.path.exists(target_path):
            os.chmod(tmp, os.stat(target_path).st_mode & 0o7777)
        os.replace(tmp, target_path)
    return 0

if __name__ == '__main__':
    sys.exit(main())
