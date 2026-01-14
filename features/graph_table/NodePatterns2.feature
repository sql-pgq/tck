#
# SQL/PGQ TCK - Node Patterns (Advanced)
#
# Tests for advanced node pattern matching in GRAPH_TABLE queries
#

Feature: NodePatterns2 - Advanced node pattern matching

  Background:
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person PROPERTIES (id, name, age, city),
        companies KEY (id) LABEL Company PROPERTIES (id, name, industry)
      )
      """
    And table "persons" with data:
      | id | name    | age | city      |
      | 1  | Alice   | 30  | New York  |
      | 2  | Bob     | 25  | Boston    |
      | 3  | Charlie | 35  | New York  |
      | 4  | Diana   | 28  | Chicago   |
    And table "companies" with data:
      | id | name    | industry   |
      | 1  | TechCo  | Technology |
      | 2  | FinCorp | Finance    |

  Scenario: [1] Match nodes with multiple labels
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.city = 'New York'
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name    |
      | Alice   |
      | Charlie |

  Scenario: [2] Match nodes from different vertex tables
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (c:Company)
        COLUMNS (c.name AS name, c.industry AS industry)
      )
      """
    Then the result should be, in any order:
      | name    | industry   |
      | TechCo  | Technology |
      | FinCorp | Finance    |

  Scenario: [3] Match node with NOT condition
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE NOT p.city = 'New York'
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Bob   |
      | Diana |

  @IsNullCondition
  Scenario: [4] Match node with IS NULL condition
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        items KEY (id) LABEL Item PROPERTIES (id, name, value)
      )
      """
    And table "items" with data:
      | id | name  | value |
      | 1  | alpha | 100   |
      | 2  | beta  | null  |
      | 3  | gamma | 200   |
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (i:Item)
        WHERE i.value IS NULL
        COLUMNS (i.name AS name)
      )
      """
    Then the result should be, in any order:
      | name |
      | beta |

  @IsNullCondition
  Scenario: [5] Match node with IS NOT NULL condition
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        items KEY (id) LABEL Item PROPERTIES (id, name, value)
      )
      """
    And table "items" with data:
      | id | name  | value |
      | 1  | alpha | 100   |
      | 2  | beta  | null  |
      | 3  | gamma | 200   |
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (i:Item)
        WHERE i.value IS NOT NULL
        COLUMNS (i.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | alpha |
      | gamma |

  @InListCondition
  Scenario: [6] Match node with IN list
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.city IN ('Boston', 'Chicago')
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Bob   |
      | Diana |

  @InListCondition
  Scenario: [7] Match node with NOT IN list
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.city NOT IN ('Boston', 'Chicago')
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name    |
      | Alice   |
      | Charlie |

  @BetweenCondition
  Scenario: [8] Match node with BETWEEN condition
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.age BETWEEN 26 AND 32
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Diana |

  Scenario: [9] Match node with complex nested condition
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE (p.age > 30 OR p.city = 'Boston') AND p.name <> 'Charlie'
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name |
      | Bob  |

  Scenario: [10] Match node returning all properties
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 1
        COLUMNS (p.id AS id, p.name AS name, p.age AS age, p.city AS city)
      )
      """
    Then the result should be, in any order:
      | id | name  | age | city     |
      | 1  | Alice | 30  | New York |
