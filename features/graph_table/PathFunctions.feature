#
# SQL/PGQ TCK - Path Functions
#
# A path pattern may be named, `p = (a)-[:KNOWS]->(b)`, and the name then given
# to PATH_LENGTH, VERTICES or EDGES. ELEMENT_ID takes an element variable
# rather than a path.
#
# ELEMENT_ID's value is implementation-dependent, so these scenarios assert
# what the standard fixes about it, that it is present and distinguishes
# distinct elements, and not any particular id. Asserting a literal there would
# test one engine rather than the standard.
#

Feature: PathFunctions - Naming a path and asking about it

  Background:
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person PROPERTIES (id, name)
      )
      EDGE TABLES (
        knows SOURCE KEY (src) REFERENCES persons (id)
              DESTINATION KEY (dst) REFERENCES persons (id)
              LABEL KNOWS
      )
      """
    And table "persons" with data:
      | id | name  |
      | 1  | Alice |
      | 2  | Bob   |
      | 3  | Carol |
    And table "knows" with data:
      | src | dst |
      | 1   | 2   |
      | 2   | 3   |

  @NamedPath
  Scenario: [1] A path may be named without being asked about
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH p = (a:Person)-[:KNOWS]->(b:Person)
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should be, in any order:
      | a     | b     |
      | Alice | Bob   |
      | Bob   | Carol |

  @PathLength
  Scenario: [2] PATH_LENGTH counts the edges of a one-hop path
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH p = (a:Person)-[:KNOWS]->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (PATH_LENGTH(p) AS len)
      )
      """
    Then the result should be, in any order:
      | len |
      | 1   |

  @PathLength
  Scenario: [3] PATH_LENGTH reports each path's own length
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH p = (a:Person)-[:KNOWS{1,2}]->(b:Person)
        WHERE a.name = 'Alice' AND b.name = 'Carol'
        COLUMNS (PATH_LENGTH(p) AS len)
      )
      """
    Then the result should be, in any order:
      | len |
      | 2   |

  @PathVertices
  Scenario: [4] VERTICES yields the path's endpoints
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH p = (a:Person)-[:KNOWS]->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (VERTICES(p) AS vs)
      )
      """
    Then the result should have 1 row
    And column "vs" should have no nulls

  @PathEdges
  Scenario: [5] EDGES yields the path's edges
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH p = (a:Person)-[:KNOWS]->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (EDGES(p) AS es)
      )
      """
    Then the result should have 1 row
    And column "es" should have no nulls

  @ElementId
  Scenario: [6] ELEMENT_ID is present for every matched element
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:Person)
        COLUMNS (ELEMENT_ID(n) AS eid)
      )
      """
    Then the result should have 3 rows
    And column "eid" should have no nulls

  @ElementId
  Scenario: [7] ELEMENT_ID distinguishes distinct elements
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:Person)
        COLUMNS (ELEMENT_ID(n) AS eid)
      )
      """
    Then column "eid" should have 3 distinct values
