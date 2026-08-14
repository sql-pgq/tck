# SQL/PGQ TCK

[![TCK](https://github.com/sql-pgq/tck/actions/workflows/tck.yml/badge.svg)](https://github.com/sql-pgq/tck/actions/workflows/tck.yml)

A Technology Compatibility Kit for **SQL/PGQ**: SQL:2023 Part 16 (ISO/IEC
9075-16), the property-graph query extension to SQL.

The suite is a set of executable scenarios written in Gherkin. Each one states a
property graph, a query, and the rows the query must return. Nothing in
`features/` knows what engine will run it.

## Why this exists

SQL/PGQ is being implemented independently and roughly simultaneously by
warehouses, relational databases and virtual-graph layers. The standard is a
document behind a paywall; there is no shared, executable statement of what
`GRAPH_TABLE` actually does.

That is the condition dialects grow in. Two engines read the same clause, reach
defensible but different conclusions, ship, and by the time anyone compares
them the difference is load-bearing in someone's production query. The
divergences that matter are rarely the dramatic ones. They are off-by-ones in
`SUBSTRING`, disagreements about whether an unmatched optional pattern drops the
row, edge direction on an undirected pattern. Small, plausible, and invisible
without a shared test.

A TCK does not prevent that by authority. It has none. It works by making
disagreement *cheap to discover*: an implementer runs the suite, sees a red
scenario, and finds out in an afternoon rather than from a bug report two years
later.

**This suite is small.** It covers a usable slice of `GRAPH_TABLE` and
property-graph DDL, not the standard. See [Coverage](#coverage) for exactly
what exists. A green run means "conforms on the covered subset" and never
"conforms to SQL/PGQ", and the coverage table is the claim, so please read it
before quoting a pass rate.

## Modeled on the openCypher TCK

The [openCypher TCK](https://github.com/opencypher/openCypher/tree/master/tck)
solved this problem for Cypher, and it solved it well enough that copying its
structure was the obvious move. The borrowings are deliberate:

**The specification is separate from anything that runs it.** openCypher keeps
pure Gherkin in `tck/features/` and leaves step definitions to implementers.
Here, `features/` is the artifact and every binding lives under
`implementations/`. This is the load-bearing decision: it is what lets a second
implementation adopt the suite by writing a binding rather than by forking, and
it is why a scenario is never deleted because some engine cannot pass it.

**Scenarios are numbered within a feature.** `Scenario: [1] Arithmetic addition
in COLUMNS`, matching openCypher's `Scenario: [1] Match non-existent nodes
returns empty`. Numbering gives a scenario a stable name to cite in a bug
report, independent of its wording.

**Feature files are grouped by construct and numbered when they grow.**
openCypher has `Match1.feature` through `Match9.feature`; this has
`NodePatterns1/2`, `EdgePatterns1/2`, `CreatePropertyGraph1/2`. Files stay
readable and a new area is a new file, not an edit to a large one.

**Results are compared unordered by default.** The step is spelled exactly as
openCypher spells it, `Then the result should be, in any order:`, so that
ordering is asserted only where a scenario means to assert it.

**Apache 2.0**, following the same precedent.

Where it differs, it differs because SQL/PGQ is not Cypher:

- openCypher scenarios start from `Given an empty graph` and build with Cypher
  `CREATE`. SQL/PGQ has no such literal: a graph is a *view over base tables*.
  So each feature opens with a `Background:` holding a
  `CREATE PROPERTY GRAPH` statement and the tables it maps over, which makes the
  table-to-graph mapping part of the specification rather than setup hidden in a
  fixture.
- There is no `And no side effects` step. The covered subset is read-only:
  SQL/PGQ as standardised has no graph mutation of its own.
- Bindings live in this repository rather than only in implementers' trees, so
  that at least one runnable example of a binding ships with the suite.

## Layout

```
features/                     # the specification: pure Gherkin, no engine
├── ddl/                      # CREATE PROPERTY GRAPH
└── graph_table/              # GRAPH_TABLE queries, expressions, quantifiers
implementations/              # bindings, one per language or system
└── python/                   # pytest-bdd, currently driving ProGraph
```

## Running

```bash
pip install -e ".[python]"                                   # pytest, pytest-bdd, pandas
pip install "prograph @ git+https://gitlab.com/briceg/prograph.git"   # the engine the binding drives
pytest
```

ProGraph is not on PyPI yet, hence the source install; it is not a dependency of
this package and nothing but the Python binding needs it.

`pytest` from the repo root picks up `implementations/python` via
`pyproject.toml`. To run one area:

```bash
pytest implementations/python/test_graph_table.py -k substring
```

The Python binding takes `--backend=pandas` (default) or `--backend=spark`.

### The engine under test

The Python binding drives [ProGraph](https://gitlab.com/briceg/prograph):
`conftest.py` imports `prograph` and builds an engine per scenario. That is a
property of *the binding*, which is why the engine is an optional extra rather
than a dependency. A second implementation's binding should not have to install
the first one's engine to run the suite.

### Scenarios a run is allowed to skip

Every scenario carries a tag naming the construct it exercises
(`@PathQuantifier`, `@CaseExpression`, …). A binding lists tags its engine does
not implement in `XFAIL_TAGS`, with a reason, and those scenarios become xfails
instead of failures.

That table describes **the engine**, not the standard. Keeping the list explicit
and small is the point: a silently skipped conformance test reads exactly like a
passing one, which is the failure mode a TCK exists to prevent. `xfail_strict`
is on, so an entry whose scenario starts passing fails the build until the entry
is removed. The list is not allowed to accumulate claims that stopped being
true.

## Writing a binding

Add a sibling directory under `implementations/` and implement the steps the
features use. There are four:

| Step | Meaning |
|---|---|
| `Given property graph "g" with schema:` | execute the given `CREATE PROPERTY GRAPH` DDL |
| `And table "t" with data:` | load the given rows as the named base table |
| `When executing SQL/PGQ:` | run the query, capture rows or the error |
| `Then the result should be, in any order:` | compare rows, ignoring order |

No feature file changes. If a scenario cannot be expressed against your engine,
that is a finding worth opening an issue about, because it usually means the
scenario encodes an interpretation that deserves to be argued in public.

## Coverage

140 scenarios (142 tests, after one `Scenario Outline` expands).

| Area | Files | Scenarios |
|---|---|---|
| Property-graph DDL | `CreatePropertyGraph1/2`, `PropertiesClause` | 28 |
| Node patterns | `NodePatterns1/2` | 20 |
| Edge patterns | `EdgePatterns1/2` | 20 |
| Expressions and functions | `Expressions` | 15 |
| Label expressions | `LabelExpressions` | 13 |
| Path quantifiers | `PathQuantifiers` | 12 |
| Aggregation | `Aggregations` | 10 |
| Path prefixes | `PathPrefixes` | 8 |
| Element WHERE | `ElementWhere` | 7 |
| Path functions | `PathFunctions` | 7 |

Known to be absent, listed so the gaps are visible rather than merely unmet:

- `ONE ROW PER MATCH` / `ONE ROW PER VERTEX` / `ONE ROW PER STEP`
- Path modes: `TRAIL`, `ACYCLIC`, `SIMPLE`
- `IS LABELED`
- Literals and the type system as a category of their own
- Anything in the outer SQL query beyond the handful of tagged scenarios

## Baseline

Against ProGraph, at the time of writing: **125 passed, 17 xfailed, 0 failed.**

The xfails that remain are worth reading. They are not unimplemented syntax
that raises; they are constructs the engine parses and then discards, so the
query is accepted, nothing is raised, and the answer is wrong: a reducing path
prefix returns every path. A scenario is the only thing that tells that apart
from working, which is the argument for this suite in one paragraph.

The element `WHERE` and the path functions were both in that list when these
scenarios were written, and both now pass. That is the intended life cycle: a
gap becomes visible, then it becomes a passing test.

Record the equivalent number for your binding. Comparing counts is the only
reliable way to tell a regression you introduced from a gap you inherited.

## Contributing

Scenarios are the contribution that matters most, particularly in the areas
listed as absent above. Bug reports citing a scenario number and a failing
engine are the second most useful thing.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the conventions and for the one rule
the suite depends on: a scenario is never deleted or weakened because an engine
cannot pass it.

## History

Extracted with `git subtree split` from the
[ProGraph](https://gitlab.com/briceg/prograph) repository, where it began as a
tracer bullet for SQL/PGQ conformance. Commit history is preserved.

## License

Apache License 2.0. See [LICENSE](LICENSE).

## Acknowledgments

The [openCypher TCK](https://github.com/opencypher/openCypher/tree/master/tck),
for the structure and for demonstrating that a shared executable specification
is worth the trouble.
