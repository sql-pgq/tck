#
# SQL/PGQ TCK - Node Patterns
#
# Tests for node pattern matching in GRAPH_TABLE queries
#

Feature: NodePatterns1 - Basic node pattern matching

  Background:
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person PROPERTIES (id, name, age)
      )
      """
    And table "persons" with data:
      | id | name    | age |
      | 1  | Alice   | 30  |
      | 2  | Bob     | 25  |
      | 3  | Charlie | 35  |

  Scenario: [1] Match all nodes with label
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name    |
      | Alice   |
      | Bob     |
      | Charlie |

  @LabellessMatch
  Scenario: [2] Match node with variable only (no label)
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p)
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name    |
      | Alice   |
      | Bob     |
      | Charlie |

  Scenario: [3] Match node with property filter in WHERE
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.age > 28
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name    |
      | Alice   |
      | Charlie |

  Scenario: [4] Match node with equality filter
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.name = 'Bob'
        COLUMNS (p.id AS id, p.name AS name)
      )
      """
    Then the result should be, in any order:
      | id | name |
      | 2  | Bob  |

  Scenario: [5] Match node returning multiple properties
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 1
        COLUMNS (p.id AS id, p.name AS name, p.age AS age)
      )
      """
    Then the result should be, in any order:
      | id | name  | age |
      | 1  | Alice | 30  |

  Scenario: [6] Match node with no results
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.name = 'NonExistent'
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be empty

  Scenario: [7] Match node with AND condition
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.age > 25 AND p.age < 35
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |

  Scenario: [8] Match node with OR condition
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.name = 'Alice' OR p.name = 'Bob'
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |

  Scenario Outline: [9] Match node with comparison operators
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.age <op> <value>
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name   |
      | <name> |

    Examples:
      | op | value | name    |
      | =  | 30    | Alice   |
      | =  | 25    | Bob     |
      | =  | 35    | Charlie |

  @LikeOperator
  Scenario: [10] Match node with LIKE pattern
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.name LIKE 'A%'
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
