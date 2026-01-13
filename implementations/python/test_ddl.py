"""SQL/PGQ TCK - DDL Tests.

This module runs the DDL feature files (CREATE/DROP PROPERTY GRAPH).
"""

from pytest_bdd import scenarios

# Import step definitions from conftest
from conftest import *  # noqa: F401, F403

# Load all DDL scenarios
scenarios('../../features/ddl/CreatePropertyGraph1.feature')
