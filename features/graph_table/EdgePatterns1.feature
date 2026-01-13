#
# SQL/PGQ TCK - Edge Patterns
#
# Tests for edge pattern matching in GRAPH_TABLE queries
#

Feature: EdgePatterns1 - Basic edge pattern matching

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
              LABEL KNOWS PROPERTIES (since)
      )
      """
    And table "persons" with data:
      | id | name    |
      | 1  | Alice   |
      | 2  | Bob     |
      | 3  | Charlie |
    And table "knows" with data:
      | src | dst | since |
      | 1   | 2   | 2020  |
      | 2   | 3   | 2021  |
      | 1   | 3   | 2019  |

  Scenario: [1] Match edge with right arrow direction
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[k:KNOWS]->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (a.name AS src, b.name AS dst)
      )
      """
    Then the result should be, in any order:
      | src   | dst     |
      | Alice | Bob     |
      | Alice | Charlie |

  Scenario: [2] Match edge with left arrow direction
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)<-[k:KNOWS]-(b:Person)
        WHERE a.name = 'Bob'
        COLUMNS (a.name AS dst, b.name AS src)
      )
      """
    Then the result should be, in any order:
      | dst | src   |
      | Bob | Alice |

  Scenario: [3] Match edge with undirected pattern
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[k:KNOWS]-(b:Person)
        WHERE a.name = 'Bob'
        COLUMNS (a.name AS a_name, b.name AS b_name)
      )
      """
    Then the result should be, in any order:
      | a_name | b_name  |
      | Bob    | Alice   |
      | Bob    | Charlie |

  Scenario: [4] Match edge with relationship property
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[k:KNOWS]->(b:Person)
        COLUMNS (a.name AS src, b.name AS dst, k.since AS since)
      )
      """
    Then the result should be, in any order:
      | src   | dst     | since |
      | Alice | Bob     | 2020  |
      | Bob   | Charlie | 2021  |
      | Alice | Charlie | 2019  |

  Scenario: [5] Match edge with property filter on relationship
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[k:KNOWS]->(b:Person)
        WHERE k.since >= 2020
        COLUMNS (a.name AS src, b.name AS dst)
      )
      """
    Then the result should be, in any order:
      | src   | dst     |
      | Alice | Bob     |
      | Bob   | Charlie |

  Scenario: [6] Match edge without label (any relationship type)
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[]->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (b.name AS connected_to)
      )
      """
    Then the result should be, in any order:
      | connected_to |
      | Bob          |
      | Charlie      |

  Scenario: [7] Match edge with abbreviated syntax ->
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (b.name AS connected_to)
      )
      """
    Then the result should be, in any order:
      | connected_to |
      | Bob          |
      | Charlie      |

  Scenario: [8] Match edge with abbreviated syntax <-
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)<-(b:Person)
        WHERE a.name = 'Bob'
        COLUMNS (b.name AS connected_from)
      )
      """
    Then the result should be, in any order:
      | connected_from |
      | Alice          |

  Scenario: [9] Match two-hop path
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]->(b:Person)-[:KNOWS]->(c:Person)
        WHERE a.name = 'Alice'
        COLUMNS (a.name AS start, b.name AS middle, c.name AS end)
      )
      """
    Then the result should be, in any order:
      | start | middle | end     |
      | Alice | Bob    | Charlie |

  Scenario: [10] Match path with no results
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]->(b:Person)
        WHERE a.name = 'Charlie'
        COLUMNS (b.name AS connected_to)
      )
      """
    Then the result should be empty
