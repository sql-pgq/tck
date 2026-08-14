"""SQL/PGQ TCK Step Definitions for pytest-bdd.

This module provides step definitions for running SQL/PGQ TCK tests
against the ProGraph implementation.

Supports both Pandas and Spark backends via --backend option:
    pytest --backend=pandas  (default)
    pytest --backend=spark
"""

import os
import pathlib
import re

import pytest
from pytest_bdd import given, when, then, parsers
import pandas as pd

# Import ProGraph implementation
from prograph import ProGraph
from prograph.plan import SQLPGQPlanBuilder
from prograph.schema import GraphSchema, NodeMapping, RelationshipMapping
from prograph.schema.property_graph import PropertyGraphRegistry

# Spark imports (optional)
_spark_session = None


def get_spark_session():
    """Get or create a SparkSession for Spark backend tests."""
    global _spark_session
    if _spark_session is None:
        from pyspark.sql import SparkSession
        _spark_session = SparkSession.builder \
            .appName("SQL-PGQ-TCK") \
            .master("local[*]") \
            .config("spark.driver.memory", "2g") \
            .getOrCreate()
        _spark_session.sparkContext.setLogLevel("WARN")
    return _spark_session


def pandas_to_spark(pdf, spark):
    """Convert pandas DataFrame to Spark DataFrame."""
    return spark.createDataFrame(pdf)


# -----------------------------------------------------------------------------
# Implementation-specific tag handling
# -----------------------------------------------------------------------------
# Every scenario carries a tag naming the construct it exercises. A binding
# whose engine does not implement that construct lists the tag here with a
# reason, and the scenario becomes an xfail instead of a failure.
#
# This table describes ProGraph, not SQL/PGQ. Nothing in it is a statement
# about the standard, and a scenario is never removed from features/ because an
# engine cannot run it, because that would quietly shrink the specification to
# fit the implementation. An entry whose scenario starts passing shows up as XPASS and
# should be deleted.

SKIP_TAGS = set()  # Tags to skip entirely
XFAIL_TAGS = {
    # SQL query surrounding the GRAPH_TABLE
    'OuterOrderBy': 'ORDER BY in outer query not yet implemented',
    'OuterDistinct': 'DISTINCT in outer query not yet implemented',
    'Aggregation': 'SQL aggregation functions not yet implemented',
}


def pytest_bdd_apply_tag(tag, function):
    """Apply pytest markers based on Gherkin tags.

    Note: pytest-bdd ignores the return value - we must modify function in-place.
    """
    if tag in SKIP_TAGS:
        marker = pytest.mark.skip(reason=f"Tag @{tag} is skipped for this implementation")
        marker(function)
    elif tag in XFAIL_TAGS:
        marker = pytest.mark.xfail(reason=XFAIL_TAGS[tag])
        marker(function)


def pytest_addoption(parser):
    """Add command line options for backend selection."""
    parser.addoption(
        "--backend",
        action="store",
        default="pandas",
        choices=["pandas", "spark"],
        help="Backend to use for tests: pandas (default) or spark"
    )


FEATURES_DIR = pathlib.Path(__file__).resolve().parents[2] / "features"
_TAG_RE = re.compile(r"^\s*@(\w+)", re.MULTILINE)


def _feature_tags():
    """Every tag used anywhere in features/.

    pytest-bdd turns each Gherkin tag into a pytest mark, so registering only
    the ones this binding xfails leaves the rest unknown and a clean run warns
    about them. The warnings are harmless and that is the problem: noise on a
    green run is how real warnings get overlooked.
    """
    tags = set()
    for path in FEATURES_DIR.rglob("*.feature"):
        tags.update(_TAG_RE.findall(path.read_text(encoding="utf-8")))
    return tags


def pytest_configure(config):
    """Register the Gherkin tags as markers, and record the backend choice."""
    for tag in sorted(_feature_tags() | SKIP_TAGS | set(XFAIL_TAGS)):
        config.addinivalue_line(
            "markers", f"{tag}: SQL/PGQ TCK scenario tag"
        )
    # Store backend choice for access in fixtures
    config.backend = config.getoption("--backend")


# -----------------------------------------------------------------------------
# Fixtures
# -----------------------------------------------------------------------------

@pytest.fixture
def registry():
    """Fresh property graph registry for each test."""
    return PropertyGraphRegistry()


@pytest.fixture
def builder(registry):
    """SQL/PGQ plan builder with fresh registry."""
    return SQLPGQPlanBuilder(registry)


@pytest.fixture
def context(request):
    """Shared context for passing data between steps."""
    backend = request.config.backend
    return {
        'registry': None,
        'builder': None,
        'engine': None,
        'result': None,
        'error': None,
        'tables': {},
        'schema': None,
        'backend': backend,
    }


# -----------------------------------------------------------------------------
# Given Steps
# -----------------------------------------------------------------------------

@given("an empty property graph registry")
def empty_registry(context, registry, builder):
    """Start with empty registry."""
    context['registry'] = registry
    context['builder'] = builder


@given(parsers.parse('property graph "{name}" with schema:'))
def property_graph_with_schema(context, name, registry, builder, docstring):
    """Create property graph from DDL schema.

    For GRAPH_TABLE tests, we need to register the graph with a ProGraph engine
    that will be used for query execution. We defer engine creation until tables
    are loaded.
    """
    context['registry'] = registry
    context['builder'] = builder
    context['schema_ddl'] = docstring.strip()  # Store for later execution
    # Clear any existing graph with same name (for test isolation)
    if registry.exists(name):
        registry.drop(name)
    builder.build(docstring.strip())  # Also build for DDL-only tests


@given(parsers.parse('property graph "{name}" exists with vertex tables:'))
def existing_property_graph(context, name, registry, builder, datatable):
    """Create an existing property graph."""
    context['registry'] = registry
    context['builder'] = builder
    # Parse table spec from datatable
    tables = []
    if datatable and len(datatable) > 1:
        for row in datatable[1:]:
            if row:
                tables.append(row[0])

    if tables:
        table_list = ', '.join(tables)
        builder.build(f"CREATE PROPERTY GRAPH {name} VERTEX TABLES ({table_list})")


@given(parsers.parse('table "{name}" with data:'))
def table_with_data(context, name, datatable):
    """Create a pandas DataFrame from the data specification."""
    if not datatable or len(datatable) < 2:
        return

    # First row is headers
    headers = list(datatable[0])

    # Parse data rows
    rows = []
    for row in datatable[1:]:
        # Convert numeric strings to appropriate types
        converted = []
        for v in row:
            # Handle null values
            if v is None or (isinstance(v, str) and v.lower() == 'null'):
                converted.append(None)
            else:
                try:
                    converted.append(int(v))
                except (ValueError, TypeError):
                    try:
                        converted.append(float(v))
                    except (ValueError, TypeError):
                        converted.append(v)
        rows.append(converted)

    df = pd.DataFrame(rows, columns=headers)
    context['tables'][name] = df


# -----------------------------------------------------------------------------
# When Steps
# -----------------------------------------------------------------------------

@when("executing SQL/PGQ:")
def execute_sqlpgq(context, docstring):
    """Execute a SQL/PGQ query."""
    query = docstring.strip()
    try:
        builder = context.get('builder')
        if builder:
            plan = builder.build(query)
            context['plan'] = plan

            # If we have tables and a GRAPH_TABLE query, execute it
            if context.get('tables') and 'GRAPH_TABLE' in query.upper():
                # Build schema from registry
                registry = context.get('registry')
                graph_name = _extract_graph_name(query)

                if registry and graph_name and registry.exists(graph_name):
                    defn = registry.get(graph_name)
                    schema = _build_schema_from_definition(defn)

                    # Get backend from context (pandas or spark)
                    backend = context.get('backend', 'pandas')
                    tables = context['tables']

                    # Convert to Spark DataFrames if using Spark backend
                    if backend == 'spark':
                        spark = get_spark_session()
                        tables = {name: pandas_to_spark(df, spark) for name, df in tables.items()}

                    engine = ProGraph(
                        backend=backend,
                        schema=schema,
                        dataframes=tables
                    )
                    context['engine'] = engine

                    # First, register the property graph with the engine's registry
                    schema_ddl = context.get('schema_ddl')
                    if schema_ddl:
                        engine.execute(schema_ddl, language='sqlpgq')

                    # Execute the query
                    result = engine.execute(query, language='sqlpgq')
                    context['result'] = result

        context['error'] = None
    except Exception as e:
        context['error'] = e
        context['result'] = None


# -----------------------------------------------------------------------------
# Then Steps - DDL Assertions
# -----------------------------------------------------------------------------

@then(parsers.parse('the property graph "{name}" should exist'))
def graph_should_exist(context, name):
    """Assert that a property graph exists."""
    registry = context.get('registry')
    builder = context.get('builder')
    if builder:
        registry = builder.registry
    assert registry is not None, "No registry available"
    assert registry.exists(name), f"Property graph '{name}' does not exist"


@then(parsers.parse('the property graph "{name}" should have {count:d} vertex table'))
@then(parsers.parse('the property graph "{name}" should have {count:d} vertex tables'))
def graph_vertex_table_count(context, name, count):
    """Assert vertex table count."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')
    defn = registry.get(name)
    assert len(defn.vertex_tables) == count, \
        f"Expected {count} vertex tables, got {len(defn.vertex_tables)}"


@then(parsers.parse('vertex table "{name}" should have key columns:'))
def vertex_table_key_columns(context, name, datatable):
    """Assert key columns for a vertex table."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')

    # Parse expected columns from datatable (list of lists, first row is header)
    expected = []
    if datatable and len(datatable) > 1:
        for row in datatable[1:]:
            if row:
                expected.append(row[0])

    # Find the vertex table
    for graph_name in ['g']:  # Default graph name
        if registry.exists(graph_name):
            defn = registry.get(graph_name)
            for vt in defn.vertex_tables:
                if vt.table_name == name:
                    assert vt.key_columns == expected, \
                        f"Expected keys {expected}, got {vt.key_columns}"
                    return

    pytest.fail(f"Vertex table '{name}' not found")


@then(parsers.parse('vertex table "{name}" should have label "{label}"'))
def vertex_table_label(context, name, label):
    """Assert label for a vertex table."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')

    for graph_name in ['g']:
        if registry.exists(graph_name):
            defn = registry.get(graph_name)
            for vt in defn.vertex_tables:
                if vt.table_name == name:
                    assert vt.label == label, \
                        f"Expected label '{label}', got '{vt.label}'"
                    return

    pytest.fail(f"Vertex table '{name}' not found")


@then(parsers.parse('vertex table "{name}" should have alias "{alias}"'))
def vertex_table_alias(context, name, alias):
    """Assert alias for a vertex table."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')

    for graph_name in ['g']:
        if registry.exists(graph_name):
            defn = registry.get(graph_name)
            for vt in defn.vertex_tables:
                if vt.table_name == name:
                    assert vt.alias == alias, \
                        f"Expected alias '{alias}', got '{vt.alias}'"
                    return

    pytest.fail(f"Vertex table '{name}' not found")


@then(parsers.parse('vertex table "{name}" should have properties:'))
def vertex_table_properties(context, name, datatable):
    """Assert properties for a vertex table."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')

    # Parse expected properties from datatable
    expected = []
    if datatable and len(datatable) > 1:
        for row in datatable[1:]:
            if row:
                expected.append(row[0])

    for graph_name in ['g']:
        if registry.exists(graph_name):
            defn = registry.get(graph_name)
            for vt in defn.vertex_tables:
                if vt.table_name == name:
                    actual = list(vt.properties.keys())
                    assert set(actual) == set(expected), \
                        f"Expected properties {expected}, got {actual}"
                    return

    pytest.fail(f"Vertex table '{name}' not found")


@then(parsers.parse('vertex table "{name}" should have property mapping:'))
def vertex_table_property_mapping(context, name, datatable):
    """Assert property-to-column mapping for a vertex table."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')

    # Parse expected mapping from datatable (property, column)
    expected = {}
    if datatable and len(datatable) > 1:
        for row in datatable[1:]:
            if len(row) >= 2:
                expected[row[0]] = row[1]

    for graph_name in ['g']:
        if registry.exists(graph_name):
            defn = registry.get(graph_name)
            for vt in defn.vertex_tables:
                if vt.table_name == name:
                    for prop, col in expected.items():
                        assert vt.properties.get(prop) == col, \
                            f"Expected {prop} -> {col}, got {vt.properties.get(prop)}"
                    return

    pytest.fail(f"Vertex table '{name}' not found")


@then("no error should be raised")
def no_error(context):
    """Assert no error occurred."""
    assert context.get('error') is None, f"Unexpected error: {context.get('error')}"


# -----------------------------------------------------------------------------
# Then Steps - Edge Table DDL Assertions
# -----------------------------------------------------------------------------

@then(parsers.parse('the property graph "{name}" should have {count:d} edge table'))
@then(parsers.parse('the property graph "{name}" should have {count:d} edge tables'))
def graph_edge_table_count(context, name, count):
    """Assert edge table count."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')
    defn = registry.get(name)
    assert len(defn.edge_tables) == count, \
        f"Expected {count} edge tables, got {len(defn.edge_tables)}"


@then(parsers.parse('edge table "{name}" should have label "{label}"'))
def edge_table_label(context, name, label):
    """Assert label for an edge table."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')

    for graph_name in ['g']:
        if registry.exists(graph_name):
            defn = registry.get(graph_name)
            for et in defn.edge_tables:
                if et.table_name == name:
                    assert et.label == label, \
                        f"Expected label '{label}', got '{et.label}'"
                    return

    pytest.fail(f"Edge table '{name}' not found")


@then(parsers.parse('edge table "{name}" should have properties:'))
def edge_table_properties(context, name, datatable):
    """Assert properties for an edge table."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')

    # Parse expected properties from datatable
    expected = []
    if datatable and len(datatable) > 1:
        for row in datatable[1:]:
            if row:
                expected.append(row[0])

    for graph_name in ['g']:
        if registry.exists(graph_name):
            defn = registry.get(graph_name)
            for et in defn.edge_tables:
                if et.table_name == name:
                    actual = list(et.properties.keys()) if et.properties else []
                    assert set(actual) == set(expected), \
                        f"Expected properties {expected}, got {actual}"
                    return

    pytest.fail(f"Edge table '{name}' not found")


@then(parsers.parse('edge table "{name}" should have property mapping:'))
def edge_table_property_mapping(context, name, datatable):
    """Assert property-to-column mapping for an edge table."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')

    # Parse expected mapping from datatable (property, column)
    expected = {}
    if datatable and len(datatable) > 1:
        for row in datatable[1:]:
            if len(row) >= 2:
                expected[row[0]] = row[1]

    for graph_name in ['g']:
        if registry.exists(graph_name):
            defn = registry.get(graph_name)
            for et in defn.edge_tables:
                if et.table_name == name:
                    for prop, col in expected.items():
                        actual_col = et.properties.get(prop) if et.properties else None
                        assert actual_col == col, \
                            f"Expected {prop} -> {col}, got {actual_col}"
                    return

    pytest.fail(f"Edge table '{name}' not found")


@then(parsers.parse('edge table "{name}" should have source reference "{ref}"'))
def edge_table_source_reference(context, name, ref):
    """Assert source reference for an edge table."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')

    for graph_name in ['g']:
        if registry.exists(graph_name):
            defn = registry.get(graph_name)
            for et in defn.edge_tables:
                if et.table_name == name:
                    assert et.source_ref == ref, \
                        f"Expected source ref '{ref}', got '{et.source_ref}'"
                    return

    pytest.fail(f"Edge table '{name}' not found")


@then(parsers.parse('edge table "{name}" should have destination reference "{ref}"'))
def edge_table_destination_reference(context, name, ref):
    """Assert destination reference for an edge table."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')

    for graph_name in ['g']:
        if registry.exists(graph_name):
            defn = registry.get(graph_name)
            for et in defn.edge_tables:
                if et.table_name == name:
                    assert et.dest_ref == ref, \
                        f"Expected dest ref '{ref}', got '{et.dest_ref}'"
                    return

    pytest.fail(f"Edge table '{name}' not found")


@then(parsers.parse('edge table "{name}" should have source columns:'))
def edge_table_source_columns(context, name, datatable):
    """Assert source columns for an edge table."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')

    # Parse expected columns from datatable
    expected = []
    if datatable and len(datatable) > 1:
        for row in datatable[1:]:
            if row:
                expected.append(row[0])

    for graph_name in ['g']:
        if registry.exists(graph_name):
            defn = registry.get(graph_name)
            for et in defn.edge_tables:
                if et.table_name == name:
                    assert et.source_columns == expected, \
                        f"Expected source columns {expected}, got {et.source_columns}"
                    return

    pytest.fail(f"Edge table '{name}' not found")


@then(parsers.parse('edge table "{name}" should have no properties'))
def edge_table_no_properties(context, name):
    """Assert edge table has no properties."""
    builder = context.get('builder')
    registry = builder.registry if builder else context.get('registry')

    for graph_name in ['g']:
        if registry.exists(graph_name):
            defn = registry.get(graph_name)
            for et in defn.edge_tables:
                if et.table_name == name:
                    props = et.properties if et.properties else {}
                    assert len(props) == 0, \
                        f"Expected no properties, got {props}"
                    return

    pytest.fail(f"Edge table '{name}' not found")


# -----------------------------------------------------------------------------
# Then Steps - Query Result Assertions
# -----------------------------------------------------------------------------

@then("the result should be, in any order:")
def result_in_any_order(context, datatable):
    """Assert query results match expected (order-independent)."""
    result = context.get('result')
    assert result is not None, "No result available"

    # Parse expected rows from datatable
    expected_rows = []
    if datatable and len(datatable) > 1:
        headers = datatable[0]
        for row in datatable[1:]:
            row_dict = {}
            for h, v in zip(headers, row):
                # Try to convert to appropriate type
                try:
                    row_dict[h] = int(v)
                except (ValueError, TypeError):
                    try:
                        row_dict[h] = float(v)
                    except (ValueError, TypeError):
                        row_dict[h] = v
            expected_rows.append(row_dict)

    # Convert result to comparable format
    actual_rows = [dict(row) for row in result]

    # Sort both for comparison
    def row_key(row):
        return tuple(sorted(str(v) for v in row.values()))

    actual_sorted = sorted(actual_rows, key=row_key)
    expected_sorted = sorted(expected_rows, key=row_key)

    assert len(actual_sorted) == len(expected_sorted), \
        f"Expected {len(expected_sorted)} rows, got {len(actual_sorted)}"

    for actual, exp in zip(actual_sorted, expected_sorted):
        for key in exp:
            assert key in actual, f"Missing column '{key}' in result"
            # Handle type coercion for comparison
            actual_val = actual[key]
            expected_val = exp[key]
            if isinstance(expected_val, (int, float)) and isinstance(actual_val, (int, float)):
                assert actual_val == expected_val, \
                    f"Column '{key}': expected {expected_val}, got {actual_val}"
            # Handle null comparison (Python None vs 'null' string in feature files)
            elif expected_val == 'null' or str(expected_val).lower() == 'null':
                assert actual_val is None, \
                    f"Column '{key}': expected null, got {actual_val}"
            elif actual_val is None:
                assert expected_val == 'null' or str(expected_val).lower() == 'null', \
                    f"Column '{key}': expected {expected_val}, got null"
            else:
                assert str(actual_val) == str(expected_val), \
                    f"Column '{key}': expected {expected_val}, got {actual_val}"


@then("the result should be empty")
def result_empty(context):
    """Assert query returned no results."""
    result = context.get('result')
    assert result is not None, "No result available"
    assert len(result) == 0, f"Expected empty result, got {len(result)} rows"


# The three steps below assert *properties* of a column rather than its values.
# They exist for constructs whose result the standard leaves to the
# implementation, ELEMENT_ID being the case in point: a conformance suite may
# require that an element id is present, and stable, and distinguishes distinct
# elements, but it must not require any particular id. Pinning a literal there
# would test ProGraph rather than SQL/PGQ.

@then(parsers.parse("the result should have {count:d} row"))
@then(parsers.parse("the result should have {count:d} rows"))
def result_row_count(context, count):
    """Assert the number of rows without constraining their values."""
    result = context.get('result')
    assert result is not None, "No result available"
    assert len(result) == count, f"Expected {count} rows, got {len(result)}"


@then(parsers.parse('column "{column}" should have no nulls'))
def column_no_nulls(context, column):
    result = context.get('result')
    assert result is not None, "No result available"
    assert result, "No rows to check"
    missing = [r for r in result if column not in r]
    assert not missing, f"Column '{column}' absent from {len(missing)} rows"
    nulls = [r for r in result if r[column] is None]
    assert not nulls, f"Column '{column}' was null in {len(nulls)} of {len(result)} rows"


@then(parsers.parse('column "{column}" should have {count:d} distinct values'))
def column_distinct_count(context, column, count):
    result = context.get('result')
    assert result is not None, "No result available"
    values = {str(r.get(column)) for r in result}
    assert len(values) == count, \
        f"Column '{column}': expected {count} distinct values, got {len(values)} ({sorted(values)})"


# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

def _parse_column_list(spec, column_name='column'):
    """Parse a column list from Gherkin table format."""
    columns = []
    for line in spec.strip().split('\n'):
        if '|' in line:
            parts = [p.strip() for p in line.split('|') if p.strip()]
            if parts and parts[0] != column_name:
                columns.append(parts[0])
    return columns


def _parse_property_mapping(spec):
    """Parse property-to-column mapping from Gherkin table format."""
    mapping = {}
    lines = spec.strip().split('\n')
    for line in lines:
        if '|' in line:
            parts = [p.strip() for p in line.split('|') if p.strip()]
            if len(parts) >= 2 and parts[0] != 'property':
                mapping[parts[0]] = parts[1]
    return mapping


def _parse_result_table(spec):
    """Parse expected result table from Gherkin format."""
    lines = [l for l in spec.strip().split('\n') if l.strip()]

    # Parse header
    header_line = lines[0]
    headers = [h.strip() for h in header_line.split('|') if h.strip()]

    # Parse data rows
    rows = []
    for line in lines[1:]:
        if '|' in line:
            values = [v.strip() for v in line.split('|') if v.strip()]
            if values and len(values) == len(headers):
                row = {}
                for h, v in zip(headers, values):
                    # Try to convert to appropriate type
                    try:
                        row[h] = int(v)
                    except ValueError:
                        try:
                            row[h] = float(v)
                        except ValueError:
                            row[h] = v
                rows.append(row)

    return rows


def _extract_graph_name(query):
    """Extract graph name from GRAPH_TABLE query."""
    import re
    match = re.search(r'GRAPH_TABLE\s*\(\s*(\w+)', query, re.IGNORECASE)
    return match.group(1) if match else None


def _build_schema_from_definition(defn):
    """Build GraphSchema from PropertyGraphDefinition."""
    schema = GraphSchema()

    for vt in defn.vertex_tables:
        # Determine ID column
        id_col = vt.key_columns[0] if vt.key_columns else 'id'

        # Build property columns
        prop_cols = {}
        if vt.properties:
            for prop_name, col_name in vt.properties.items():
                prop_cols[prop_name] = col_name if col_name else prop_name

        schema.add_node_mapping(NodeMapping(
            source_table=vt.table_name,
            label=vt.label or vt.table_name,
            id_column=id_col,
            property_columns=prop_cols
        ))

    for et in defn.edge_tables:
        # Find the source vertex table to get its label
        source_label = et.source_ref  # Default to table name
        dest_label = et.dest_ref
        for vt in defn.vertex_tables:
            if vt.table_name == et.source_ref:
                source_label = vt.label or vt.table_name
            if vt.table_name == et.dest_ref:
                dest_label = vt.label or vt.table_name

        schema.add_relationship_mapping(RelationshipMapping(
            source_table=et.table_name,
            rel_type=et.label or et.table_name.upper(),
            start_node_label=source_label,
            start_id_column=et.source_columns[0] if et.source_columns else 'src',
            end_node_label=dest_label,
            end_id_column=et.dest_columns[0] if et.dest_columns else 'dst',
            property_columns=et.properties or {}
        ))

    return schema
