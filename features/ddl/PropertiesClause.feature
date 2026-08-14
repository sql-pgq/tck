#
# SQL/PGQ TCK - Properties Clause
#
# The forms a vertex or edge table may use to say which columns become
# properties: an explicit list, every column, every column bar a few, and none
# at all. The explicit list is covered by CreatePropertyGraph1/2; this file
# covers the rest, and asserts through queries rather than through the parsed
# definition, so that a clause which parses but does not take effect fails.
#

Feature: PropertiesClause - Declaring which columns become properties

  Background:
    Given table "persons" with data:
      | id | name  | age |
      | 1  | Alice | 30  |
      | 2  | Bob   | 25  |

  @PropertiesAreAllColumns
  Scenario: [1] PROPERTIES ARE ALL COLUMNS exposes every column
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person PROPERTIES ARE ALL COLUMNS
      )
      """
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.name AS name, p.age AS age)
      )
      """
    Then the result should be, in any order:
      | name  | age |
      | Alice | 30  |
      | Bob   | 25  |

  @PropertiesAreAllColumns
  Scenario: [2] EXCEPT keeps the columns it does not name
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person PROPERTIES ARE ALL COLUMNS EXCEPT (age)
      )
      """
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |

  @PropertiesAreAllColumns
  Scenario: [3] An excepted column is not a property
    # The clause must actually take effect. If EXCEPT parsed and were ignored
    # this scenario would return 30 and 25 rather than nulls.
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person PROPERTIES ARE ALL COLUMNS EXCEPT (age)
      )
      """
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (p.age AS age)
      )
      """
    Then the result should be, in any order:
      | age  |
      | null |
      | null |

  @NoPropertiesClause
  Scenario: [4] NO PROPERTIES still matches the rows
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person NO PROPERTIES
      )
      """
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)
        COLUMNS (1 AS present)
      )
      """
    Then the result should be, in any order:
      | present |
      | 1       |
      | 1       |

  @VertexTableAlias
  Scenario: [5] A vertex table may be aliased
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons AS p KEY (id) LABEL Person PROPERTIES (id, name)
      )
      """
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:Person)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |

  @OptionalKeyClause
  Scenario: [6] The KEY clause may be omitted
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons LABEL Person PROPERTIES (id, name)
      )
      """
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:Person)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |

  @RepeatedLabelClause
  Scenario: [7] A table may declare more than one label
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person LABEL Human PROPERTIES (id, name)
      )
      """
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:Human)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |

  @RepeatedLabelClause
  Scenario: [8] Both declared labels select the same rows
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person LABEL Human PROPERTIES (id, name)
      )
      """
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:Person)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |
