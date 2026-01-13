# SQL/PGQ Technology Compatibility Kit (TCK)

A community-driven test suite for SQL/PGQ (SQL:2023 Property Graph Queries) implementations.

## Overview

SQL/PGQ is Part 16 of the SQL:2023 standard (ISO/IEC 9075-16), adding property graph query capabilities to SQL. This TCK provides executable specifications to verify implementation conformance.

**Status**: Early development / Tracer bullet phase

## Structure

```
sql-pgq-tck/
├── features/                    # Gherkin feature files (the specification)
│   ├── ddl/                     # CREATE/DROP PROPERTY GRAPH
│   ├── graph_table/             # GRAPH_TABLE queries
│   ├── expressions/             # Comparisons, predicates, functions
│   └── clauses/                 # WHERE, ORDER BY, COLUMNS
├── implementations/             # Step definitions per language/system
│   └── python/                  # pytest-bdd implementation
└── docs/                        # Documentation
```

## Running Tests

### Python (pytest-bdd)

```bash
cd sql-pgq-tck/implementations/python
pip install pytest pytest-bdd
pytest -v
```

## Feature Coverage

| Category | Features | Status |
|----------|----------|--------|
| DDL | CREATE/DROP PROPERTY GRAPH | Tracer |
| Node Patterns | Labels, variables, filters | Tracer |
| Edge Patterns | Directions, labels, quantifiers | Tracer |
| Expressions | Comparisons, predicates | Tracer |
| Clauses | WHERE, ORDER BY, COLUMNS | Planned |
| Path Patterns | Variables, quantifiers, functions | Planned |
| Literals | Strings, numbers, booleans, null | Planned |

## Design Principles

1. **Language-agnostic**: Feature files are pure Gherkin; implementations provide step definitions
2. **Spec-aligned**: Tests reflect SQL:2023 Part 16 where possible
3. **Incremental**: Start with core features, expand based on implementation feedback
4. **Executable documentation**: Features serve as both tests and specification

## Contributing

See [CONTRIBUTING.md](docs/CONTRIBUTING.md) for guidelines.

## License

Apache License 2.0 (following openCypher TCK precedent)

## Acknowledgments

Inspired by the [openCypher TCK](https://github.com/opencypher/openCypher/tree/master/tck).
