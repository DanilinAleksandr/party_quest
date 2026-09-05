"""CONTENT HEALTH — developer-only report on the state of the game's content.

Not part of the app. Run from the project root after any content wave:

    python tool/content_health.py            # full report
    python tool/content_health.py --brief    # summary + recommendations only

It answers the question a manual audit used to answer by hand: is the content
still varied, or is it drifting — flattening out, leaning on one system,
growing monster cards nobody can read?

A *modifier* is one distinct condition attached to a card's choices: an
origin that unlocks a line, an item that changes the price, a faction
standing that changes who is talking to you. Two choices gated on the same
item count once — what matters is how many different things about a party
can change this scene.

Deliberately NOT counted as modifiers: player counts, step thresholds,
biome/phase/game-mode gates. Those vary by table and by where you are, not
by the party's story, and counting them would flatter every card equally.

Sync note: this script knows condition names as strings, which the engine
knows as classes. To stop the two drifting apart silently, every unknown
`condition` value found in the content is reported as a warning instead of
being ignored — see UNKNOWN CONDITIONS at the end of the report.
"""

import glob
import io
import json
import os
import re
import sys
from collections import Counter, defaultdict
from itertools import combinations

# --------------------------------------------------------------------------
# What each condition says about *the party*, and what it is called in the
# report. `None` means "deliberately not a modifier" (see the module doc).

SYSTEMS = {
    'origin': 'Происхождения',
    'item': 'Предметы',
    'blessing': 'Благословения',
    'curse': 'Проклятия',
    'world': 'Флаги мира',
    'ally': 'Союзники',
    'stat': 'Характеристики',
    'ambient': 'Погода и сезон',
}

CONDITION_SYSTEM = {
    'currentPlayerHasOrigin': 'origin',
    'anyPlayerHasOrigin': 'origin',
    'currentPlayerLacksOrigin': 'origin',
    'anyPlayerMissingOrigin': 'origin',
    'currentPlayerOriginUnknown': 'origin',
    'currentPlayerHasItem': 'item',
    'partyHasItem': 'item',
    'anyPlayerHasItem': 'item',
    'currentPlayerMissingItem': 'item',
    'partyMissingItem': 'item',
    # effect conditions are split into blessing/curse by the effect's own
    # polarity — resolved in classify() below.
    'currentPlayerHasEffect': 'effect',
    'anyPlayerHasEffect': 'effect',
    'currentPlayerMissingEffect': 'effect',
    'worldFlagSet': 'world',
    'worldFlagUnset': 'world',
    'minimumStepsSinceFlag': 'world',
    'adventureCompleted': 'world',
    'adventureNotCompleted': 'world',
    'globalModifierAtLeast': 'world',
    'currentPlayerStatAtLeast': 'stat',
    'anyPlayerStatAtLeast': 'stat',
    'inWeather': 'ambient',
    'notInWeather': 'ambient',
    'inSeason': 'ambient',
    'notInSeason': 'ambient',
    'minimumTurnsInWeather': 'ambient',
    # --- known, and deliberately not modifiers ---
    'inBiome': None,
    'notInBiome': None,
    'minimumTurnsInBiome': None,
    'minimumTurnsInTavern': None,
    'minimumPlayers': None,
    'maximumPlayers': None,
    'minimumStep': None,
    'maximumStep': None,
    'gameMode': None,
    'inPhase': None,
    'leaderIsSet': None,
    'leaderIsUnset': None,
}

FACTIONS = {
    'Орден': {'paladin_ally', 'declared_heretic', 'paladin_debt'},
    'Ведьмовской круг': {'circle_ally', 'circle_enemy'},
    'Пираты': {'captain_ally', 'cheated_pirate_captain', 'knows_captain_haunt'},
    'Вожди пустыни': {'warlord_ally', 'warlord_enemy', 'warlord_respect'},
}

# Recurring people: the flags that remember a *person* rather than a deed.
# Each entry is (положительная память, отрицательная память) — either may be
# None for an NPC the party can only wrong or only help.
RECURRING_NPCS = {
    'Коробейник': ('helped_peddler', 'cheated_peddler'),
    'Травница': ('helped_herbwoman', 'cheated_herbwoman'),
    'Шулер': ('helped_cardsharp', 'cheated_cardsharp'),
    'Алхимик': ('helped_alchemist', 'cheated_alchemist'),
    'Могильщик': ('helped_gravedigger', 'cheated_gravedigger'),
    'Караванщик': ('helped_caravan', 'robbed_caravan'),
    'Странник': ('helped_wanderer', 'cheated_wanderer'),
    'Музыкант': ('helped_musician', 'cheated_musician'),
    'Контрабандист': ('helped_smuggler', 'cheated_smuggler'),
    'Отшельник': ('helped_hermit', 'cheated_hermit'),
    'Кузнец': ('helped_smith', 'cheated_smith'),
    'Картограф': ('helped_cartographer', 'cheated_cartographer'),
    'Сборщик податей': ('paid_taxman', 'dodged_taxman'),
}

FLAT_LIMIT = 8          # how many flat cards to list
OVERLOAD_AT = 8         # modifiers above which a card is worth a second look
RARE_SYSTEM_AT = 12     # a system in fewer cards than this is starving
DOMINANT_SHARE = 0.65   # a system in more than this share of cards dominates

unknown_conditions = Counter()


# --------------------------------------------------------------------------
# Loading

def _read_json(path):
    return json.load(io.open(path, encoding='utf-8'))


def load_cards():
    cards = []
    for path in sorted(glob.glob('assets/data/cards/*.json')):
        for card in _read_json(path):
            card['_file'] = os.path.basename(path)
            cards.append(card)
    return cards


def load_adventures():
    out = []
    for path in sorted(glob.glob('assets/data/adventures/*.json')):
        for adventure in _read_json(path):
            adventure['_file'] = os.path.basename(path)
            out.append(adventure)
    return out


def load_named(pattern, key):
    out = {}
    for path in sorted(glob.glob(pattern)):
        data = _read_json(path)
        rows = data[key] if isinstance(data, dict) else data
        for row in rows:
            out[row['id']] = row
    return out


def load_ally_flags():
    """Read the ally registry out of the Dart source so the two can't drift."""
    path = 'lib/core/constants/ally_flags.dart'
    if not os.path.exists(path):
        return set()
    source = io.open(path, encoding='utf-8').read()
    body = source.split('allyFlags = {', 1)[-1]
    return set(re.findall(r"^\s*'([a-z_]+)':", body, re.M))


# --------------------------------------------------------------------------
# Classification

def classify(condition, ally_flags, effect_polarity):
    """Which system this condition makes a card react to, or None."""
    name = condition.get('condition')
    system = CONDITION_SYSTEM.get(name, 'UNKNOWN')
    if system == 'UNKNOWN':
        unknown_conditions[name] += 1
        return None
    if system == 'effect':
        polarity = effect_polarity.get(condition.get('effectId'))
        return 'blessing' if polarity == 'positive' else 'curse'
    if system == 'world' and name == 'worldFlagSet':
        if condition.get('flag') in ally_flags:
            return 'ally'
    return system


def card_modifiers(card, ally_flags, effect_polarity):
    """(distinct modifiers, systems touched, per-choice system sets)."""
    modifiers, systems, per_choice = set(), set(), []
    for choice in card.get('choices', []):
        local = set()
        for condition in choice.get('conditions', []):
            system = classify(condition, ally_flags, effect_polarity)
            if not system:
                continue
            systems.add(system)
            local.add(system)
            modifiers.add(json.dumps(condition, sort_keys=True))
        per_choice.append(local)
    return modifiers, systems, per_choice


# --------------------------------------------------------------------------
# Report helpers

def rule(title):
    print()
    print('=' * 62)
    print(title)
    print('=' * 62)


def bar(value, peak, width=24):
    if peak <= 0:
        return ''
    filled = int(round(width * value / peak))
    return '█' * filled + '·' * (width - filled)


def dotted(label, value, width=26):
    return '%s %s %s' % (label, '.' * max(2, width - len(label)), value)


# --------------------------------------------------------------------------

def main():
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    brief = '--brief' in sys.argv

    cards = load_cards()
    adventures = load_adventures()
    origins = load_named('assets/data/origins/*.json', 'origins')
    effects = load_named('assets/data/effects/*.json', 'effects')
    effect_polarity = {k: v.get('polarity') for k, v in effects.items()}
    ally_flags = load_ally_flags()

    choice_cards = [c for c in cards if c.get('choices')]
    analysed = []
    for card in choice_cards:
        modifiers, systems, per_choice = card_modifiers(
            card, ally_flags, effect_polarity)
        analysed.append({
            'id': card['id'],
            'file': card['_file'],
            'weight': card.get('weight', 0),
            'choices': len(card['choices']),
            'count': len(modifiers),
            'systems': systems,
            'per_choice': per_choice,
        })

    total = len(analysed)
    flat = [a for a in analysed if a['count'] == 0]
    deep = [a for a in analysed if a['count'] >= 4]
    average = sum(a['count'] for a in analysed) / total if total else 0
    weight_sum = sum(a['weight'] for a in analysed)
    weighted = (sum(a['count'] * a['weight'] for a in analysed) / weight_sum
                if weight_sum else 0)

    recommendations = []

    # ---------------------------------------------------------------- header
    rule('CONTENT HEALTH')
    print(dotted('Карточек с выбором', total))
    print(dotted('Среднее модификаторов', '%.2f' % average))
    print(dotted('Средневзвешенное', '%.2f' % weighted))
    print(dotted('Без модификаторов', len(flat)))
    print(dotted('С 4+ модификаторами', '%d из %d' % (len(deep), total)))
    print()
    print('  Средневзвешенное считается по весу вытягивания: это то, сколько')
    print('  развилок игрок реально встречает за столом, а не в каталоге.')

    # --------------------------------------------------------------- systems
    usage = Counter()
    for a in analysed:
        usage.update(a['systems'])
    peak = max(usage.values()) if usage else 0

    rule('ИСПОЛЬЗОВАНИЕ СИСТЕМ')
    for key, label in SYSTEMS.items():
        count = usage[key]
        share = count * 100 / total if total else 0
        print('%-18s %s %3d  (%4.1f%%)'
              % (label, bar(count, peak), count, share))

    for key, label in SYSTEMS.items():
        count = usage[key]
        if count == 0:
            recommendations.append(('warn', '%s не используются вообще.' % label))
        elif count < RARE_SYSTEM_AT:
            recommendations.append(
                ('warn', '%s используются только в %d карточках.' % (label, count)))
        elif total and count / total > DOMINANT_SHARE:
            recommendations.append(
                ('warn', '%s используются в %d%% карточек — возможен перекос.'
                 % (label, round(count * 100 / total))))

    # ------------------------------------------------------------ flat cards
    if not brief:
        show_all = '--all' in sys.argv
        rule('ВСЕ КАРТОЧКИ' if show_all else 'ПЛОСКИЕ КАРТОЧКИ')
        thin = sorted(analysed, key=lambda a: (a['count'], -a['weight']))
        if show_all:
            print('%-4s %-5s %-36s %s' % ('вес', 'моды', 'id', 'файл'))
            for a in thin:
                print('%-4d %-5d %-36s %s'
                      % (a['weight'], a['count'], a['id'], a['file']))
            thin = []
        for a in thin[:FLAT_LIMIT]:
            print('%s' % a['id'])
            print('  вес: %d   модификаторов: %d   вариантов: %d'
                  % (a['weight'], a['count'], a['choices']))
            names = [SYSTEMS[s] for s in SYSTEMS if s in a['systems']]
            print('  системы: %s' % (', '.join(names) if names else '— нет —'))
            print()

    # ------------------------------------------------------ overloaded cards
    overloaded = sorted([a for a in analysed if a['count'] >= OVERLOAD_AT],
                        key=lambda a: -a['count'])
    if not brief:
        rule('ПЕРЕГРУЖЕННЫЕ КАРТОЧКИ')
        if not overloaded:
            print('Нет карточек с %d+ модификаторами.' % OVERLOAD_AT)
        for a in overloaded[:6]:
            print('%s' % a['id'])
            print('  вес: %d   модификаторов: %d   вариантов: %d   систем: %d'
                  % (a['weight'], a['count'], a['choices'], len(a['systems'])))
            print()
    if overloaded:
        worst = overloaded[0]
        if worst['choices'] >= 10:
            recommendations.append(
                ('warn', '%s показывает до %d вариантов — проверь, читается ли '
                 'она за столом.' % (worst['id'], worst['choices'])))

    # -------------------------------------------------------- intersections
    pair_counts = Counter()
    same_choice_pairs = Counter()
    for a in analysed:
        for pair in combinations(sorted(a['systems']), 2):
            pair_counts[pair] += 1
        for local in a['per_choice']:
            for pair in combinations(sorted(local), 2):
                same_choice_pairs[pair] += 1

    if not brief:
        rule('ПЕРЕСЕЧЕНИЯ СИСТЕМ')
        print('Чаще всего в одной карточке:')
        for (a_, b_), n in pair_counts.most_common(6):
            print('  %-24s + %-24s %d' % (SYSTEMS[a_], SYSTEMS[b_], n))

        all_pairs = set(combinations(sorted(SYSTEMS), 2))
        missing = sorted(p for p in all_pairs if pair_counts[p] <= 1)
        print()
        print('Почти никогда не встречаются вместе:')
        if not missing:
            print('  — таких пар нет —')
        for a_, b_ in missing[:8]:
            print('  %-24s + %-24s %d' % (SYSTEMS[a_], SYSTEMS[b_],
                                          pair_counts[(a_, b_)]))

        print()
        print('В одном варианте выбора (две системы сразу — самая глубокая форма):')
        if not same_choice_pairs:
            print('  — нет —')
        for (a_, b_), n in same_choice_pairs.most_common(5):
            print('  %-24s + %-24s %d' % (SYSTEMS[a_], SYSTEMS[b_], n))

    if not same_choice_pairs:
        recommendations.append(
            ('warn', 'Ни один вариант выбора не требует двух систем сразу.'))

    # ------------------------------------------------------------- factions
    def flags_in(node, found):
        if isinstance(node, dict):
            if node.get('condition') in ('worldFlagSet', 'worldFlagUnset',
                                         'minimumStepsSinceFlag'):
                found.add(node.get('flag'))
            for value in node.values():
                flags_in(value, found)
        elif isinstance(node, list):
            for value in node:
                flags_in(value, found)
        return found

    faction_rows = []
    for name, flags in FACTIONS.items():
        touching = 0
        crossings = 0
        for card in cards:
            read = flags_in(card, set())
            if not read & flags:
                continue
            touching += 1
            for other, other_flags in FACTIONS.items():
                if other != name and read & other_flags:
                    crossings += 1
                    break
        in_adventures = sum(
            1 for adv in adventures if flags_in(adv, set()) & flags)
        faction_rows.append((name, touching, in_adventures,
                             len(flags & ally_flags), len(flags), crossings))

    if not brief:
        rule('ФРАКЦИИ')
        for name, touching, in_adv, allies, states, crossings in faction_rows:
            print(name)
            print('  карточек ............. %d' % touching)
            print('  приключений .......... %d' % in_adv)
            print('  флагов союза ......... %d' % allies)
            print('  состояний мира ....... %d' % states)
            print('  пересечений с другими  %d' % crossings)
            print()

    active = [r for r in faction_rows if r[1] > 0]
    if len(active) >= 2:
        richest = max(active, key=lambda r: r[1])
        poorest = min(active, key=lambda r: r[1])
        if richest[1] >= poorest[1] * 3:
            recommendations.append(
                ('warn', 'Фракция «%s» присутствует в %d карточках против '
                 '%d у «%s».' % (richest[0], richest[1], poorest[1],
                                 poorest[0])))

    # ---------------------------------------------------- recurring people
    # A card *sets* a memory flag (the meeting where it is earned) or *reads*
    # it (the re-encounter where the world remembers). Only the second kind
    # produces the "подожди, я же его встречал" moment, so they are counted
    # apart.
    def flags_touched(node, setters, readers):
        if isinstance(node, dict):
            if node.get('action') == 'setWorldFlag' and node.get('value') is True:
                setters.add(node.get('flag'))
            if node.get('condition') in ('worldFlagSet', 'minimumStepsSinceFlag'):
                readers.add(node.get('flag'))
            for value in node.values():
                flags_touched(value, setters, readers)
        elif isinstance(node, list):
            for value in node:
                flags_touched(value, setters, readers)
        return setters, readers

    def biomes_of(card):
        found = set()

        def walk(node):
            if isinstance(node, dict):
                if node.get('condition') == 'inBiome':
                    found.add(node.get('biomeId'))
                for value in node.values():
                    walk(value)
            elif isinstance(node, list):
                for value in node:
                    walk(value)

        walk(card)
        # A card with no biome gate can turn up anywhere — that is a wider
        # reach than any single biome, not a narrower one.
        return found or {'везде'}

    npc_rows = []
    for name, (good, bad) in RECURRING_NPCS.items():
        memory = {f for f in (good, bad) if f}
        meetings, reencounters, biomes = 0, 0, set()
        for card in cards:
            setters, readers = flags_touched(card, set(), set())
            if setters & memory:
                meetings += 1
            if readers & memory:
                reencounters += 1
                biomes |= biomes_of(card)
        npc_rows.append((name, meetings, reencounters, sorted(biomes)))

    if not brief:
        rule('ПОСТОЯННЫЕ ЛЮДИ')
        print('  встреч — где память о человеке возникает')
        print('  повторных — где мир его вспоминает')
        print()
        print('%-18s %7s %10s  %s' % ('кто', 'встреч', 'повторных', 'биомы'))
        for name, meetings, reencounters, biomes in sorted(
                npc_rows, key=lambda r: -r[2]):
            print('%-18s %7d %10d  %s'
                  % (name, meetings, reencounters, ', '.join(biomes)))
        print()
        deep = [r for r in npc_rows if r[2] >= 3]
        print('NPC с тремя и более повторными встречами: %d из %d'
              % (len(deep), len(npc_rows)))
        print('Всего повторных встреч: %d'
              % sum(r[2] for r in npc_rows))

    silent_npcs = [r[0] for r in npc_rows if r[2] == 0]
    if silent_npcs:
        recommendations.append(
            ('warn', 'Помнят, но никогда не встречают снова: %s.'
             % ', '.join(silent_npcs)))
    unmet = [r[0] for r in npc_rows if r[1] == 0]
    if unmet:
        recommendations.append(
            ('warn', 'Память есть, а первой встречи нет: %s.' % ', '.join(unmet)))

    # --------------------------------------------------------- origin paths
    origin_stats = defaultdict(lambda: {'knows': set(), 'opens': 0,
                                        'closes': 0, 'shortcuts': 0,
                                        'stories': 0, 'reveals': 0})

    def scan_reveals(node):
        """Where an origin is *granted*. Kept apart from the columns that
        count reactions: a legendary origin whose reveal lives inside its own
        adventure but which nothing else ever reacts to reads as `знают 0`,
        and that is a different (and worse) problem than an origin that does
        not exist yet."""
        if isinstance(node, dict):
            if node.get('action') == 'revealOrigin':
                origin_stats[node.get('originId')]['reveals'] += 1
            for value in node.values():
                scan_reveals(value)
        elif isinstance(node, list):
            for value in node:
                scan_reveals(value)

    for source in cards + adventures:
        scan_reveals(source)

    def scan_origins(node, source, inside_choice=False):
        if isinstance(node, dict):
            name = node.get('condition')
            if name in ('currentPlayerHasOrigin', 'anyPlayerHasOrigin'):
                oid = node.get('originId')
                origin_stats[oid]['knows'].add(source)
            elif name == 'currentPlayerLacksOrigin':
                origin_stats[node.get('originId')]['closes'] += 1
            for value in node.values():
                scan_origins(value, source, inside_choice)
        elif isinstance(node, list):
            for value in node:
                scan_origins(value, source, inside_choice)

    def choice_origins(choice):
        return [c.get('originId') for c in choice.get('conditions', [])
                if c.get('condition') == 'currentPlayerHasOrigin']

    def actions_of(choice):
        out = list(choice.get('actions', []))
        for branch in ('onSuccess', 'onFailure'):
            if isinstance(choice.get(branch), dict):
                out += choice[branch].get('actions', [])
        return out

    for card in cards:
        scan_origins(card, card['id'])
        for choice in card.get('choices', []):
            for oid in choice_origins(choice):
                origin_stats[oid]['opens'] += 1
                actions = actions_of(choice)
                starts = any(a.get('action') == 'startAdventure' for a in actions)
                flags_set = sum(1 for a in actions
                                if a.get('action') == 'setWorldFlag'
                                and a.get('value') is True)
                if starts or flags_set >= 2:
                    origin_stats[oid]['shortcuts'] += 1
        # a card whose *own* conditions name exactly one origin is that
        # origin's personal scene
        card_origins = {c.get('originId') for c in card.get('conditions', [])
                        if c.get('condition') in ('currentPlayerHasOrigin',
                                                  'anyPlayerHasOrigin')}
        if len(card_origins) == 1:
            origin_stats[card_origins.pop()]['stories'] += 1

    for adventure in adventures:
        scan_origins(adventure, adventure['id'])
        for node in adventure.get('nodes', []):
            for choice in node.get('choices', []):
                for oid in choice_origins(choice):
                    origin_stats[oid]['opens'] += 1

    if not brief:
        rule('ПУТИ ПРОИСХОЖДЕНИЙ')
        print('  знают — в скольких карточках/приключениях его узнают')
        print('  откр/закр — вариантов открывает / закрывает')
        print('  сокр — сокращений пути (сразу в приключение или через флаги)')
        print('  ист — личных сцен;  раскр — где вообще выдаётся')
        print()
        print('%-30s %6s %5s %5s %5s %4s %6s' %
              ('происхождение', 'знают', 'откр', 'закр', 'сокр', 'ист', 'раскр'))
        rows = []
        for oid, origin in origins.items():
            s = origin_stats[oid]
            rows.append((len(s['knows']), oid, origin['name'], s))
        for knows, oid, name, s in sorted(rows):
            print('%-30s %6d %5d %5d %5d %4d %6d'
                  % (name[:30], knows, s['opens'], s['closes'],
                     s['shortcuts'], s['stories'], s['reveals']))

    quiet = [origins[oid]['name'] for oid in origins
             if len(origin_stats[oid]['knows']) <= 1
             and origin_stats[oid]['reveals'] > 0]
    missing = [origins[oid]['name'] for oid in origins
               if origin_stats[oid]['reveals'] == 0]
    if quiet:
        recommendations.append(
            ('warn', 'Раскрываются, но почти не участвуют потом: %s.'
             % ', '.join(quiet[:6])))
    if missing:
        recommendations.append(
            ('warn', 'Нигде не выдаются игроку: %s.' % ', '.join(missing[:6])))

    # ------------------------------------------------------------- verdicts
    if not flat:
        recommendations.insert(0, ('ok', 'Все карточки имеют минимум один модификатор.'))
    else:
        recommendations.insert(
            0, ('warn', 'Карточек без модификаторов: %d.' % len(flat)))
    if average >= 4:
        recommendations.insert(
            1, ('ok', 'Среднее число модификаторов %.2f — выше цели в 4.' % average))
    else:
        recommendations.insert(
            1, ('warn', 'Среднее число модификаторов %.2f — ниже цели в 4.' % average))

    if unknown_conditions:
        rule('НЕИЗВЕСТНЫЕ УСЛОВИЯ')
        print('Эти условия есть в контенте, но не классифицированы в скрипте —')
        print('добавь их в CONDITION_SYSTEM, иначе отчёт занижает разнообразие:')
        for name, count in unknown_conditions.most_common():
            print('  %-34s %d' % (name, count))
        recommendations.append(
            ('warn', 'Скрипт встретил %d неизвестных типов условий.'
             % len(unknown_conditions)))

    rule('ИТОГ')
    for kind, text in recommendations:
        print(('  ✓ ' if kind == 'ok' else '  ⚠️  ') + text)
    print()


if __name__ == '__main__':
    main()
