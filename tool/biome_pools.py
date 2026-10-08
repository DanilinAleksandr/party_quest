"""BIOME POOLS — how many cards each biome can draw, by place.

Developer-only, like content_health.py. Run from the project root:

    python tool/biome_pools.py              # table
    python tool/biome_pools.py --json       # machine-readable, for diffs

A card counts for a biome and a place when its *card-level* biome conditions
(`inBiome` / `notInBiome`) let it through there and its tags put it in that
place:

- road: no `village`, `rest`, `tavern` or `town` tag, and no
  `worldFlagSet: in_tavern` condition;
- village: tagged `village`;
- rest: tagged `rest`.

Everything else about a card (flags, items, origins, steps) is ignored: this
is the ceiling of what a biome can show, not what one match will see. Cards
tagged `town` are counted apart — they are out of every pool until the game
has a town to put them in.
"""

import glob
import json
import sys

BIOMES = ['forest', 'mountains', 'coast', 'desert', 'floodlands', 'graveyard']
PLACES = ['road', 'village', 'rest']


def load(root='assets/data/cards'):
    cards = []
    for path in sorted(glob.glob(f'{root}/*.json')):
        with open(path, encoding='utf-8') as f:
            cards.extend(json.load(f))
    return cards


def open_in(card, biome):
    for c in card.get('conditions', []):
        if c['condition'] == 'inBiome' and c['biomeId'] != biome:
            return False
        if c['condition'] == 'notInBiome' and c['biomeId'] == biome:
            return False
    return True


def place_of(card):
    tags = set(card.get('tags', []))
    if 'town' in tags:
        return 'town'
    if 'village' in tags:
        return 'village'
    if 'rest' in tags:
        return 'rest'
    if 'tavern' in tags or any(
        c['condition'] == 'worldFlagSet' and c.get('flag') == 'in_tavern'
        for c in card.get('conditions', [])
    ):
        return 'tavern'
    return 'road'


def pools(cards):
    out = {p: {b: 0 for b in BIOMES} for p in PLACES}
    town = 0
    for card in cards:
        place = place_of(card)
        if place == 'town':
            town += 1
            continue
        if place not in out:
            continue
        for b in BIOMES:
            if open_in(card, b):
                out[place][b] += 1
    return out, town


def main():
    cards = load()
    out, town = pools(cards)
    if '--json' in sys.argv:
        print(json.dumps({'pools': out, 'town': town}, ensure_ascii=False))
        return
    sys.stdout.reconfigure(encoding='utf-8')
    print('place    ' + ''.join(f'{b:>12}' for b in BIOMES))
    for p in PLACES:
        print(f'{p:8} ' + ''.join(f'{out[p][b]:>12}' for b in BIOMES))
    print(f'town (out of play): {town}')


if __name__ == '__main__':
    main()
