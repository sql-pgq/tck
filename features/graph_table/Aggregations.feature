#
# SQL/PGQ TCK - Aggregations
#
# Tests for aggregation functions in GRAPH_TABLE queries
# Note: SQL/PGQ aggregations typically use outer query SQL aggregations
#

Feature: Aggregations - Aggregation functions in graph queries

  Background:
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person PROPERTIES (id, name, age, dept),
        departments KEY (id) LABEL Department PROPERTIES (id, name)
      )
      EDGE TABLES (
        works_in SOURCE KEY (person_id) REFERENCES persons (id)
                 DESTINATION KEY (dept_id) REFERENCES departments (id)
                 LABEL WORKS_IN PROPERTIES (start_year)
      )
      """
    And table "persons" with data:
      | id | name    | age | dept   |
      | 1  | Alice   | 30  | Sales  |
      | 2  | Bob     | 25  | IT     |
      | 3  | Charlie | 35  | Sales  |
      | 4  | Diana   | 28  | IT     |
      | 5  | Eve     | 32  | HR     |
    And table "departments" with data:
      | id | name  |
      | 1  | Sales |
      | 2  | IT    |
      | 3  | HR    |
    And table "works_in" with data:
      | person_id | dept_id | start_year |
      | 1         | 1       | 2018       |
      | 2         | 2       | 2020       |
      | 3         | 1       | 2015       |
      | 4         | 2       | 2019       |
      | 5         | 3       | 2021       |

  @Aggregation
  Scenario: [1] COUNT aggregation
    When executing SQL/PGQ:
      """
      SELECT COUNT(*) AS total FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | total |
      | 5     |

  @Aggregation
  Scenario: [2] SUM aggregation
    When executing SQL/PGQ:
      """
      SELECT SUM(age) AS total_age FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.age AS age)
      )
      """
    Then the result should be, in any order:
      | total_age |
      | 150       |

  @Aggregation
  Scenario: [3] AVG aggregation
    When executing SQL/PGQ:
      """
      SELECT AVG(age) AS avg_age FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.age AS age)
      )
      """
    Then the result should be, in any order:
      | avg_age |
      | 30      |

  @Aggregation
  Scenario: [4] MIN aggregation
    When executing SQL/PGQ:
      """
      SELECT MIN(age) AS min_age FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.age AS age)
      )
      """
    Then the result should be, in any order:
      | min_age |
      | 25      |

  @Aggregation
  Scenario: [5] MAX aggregation
    When executing SQL/PGQ:
      """
      SELECT MAX(age) AS max_age FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.age AS age)
      )
      """
    Then the result should be, in any order:
      | max_age |
      | 35      |

  @Aggregation
  Scenario: [6] GROUP BY aggregation
    When executing SQL/PGQ:
      """
      SELECT dept, COUNT(*) AS count FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.dept AS dept)
      ) GROUP BY dept
      """
    Then the result should be, in any order:
      | dept  | count |
      | Sales | 2     |
      | IT    | 2     |
      | HR    | 1     |

  @Aggregation
  Scenario: [7] GROUP BY with SUM
    When executing SQL/PGQ:
      """
      SELECT dept, SUM(age) AS total_age FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.dept AS dept, p.age AS age)
      ) GROUP BY dept
      """
    Then the result should be, in any order:
      | dept  | total_age |
      | Sales | 65        |
      | IT    | 53        |
      | HR    | 32        |

  @Aggregation
  Scenario: [8] Aggregation with relationship traversal
    When executing SQL/PGQ:
      """
      SELECT dept_name, COUNT(*) AS emp_count FROM GRAPH_TABLE (g
        MATCH (p:Person)-[:WORKS_IN]->(d:Department)
        COLUMNS (d.name AS dept_name)
      ) GROUP BY dept_name
      """
    Then the result should be, in any order:
      | dept_name | emp_count |
      | Sales     | 2         |
      | IT        | 2         |
      | HR        | 1         |

  @Aggregation
  Scenario: [9] HAVING clause
    When executing SQL/PGQ:
      """
      SELECT dept, COUNT(*) AS count FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.dept AS dept)
      ) GROUP BY dept HAVING COUNT(*) > 1
      """
    Then the result should be, in any order:
      | dept  | count |
      | Sales | 2     |
      | IT    | 2     |

  @Aggregation
  Scenario: [10] Multiple aggregations
    When executing SQL/PGQ:
      """
      SELECT
        COUNT(*) AS count,
        MIN(age) AS min_age,
        MAX(age) AS max_age,
        AVG(age) AS avg_age
      FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.age AS age)
      )
      """
    Then the result should be, in any order:
      | count | min_age | max_age | avg_age |
      | 5     | 25      | 35      | 30      |
