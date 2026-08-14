"""SQL/PGQ TCK - GRAPH_TABLE Tests.

Runs every feature file under ``features/graph_table/``.

The directory is passed to ``scenarios()`` rather than each file being listed,
so adding a feature file is enough to have it run. Listing them individually
meant a new file was collected by nobody and reported by nothing, which reads
exactly like a passing run: the failure mode this suite exists to prevent.
"""

from pytest_bdd import scenarios

# Import step definitions from conftest
from conftest import *  # noqa: F401, F403

scenarios('../../features/graph_table')
