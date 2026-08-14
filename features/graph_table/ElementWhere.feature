#
# SQL/PGQ TCK - Element WHERE
#
# A WHERE clause written inside an element pattern, `(p:Person WHERE p.age >
# 28)`, constrains that element. It is not a synonym for the MATCH-level WHERE:
# on an optional or multi-pattern match the two can differ, and even here they
# read differently to anyone maintaining the query.
#
# An engine that parses the clause and discards it returns *more* rows than
# asked for, silently. Every scenario below is written so that the unfiltered
# result differs from the filtered one, so a no-op implementation fails rather
# than coincidentally agreeing.
#

Feature: ElementWhere - Filtering inside an element pattern

  Background:
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person PROPERTIES (id, name, age)
      )
      EDGE TABLES (
        knows SOURCE KEY (src) REFERENCES persons (id)
              DESTINATION KEY (dst) REFERENCES persons (id)
              LABEL KNOWS PROPERTIES (since)
      )
      """
    And table "persons" with data:
      | id | name  | age |
      | 1  | Alice | 30  |
      | 2  | Bob   | 25  |
      | 3  | Carol | 35  |
      | 4  | Dave  | 28  |
    And table "knows" with data:
      | src | dst | since |
      | 1   | 2   | 2020  |
      | 2   | 3   | 2021  |
      | 3   | 4   | 2022  |
      | 1   | 3   | 2019  |

  @ElementWhere
  Scenario: [1] A node pattern filters on a comparison
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person WHERE p.age > 28)
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Carol |

  @ElementWhere
  Scenario: [2] A node pattern filters on equality
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person WHERE p.name = 'Bob')
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be, in any order:
      | name |
      | Bob  |

  @ElementWhere
  Scenario: [3] A node pattern whose filter excludes everything
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person WHERE p.age > 100)
        COLUMNS (p.name AS name)
      )
      """
    Then the result should be empty

  @ElementWhere
  Scenario: [4] An edge pattern filters on a relationship property
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[e:KNOWS WHERE e.since > 2020]->(b:Person)
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should be, in any order:
      | a     | b     |
      | Bob   | Carol |
      | Carol | Dave  |

  @ElementWhere
  Scenario: [5] Both endpoints may carry their own filter
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person WHERE a.age > 28)-[:KNOWS]->(b:Person WHERE b.age < 30)
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should be, in any order:
      | a     | b    |
      | Alice | Bob  |
      | Carol | Dave |

  @ElementWhere
  Scenario: [6] An element filter composes with the MATCH-level WHERE
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person WHERE a.age > 26)-[:KNOWS]->(b:Person)
        WHERE b.age > 26
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should be, in any order:
      | a     | b     |
      | Alice | Carol |
      | Carol | Dave  |

  @ElementWhere
  Scenario: [7] An element filter narrows a count
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person WHERE p.age >= 30)
        COLUMNS (p.name AS name)
      )
      """
    Then the result should have 2 rows
