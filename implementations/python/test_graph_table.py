"""SQL/PGQ TCK - GRAPH_TABLE Tests.

This module runs the GRAPH_TABLE feature files (node patterns, edge patterns).
"""

from pytest_bdd import scenarios

# Import step definitions from conftest
from conftest import *  # noqa: F401, F403

# Load all GRAPH_TABLE scenarios
scenarios('../../features/graph_table/NodePatterns1.feature')
scenarios('../../features/graph_table/EdgePatterns1.feature')
