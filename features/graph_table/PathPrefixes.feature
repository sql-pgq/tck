#
# SQL/PGQ TCK - Path Prefixes
#
# A path pattern may be prefixed with ALL, ANY, ALL SHORTEST, ANY SHORTEST or
# SHORTEST k, which says how many of the matching paths between a pair of
# endpoints to return. ALL is the default and returns every path; the others
# reduce that set.
#
# The graph gives Alice two routes to Carol, one hop direct and two hops via
# Bob, so a prefix that is parsed and ignored returns two rows where one is
# required. Without that second route every prefix would agree and the
# scenarios would pass without testing anything.
#

Feature: PathPrefixes - Choosing how many matching paths to return

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
      | 4  | Dave  |
    And table "knows" with data:
      | src | dst |
      | 1   | 2   |
      | 2   | 3   |
      | 3   | 4   |
      | 1   | 3   |

  @PathPrefixAll
  Scenario: [1] ALL returns every path between the endpoints
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH ALL (a:Person)-[:KNOWS{1,2}]->(b:Person)
        WHERE a.name = 'Alice' AND b.name = 'Carol'
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should have 2 rows

  @PathPrefixAll
  Scenario: [2] ALL over a single hop is the whole edge set
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH ALL (a:Person)-[:KNOWS]->(b:Person)
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should be, in any order:
      | a     | b     |
      | Alice | Bob   |
      | Alice | Carol |
      | Bob   | Carol |
      | Carol | Dave  |

  @PathPrefixAll
  Scenario: [3] Omitting the prefix behaves as ALL
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS{1,2}]->(b:Person)
        WHERE a.name = 'Alice' AND b.name = 'Carol'
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should have 2 rows

  @PathPrefixAny
  Scenario: [4] ANY returns one path per endpoint pair
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH ANY (a:Person)-[:KNOWS{1,2}]->(b:Person)
        WHERE a.name = 'Alice' AND b.name = 'Carol'
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should have 1 row

  @PathPrefixAnySingleHop
  Scenario: [5] ANY over a single hop cannot reduce anything
    # One path exists per pair at one hop, so ANY and ALL must agree here. This
    # is the control for scenario [4], and it carries its own tag because it
    # passes even against an engine that ignores the prefix entirely. That is
    # the point of it: on its own it would be evidence of nothing.
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH ANY (a:Person)-[:KNOWS]->(b:Person)
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should be, in any order:
      | a     | b     |
      | Alice | Bob   |
      | Alice | Carol |
      | Bob   | Carol |
      | Carol | Dave  |

  @PathPrefixShortest
  Scenario: [6] ALL SHORTEST keeps only the shortest paths
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH ALL SHORTEST (a:Person)-[:KNOWS{1,2}]->(b:Person)
        WHERE a.name = 'Alice' AND b.name = 'Carol'
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should have 1 row

  @PathPrefixShortest
  Scenario: [7] ANY SHORTEST returns a single shortest path
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH ANY SHORTEST (a:Person)-[:KNOWS{1,2}]->(b:Person)
        WHERE a.name = 'Alice' AND b.name = 'Carol'
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should have 1 row

  @PathPrefixShortest
  Scenario: [8] SHORTEST k bounds how many paths are returned
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH SHORTEST 1 (a:Person)-[:KNOWS{1,2}]->(b:Person)
        WHERE a.name = 'Alice' AND b.name = 'Carol'
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should have 1 row
