#
# SQL/PGQ TCK - Path Quantifiers
#
# Tests for variable-length path patterns in GRAPH_TABLE queries
# SQL/PGQ uses {min,max} syntax for path quantifiers
#

Feature: PathQuantifiers - Variable-length path matching

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
      | id | name    |
      | 1  | Alice   |
      | 2  | Bob     |
      | 3  | Charlie |
      | 4  | Diana   |
      | 5  | Eve     |
    And table "knows" with data:
      | src | dst |
      | 1   | 2   |
      | 2   | 3   |
      | 3   | 4   |
      | 4   | 5   |

  @PathQuantifier
  Scenario: [1] Match path with exact length {2}
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]{2}->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (a.name AS start, b.name AS end)
      )
      """
    Then the result should be, in any order:
      | start | end     |
      | Alice | Charlie |

  @PathQuantifier
  Scenario: [2] Match path with range {1,2}
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]{1,2}->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (a.name AS start, b.name AS end)
      )
      """
    Then the result should be, in any order:
      | start | end     |
      | Alice | Bob     |
      | Alice | Charlie |

  @PathQuantifier
  Scenario: [3] Match path with range {1,3}
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]{1,3}->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (a.name AS start, b.name AS end)
      )
      """
    Then the result should be, in any order:
      | start | end     |
      | Alice | Bob     |
      | Alice | Charlie |
      | Alice | Diana   |

  @PathQuantifier
  Scenario: [4] Match path with minimum only {2,}
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]{2,}->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (a.name AS start, b.name AS end)
      )
      """
    Then the result should be, in any order:
      | start | end     |
      | Alice | Charlie |
      | Alice | Diana   |
      | Alice | Eve     |

  @PathQuantifier
  Scenario: [5] Match path with zero minimum {0,2}
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]{0,2}->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (a.name AS start, b.name AS end)
      )
      """
    Then the result should be, in any order:
      | start | end     |
      | Alice | Alice   |
      | Alice | Bob     |
      | Alice | Charlie |

  @PathQuantifier
  Scenario: [6] Match any path * (equivalent to {1,})
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]*->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (a.name AS start, b.name AS end)
      )
      """
    Then the result should be, in any order:
      | start | end     |
      | Alice | Bob     |
      | Alice | Charlie |
      | Alice | Diana   |
      | Alice | Eve     |

  @PathQuantifier
  Scenario: [7] Match optional path + (equivalent to {1,})
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]+->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (a.name AS start, b.name AS end)
      )
      """
    Then the result should be, in any order:
      | start | end     |
      | Alice | Bob     |
      | Alice | Charlie |
      | Alice | Diana   |
      | Alice | Eve     |

  @PathQuantifier
  Scenario: [8] Match with ? (equivalent to {0,1})
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]?->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (a.name AS start, b.name AS end)
      )
      """
    Then the result should be, in any order:
      | start | end   |
      | Alice | Alice |
      | Alice | Bob   |

  @PathQuantifier
  Scenario: [9] Variable-length path with end node filter
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]{1,4}->(b:Person)
        WHERE a.name = 'Alice' AND b.name = 'Eve'
        COLUMNS (a.name AS start, b.name AS end)
      )
      """
    Then the result should be, in any order:
      | start | end |
      | Alice | Eve |

  @PathQuantifier
  Scenario: [10] Variable-length path returning no results
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]{1,2}->(b:Person)
        WHERE a.name = 'Eve'
        COLUMNS (a.name AS start, b.name AS end)
      )
      """
    Then the result should be empty

  @PathQuantifier
  Scenario: [11] Undirected variable-length path
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]{1,2}-(b:Person)
        WHERE a.name = 'Charlie'
        COLUMNS (a.name AS start, b.name AS end)
      )
      """
    Then the result should be, in any order:
      | start   | end     |
      | Charlie | Bob     |
      | Charlie | Diana   |
      | Charlie | Alice   |
      | Charlie | Eve     |

  @PathQuantifier
  Scenario: [12] Reverse direction variable-length path
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)<-[:KNOWS]{1,2}-(b:Person)
        WHERE a.name = 'Charlie'
        COLUMNS (a.name AS end, b.name AS start)
      )
      """
    Then the result should be, in any order:
      | end     | start |
      | Charlie | Bob   |
      | Charlie | Alice |
