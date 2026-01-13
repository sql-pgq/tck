"""SQL/PGQ TCK Step Definitions for pytest-bdd.

This module provides step definitions for running SQL/PGQ TCK tests
against the ProGraph implementation.
"""

import pytest
from pytest_bdd import given, when, then, parsers
import pandas as pd

# Import ProGraph implementation
from prograph import ProGraph
from prograph.plan import SQLPGQPlanBuilder
from prograph.schema import GraphSchema, NodeMapping, RelationshipMapping
from prograph.schema.property_graph import PropertyGraphRegistry


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
def context():
    """Shared context for passing data between steps."""
    return {
        'registry': None,
        'builder': None,
        'engine': None,
        'result': None,
        'error': None,
        'tables': {},
        'schema': None,
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

                    engine = ProGraph(
                        backend='pandas',
                        schema=schema,
                        dataframes=context['tables']
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
            else:
                assert str(actual_val) == str(expected_val), \
                    f"Column '{key}': expected {expected_val}, got {actual_val}"


@then("the result should be empty")
def result_empty(context):
    """Assert query returned no results."""
    result = context.get('result')
    assert result is not None, "No result available"
    assert len(result) == 0, f"Expected empty result, got {len(result)} rows"


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
        schema.add_relationship_mapping(RelationshipMapping(
            source_table=et.table_name,
            rel_type=et.label or et.table_name.upper(),
            start_node_label=et.source_table,
            start_id_column=et.source_key[0] if et.source_key else 'src',
            end_node_label=et.dest_table,
            end_id_column=et.dest_key[0] if et.dest_key else 'dst',
            property_columns=et.properties or {}
        ))

    return schema
