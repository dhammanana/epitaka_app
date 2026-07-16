import json
import os

filepath = 'assets/models/tokenizer.json'
if os.path.exists(filepath):
    with open(filepath, 'r') as f:
        data = json.load(f)
        print('Top-level keys:', list(data.keys()))
        model = data.get('model', {})
        print('model type:', model.get('type'))
        print('model keys:', list(model.keys()))
        added = data.get('added_tokens', [])
        print('added_tokens count:', len(added))
        if added:
            print('First added token:', json.dumps(added[0], indent=2))
else:
    print(f"File not found: {filepath}")
