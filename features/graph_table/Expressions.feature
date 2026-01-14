#
# SQL/PGQ TCK - Expressions
#
# Tests for expressions and functions in GRAPH_TABLE queries
#

Feature: Expressions - Expression evaluation in graph queries

  Background:
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person PROPERTIES (id, name, age, salary)
      )
      """
    And table "persons" with data:
      | id | name    | age | salary |
      | 1  | Alice   | 30  | 50000  |
      | 2  | Bob     | 25  | 40000  |
      | 3  | Charlie | 35  | 60000  |

  @ArithmeticExpression
  Scenario: [1] Arithmetic addition in COLUMNS
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 1
        COLUMNS (p.age + 5 AS age_plus_five)
      )
      """
    Then the result should be, in any order:
      | age_plus_five |
      | 35            |

  @ArithmeticExpression
  Scenario: [2] Arithmetic multiplication in COLUMNS
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 1
        COLUMNS (p.salary * 2 AS double_salary)
      )
      """
    Then the result should be, in any order:
      | double_salary |
      | 100000        |

  @ArithmeticExpression
  Scenario: [3] Arithmetic division in COLUMNS
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 1
        COLUMNS (p.salary / 1000 AS salary_k)
      )
      """
    Then the result should be, in any order:
      | salary_k |
      | 50       |

  @ArithmeticExpression
  Scenario: [4] Arithmetic in WHERE clause
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.salary / 1000 > 45
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name    |
      | Alice   |
      | Charlie |

  @StringConcatenation
  Scenario: [5] String concatenation
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 1
        COLUMNS (p.name || ' Smith' AS full_name)
      )
      """
    Then the result should be, in any order:
      | full_name   |
      | Alice Smith |

  @CaseExpression
  Scenario: [6] CASE expression
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (
          p.name AS name,
          CASE WHEN p.age >= 30 THEN 'Senior' ELSE 'Junior' END AS level
        )
      )
      """
    Then the result should be, in any order:
      | name    | level  |
      | Alice   | Senior |
      | Bob     | Junior |
      | Charlie | Senior |

  @CaseExpression
  Scenario: [7] CASE expression with multiple branches
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (
          p.name AS name,
          CASE
            WHEN p.age < 26 THEN 'Young'
            WHEN p.age < 33 THEN 'Middle'
            ELSE 'Senior'
          END AS category
        )
      )
      """
    Then the result should be, in any order:
      | name    | category |
      | Alice   | Middle   |
      | Bob     | Young    |
      | Charlie | Senior   |

  @CoalesceFunction
  Scenario: [8] COALESCE function
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        items KEY (id) LABEL Item PROPERTIES (id, name, nickname)
      )
      """
    And table "items" with data:
      | id | name  | nickname |
      | 1  | alpha | A        |
      | 2  | beta  | null     |
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (i:Item)
        COLUMNS (i.name AS name, COALESCE(i.nickname, 'N/A') AS display)
      )
      """
    Then the result should be, in any order:
      | name  | display |
      | alpha | A       |
      | beta  | N/A     |

  @NullIfFunction
  Scenario: [9] NULLIF function
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 2
        COLUMNS (p.name AS name, NULLIF(p.age, 25) AS age_or_null)
      )
      """
    Then the result should be, in any order:
      | name | age_or_null |
      | Bob  | null        |

  @LiteralValues
  Scenario: [10] Literal values in COLUMNS
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 1
        COLUMNS (p.name AS name, 'constant' AS const_val, 42 AS num_val)
      )
      """
    Then the result should be, in any order:
      | name  | const_val | num_val |
      | Alice | constant  | 42      |

  Scenario: [11] Comparison operators in expressions
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.age >= 25 AND p.age <= 30
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |

  @CastExpression
  Scenario: [12] CAST expression
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 1
        COLUMNS (p.name AS name, CAST(p.age AS VARCHAR) AS age_str)
      )
      """
    Then the result should be, in any order:
      | name  | age_str |
      | Alice | 30      |

  @NegativeNumbers
  Scenario: [13] Negative numbers
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 1
        COLUMNS (p.name AS name, -p.age AS neg_age)
      )
      """
    Then the result should be, in any order:
      | name  | neg_age |
      | Alice | -30     |

  @ParenthesizedExpression
  Scenario: [14] Parenthesized expressions
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 1
        COLUMNS ((p.salary + 10000) / 1000 AS adjusted)
      )
      """
    Then the result should be, in any order:
      | adjusted |
      | 60       |

  @SubstringFunction
  Scenario: [15] SUBSTRING function
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        WHERE p.id = 1
        COLUMNS (SUBSTRING(p.name FROM 1 FOR 3) AS short_name)
      )
      """
    Then the result should be, in any order:
      | short_name |
      | Ali        |
