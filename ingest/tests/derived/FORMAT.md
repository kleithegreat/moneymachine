# Derived-input test cases (C5.5)

One JSON object per line, holding the records of `venue/sources/derived.md`, already cut at the
dataset version:

- `observations`: `[key, id, created, at]` lists, in no particular order. `key` is a string, `id` an
  integer; ids may repeat across keys, and an item is a (key, id) pair.
- `polls`: an object mapping key to its successful poll times, in no particular order. Keys absent
  here have no polls.
- `coin_of`: the mapping, an object from key to coin. Distinct keys map to distinct coins.
- `margin`: the source's margin in milliseconds, added to an item's earliest observation to give its knownAt.
- `version`: the dataset version V. Every observation and poll is at or before it.

All times are integer milliseconds. The expected output is the list of `[coin, tau, count]` rows,
one per covered hour, in any order.
