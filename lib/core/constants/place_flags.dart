/// World flags that say *where the party is standing*, not what the world
/// remembers.
///
/// `in_tavern` and `in_rest` are ordinary `WorldState` flags, and cards
/// inside those detours test them with `worldFlagSet` like any other. But
/// they are the game's own bookkeeping — "you are at the fire right now" —
/// and the party is looking at the banner that says so. `influenceTagsOf`
/// reads this set to keep them from earning a «Мир» badge, which is meant
/// for the world's memory of what the party did.
///
/// Sits next to `allyFlags` for the same reason that map exists: one place
/// that says what kind of thing a flag is. A new detour built on the
/// tavern's pattern adds its flag here and nowhere else.
///
/// `left_rest` is the same bookkeeping one step later: it is stamped as the
/// party gets up from a halt, so a card can know the fire is fresh behind
/// them. It says when, not what the world remembers.
const Set<String> placeFlags = {'in_tavern', 'in_rest', 'left_rest'};
