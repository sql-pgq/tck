# Contributing

The most valuable contribution is a scenario. The suite's usefulness is bounded
by its coverage, and the coverage is small. See the absent list in the
[README](README.md#coverage) for where the holes are.

## The one rule

**A scenario is never deleted, weakened, or rewritten because an engine cannot
pass it.**

That is the whole discipline. The moment scenarios bend to fit implementations,
the suite stops describing SQL/PGQ and starts describing whatever the
implementations happen to do, which is the exact drift a TCK exists to catch.
If your engine fails a scenario, the options are to fix the engine, or to add
the tag to your binding's `XFAIL_TAGS` with a reason, or to argue in an issue
that the scenario is *wrong about the standard*. All three are fine. Editing the
scenario quietly is not.

The corollary: `XFAIL_TAGS` entries are debts, listed in the open so they can be
paid. `xfail_strict` is on, so an entry whose scenario starts passing fails the
build until it is removed. That is deliberate: it stops the list from
accumulating claims that stopped being true.

## Adding a scenario

Feature files live under `features/`, grouped by construct. Add to an existing
file, or start a numbered sibling (`NodePatterns3.feature`) when one grows
unwieldy.

```gherkin
  @CaseExpression
  Scenario: [16] CASE with no ELSE yields null
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 1
        COLUMNS (CASE WHEN p.age > 99 THEN 'old' END AS bucket)
      )
      """
    Then the result should be, in any order:
      | bucket |
      | null   |
```

Conventions, all inherited from the openCypher TCK:

- **Number the scenario** (`[16]`) sequentially within its file. The number
  is how a bug report cites it, so it must not be reused when a scenario is
  removed.
- **Tag it** with the construct it exercises. Bindings map tags to xfails, so an
  untagged scenario cannot be declared unimplemented by anyone.
- **Let `Background:` set up the graph.** Each feature opens with a
  `CREATE PROPERTY GRAPH` and the tables it maps over. Reuse the existing one in
  the file rather than adding a second graph, unless the scenario is *about* a
  different mapping.
- **`in any order`** unless the scenario is specifically about ordering.
- **One behaviour per scenario.** A scenario that fails should point at one
  thing.

### When the standard is ambiguous

Say so, in a comment above the scenario, naming the reading you assumed:

```gherkin
  # SQL:2023 does not state whether an empty COLUMNS list is an error or
  # yields zero columns. This assumes an error, matching the general SQL rule
  # for an empty select list.
```

An interpretation stated in the open can be argued with; one buried in an
assertion just looks like a fact. Scenarios that encode a contested reading are
still worth having, because they are how the disagreement becomes visible.

## Adding a binding

Create a sibling directory under `implementations/` and implement four steps:

| Step | Meaning |
|---|---|
| `Given property graph "g" with schema:` | execute the given `CREATE PROPERTY GRAPH` DDL |
| `And table "t" with data:` | load the given rows as the named base table |
| `When executing SQL/PGQ:` | run the query, capture rows or the error |
| `Then the result should be, in any order:` | compare rows, ignoring order |

No feature file changes. If you find yourself needing one, that is a finding
worth an issue rather than a patch. `implementations/python/` is a working
example, not a template you have to follow.

Record your binding's baseline in its own README. Comparing counts is the only
reliable way to distinguish a regression you caused from a gap you inherited.

## Running locally

```bash
pip install -e ".[python]"
pip install "prograph @ git+https://gitlab.com/briceg/prograph.git"
pytest
```

One area at a time:

```bash
pytest implementations/python/test_graph_table.py -k substring
```

CI runs the same thing on 3.9, 3.11 and 3.12, plus weekly. The weekly build is
there because the engine under test moves independently of this repo.

## Reporting a divergence

Two engines disagreeing is the signal this suite exists to produce. A good
report names the scenario (`Expressions [15]`), both behaviours, and which one
you believe the standard requires and why. If no scenario covers it yet, the
report and the scenario are the same contribution.

## Licensing

By contributing you agree your contribution is licensed under Apache 2.0, the
same terms as the rest of the repository.
