"""SQL/PGQ TCK - DDL Tests.

Runs every feature file under ``features/ddl/``. The directory is passed to
``scenarios()`` for the reason given in ``test_graph_table.py``.
"""

from pytest_bdd import scenarios

# Import step definitions from conftest
from conftest import *  # noqa: F401, F403

scenarios('../../features/ddl')
