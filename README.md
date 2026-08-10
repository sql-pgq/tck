# SQL/PGQ Technology Compatibility Kit (TCK)

A test suite for SQL/PGQ (SQL:2023 Property Graph Queries) implementations.

## Overview

SQL/PGQ is Part 16 of the SQL:2023 standard (ISO/IEC 9075-16), adding property
graph query capabilities to SQL. This TCK provides executable specifications to
verify implementation conformance.

**Status**: Early development. The feature files cover a usable slice of
`GRAPH_TABLE` and property-graph DDL, not the standard — see
[Coverage](#coverage) for what exists and what does not. Treat a passing run as
"conforms on the covered subset", never as "conforms to SQL/PGQ".

## Structure

```
features/                     # Gherkin feature files — the specification
├── ddl/                      # CREATE PROPERTY GRAPH
└── graph_table/              # GRAPH_TABLE queries, expressions, quantifiers
implementations/              # Step definitions, one per language/system
└── python/                   # pytest-bdd, currently bound to ProGraph
```

The split matters: **`features/` is the artifact**. It is pure Gherkin with no
engine in it, so a second implementation adds a sibling under
`implementations/` and reuses every scenario unchanged.

## Running

```bash
pip install -e ".[python]"      # pytest, pytest-bdd, pandas
pip install prograph            # the engine the reference binding drives
pytest
```

`pytest` from the repo root picks up `implementations/python` via
`pyproject.toml`. To run one area:

```bash
pytest implementations/python/test_graph_table.py -k substring
```

### Bindings and the engine under test

The Python binding currently drives [ProGraph](https://gitlab.com/briceg/prograph)
directly — `conftest.py` imports `prograph` and builds a `ProGraph` engine per
scenario. That is a property of the *binding*, not of the TCK: the engine is not
a dependency of this project, which is why it is an optional extra rather than a
hard requirement. Pointing the suite at another SQL/PGQ implementation means
writing a new binding, not editing the features.

### Scenarios a run is allowed to skip

`conftest.py` carries a table of tags mapped to "not yet implemented" reasons,
applied as xfail. That table describes **the binding's engine**, not the
standard — an implementation that supports a construct should delete its entry
and watch the scenario pass. Keeping the list explicit is the point: a silently
skipped conformance test reads exactly like a passing one.

## Coverage

| Category | Feature files | Status |
|---|---|---|
| DDL | `CreatePropertyGraph1/2` | Tracer |
| Node patterns | `NodePatterns1/2` | Tracer |
| Edge patterns | `EdgePatterns1/2` | Tracer |
| Expressions | `Expressions` | Tracer |
| Aggregations | `Aggregations` | Tracer |
| Path quantifiers | `PathQuantifiers` | Tracer |
| Clauses (WHERE, ORDER BY, COLUMNS) | — | Planned |
| Literals | — | Planned |

## Baseline

Against ProGraph at the time of the split: **85 passed, 13 xfailed, 1 xpassed**.

An xpassed scenario is a tag in the skip table whose engine caught up — the
entry should be removed. Record the baseline whenever you change bindings;
comparing counts is the only way to tell a new failure from an inherited one.

## Design principles

1. **Language-agnostic** — feature files are pure Gherkin; implementations
   provide step definitions.
2. **Spec-aligned** — scenarios reflect SQL:2023 Part 16 where possible, and say
   so when they encode an interpretation rather than the text.
3. **Incremental** — start with core features, expand on implementation feedback.
4. **Honest about scope** — the coverage table above is the claim; nothing
   broader is implied by a green run.

## History

Extracted from the [ProGraph](https://gitlab.com/briceg/prograph) repository,
where it began as a tracer bullet. Commit history is preserved.

## License

Apache License 2.0 (following the openCypher TCK precedent).

## Acknowledgments

Inspired by the [openCypher TCK](https://github.com/opencypher/openCypher/tree/master/tck).
