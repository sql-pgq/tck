#
# SQL/PGQ TCK - Edge Patterns (Advanced)
#
# Tests for advanced edge pattern matching in GRAPH_TABLE queries
#

Feature: EdgePatterns2 - Advanced edge pattern matching

  Background:
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person PROPERTIES (id, name),
        companies KEY (id) LABEL Company PROPERTIES (id, name)
      )
      EDGE TABLES (
        knows SOURCE KEY (src) REFERENCES persons (id)
              DESTINATION KEY (dst) REFERENCES persons (id)
              LABEL KNOWS PROPERTIES (since, strength),
        works_at SOURCE KEY (person_id) REFERENCES persons (id)
                 DESTINATION KEY (company_id) REFERENCES companies (id)
                 LABEL WORKS_AT PROPERTIES (role, start_year)
      )
      """
    And table "persons" with data:
      | id | name    |
      | 1  | Alice   |
      | 2  | Bob     |
      | 3  | Charlie |
    And table "companies" with data:
      | id | name    |
      | 1  | TechCo  |
      | 2  | FinCorp |
    And table "knows" with data:
      | src | dst | since | strength |
      | 1   | 2   | 2020  | 5        |
      | 2   | 3   | 2021  | 3        |
      | 1   | 3   | 2019  | 8        |
    And table "works_at" with data:
      | person_id | company_id | role      | start_year |
      | 1         | 1          | Engineer  | 2018       |
      | 2         | 1          | Manager   | 2015       |
      | 3         | 2          | Analyst   | 2020       |

  Scenario: [1] Match edges between different node types
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (p:Person)-[w:WORKS_AT]->(c:Company)
        WHERE c.name = 'TechCo'
        COLUMNS (p.name AS person, w.role AS role)
      )
      """
    Then the result should be, in any order:
      | person | role     |
      | Alice  | Engineer |
      | Bob    | Manager  |

  Scenario: [2] Match edge with multiple property filters
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[k:KNOWS]->(b:Person)
        WHERE k.since >= 2020 AND k.strength > 4
        COLUMNS (a.name AS src, b.name AS dst, k.strength AS str)
      )
      """
    Then the result should be, in any order:
      | src   | dst | str |
      | Alice | Bob | 5   |

  Scenario: [3] Match edge returning relationship ID
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[k:KNOWS]->(b:Person)
        WHERE a.name = 'Alice'
        COLUMNS (a.name AS src, b.name AS dst, k.since AS since)
      )
      """
    Then the result should be, in any order:
      | src   | dst     | since |
      | Alice | Bob     | 2020  |
      | Alice | Charlie | 2019  |

  Scenario: [4] Match three-hop path
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]->(b:Person)-[:KNOWS]->(c:Person)
        WHERE a.name = 'Alice' AND c.name = 'Charlie'
        COLUMNS (a.name AS start, b.name AS middle, c.name AS end)
      )
      """
    Then the result should be, in any order:
      | start | middle | end     |
      | Alice | Bob    | Charlie |

  Scenario: [5] Match path with mixed relationship types
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]->(b:Person)-[:WORKS_AT]->(c:Company)
        WHERE a.name = 'Alice'
        COLUMNS (a.name AS person, b.name AS friend, c.name AS company)
      )
      """
    Then the result should be, in any order:
      | person | friend  | company |
      | Alice  | Bob     | TechCo  |
      | Alice  | Charlie | FinCorp |

  Scenario: [6] Match edge with inequality filter
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[k:KNOWS]->(b:Person)
        WHERE k.strength <> 5
        COLUMNS (a.name AS src, b.name AS dst)
      )
      """
    Then the result should be, in any order:
      | src     | dst     |
      | Bob     | Charlie |
      | Alice   | Charlie |

  @SelfLoop
  Scenario: [7] Match self-loop (if present)
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        nodes KEY (id) LABEL Node PROPERTIES (id, name)
      )
      EDGE TABLES (
        links SOURCE KEY (src) REFERENCES nodes (id)
              DESTINATION KEY (dst) REFERENCES nodes (id)
              LABEL LINKS
      )
      """
    And table "nodes" with data:
      | id | name  |
      | 1  | alpha |
      | 2  | beta  |
    And table "links" with data:
      | src | dst |
      | 1   | 1   |
      | 1   | 2   |
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Node)-[:LINKS]->(b:Node)
        WHERE a.id = b.id
        COLUMNS (a.name AS node)
      )
      """
    Then the result should be, in any order:
      | node  |
      | alpha |

  @OuterOrderBy
  Scenario: [8] Match edge with ORDER BY in outer query
    When executing SQL/PGQ:
      """
      SELECT * FROM (
        SELECT * FROM GRAPH_TABLE (g
          MATCH (a:Person)-[k:KNOWS]->(b:Person)
          COLUMNS (a.name AS src, b.name AS dst, k.since AS since)
        )
      ) ORDER BY since DESC
      """
    Then the result should be, in any order:
      | src     | dst     | since |
      | Bob     | Charlie | 2021  |
      | Alice   | Bob     | 2020  |
      | Alice   | Charlie | 2019  |

  Scenario: [9] Match path and count hops
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[:KNOWS]->(b:Person)-[:KNOWS]->(c:Person)
        COLUMNS (a.name AS start, c.name AS end)
      )
      """
    Then the result should be, in any order:
      | start | end     |
      | Alice | Charlie |

  @OuterDistinct
  Scenario: [10] Match edge with DISTINCT in outer query
    When executing SQL/PGQ:
      """
      SELECT DISTINCT company FROM (
        SELECT * FROM GRAPH_TABLE (g
          MATCH (p:Person)-[:WORKS_AT]->(c:Company)
          COLUMNS (c.name AS company)
        )
      )
      """
    Then the result should be, in any order:
      | company |
      | TechCo  |
      | FinCorp |
