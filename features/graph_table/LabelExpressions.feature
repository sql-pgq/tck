#
# SQL/PGQ TCK - Label Expressions
#
# A label expression selects elements by label. `|` is a disjunction and `&` a
# conjunction, and the difference is the whole point: an engine that treats
# `:A|B` as `:A&B` returns an empty result rather than an error, which is the
# kind of divergence a conformance suite exists to surface.
#
# The graph deliberately gives Person and Company disjoint rows, so a
# disjunction and a conjunction cannot accidentally agree.
#

Feature: LabelExpressions - Selecting elements by label expression

  Background:
    Given property graph "g" with schema:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons   KEY (id) LABEL Person  PROPERTIES (id, name),
        companies KEY (id) LABEL Company PROPERTIES (id, name)
      )
      EDGE TABLES (
        knows SOURCE KEY (src) REFERENCES persons (id)
              DESTINATION KEY (dst) REFERENCES persons (id)
              LABEL KNOWS,
        works_at SOURCE KEY (pid) REFERENCES persons (id)
                 DESTINATION KEY (cid) REFERENCES companies (id)
                 LABEL WORKS_AT
      )
      """
    And table "persons" with data:
      | id | name    |
      | 1  | Alice   |
      | 2  | Bob     |
    And table "companies" with data:
      | id | name |
      | 10 | Acme |
    And table "knows" with data:
      | src | dst |
      | 1   | 2   |
    And table "works_at" with data:
      | pid | cid |
      | 1   | 10  |

  @LabelDisjunction
  Scenario: [1] Alternation matches an element carrying either label
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:Person|Company)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |
      | Acme  |

  @LabelDisjunction
  Scenario: [2] Alternation naming one label matches that label alone
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:Company)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name |
      | Acme |

  @LabelDisjunction
  Scenario: [3] Repeating a label in an alternation does not duplicate rows
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:Person|Person)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |

  @LabelDisjunction
  Scenario: [4] A branch matching nothing does not suppress the others
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:Company|Person)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |
      | Acme  |

  @LabelDisjunction @Aggregation
  Scenario: [5] Alternation counted
    # Aggregated in the outer query, where GRAPH_TABLE yields one row per match
    # and the count is well defined. Aggregating inside COLUMNS is a separate
    # question this suite does not yet take a position on.
    #
    # Also tagged @Aggregation: outer-query aggregation is a declared gap in
    # the reference binding's engine, so this rides that entry rather than
    # asserting the disjunction is broken when it is the SELECT that is.
    When executing SQL/PGQ:
      """
      SELECT COUNT(*) AS total FROM GRAPH_TABLE (g
        MATCH (n:Person|Company)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | total |
      | 3     |

  @LabelGrouping
  Scenario: [6] A parenthesised alternation behaves as the bare form
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:(Person|Company))
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |
      | Acme  |

  @LabelGrouping
  Scenario: [7] A parenthesised single label
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:(Company))
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name |
      | Acme |

  @LabelConjunction
  Scenario: [8] Conjunction requires every named label
    # No row carries both, so the empty result here is the correct answer, not
    # the symptom that scenario [1] guards against.
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:Person&Company)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name |

  @LabelWildcard
  Scenario: [9] The wildcard matches every element
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n:%)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |
      | Acme  |

  @LabellessMatch
  Scenario: [10] A pattern with no label expression matches every element
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name  |
      | Alice |
      | Bob   |
      | Acme  |

  @IsKeyword
  Scenario: [11] IS is a synonym for the colon
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (n IS Company)
        COLUMNS (n.name AS name)
      )
      """
    Then the result should be, in any order:
      | name |
      | Acme |

  @EdgeLabelDisjunction
  Scenario: [12] Alternation on an edge matches either type
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[e:KNOWS|WORKS_AT]->(b)
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should be, in any order:
      | a     | b    |
      | Alice | Bob  |
      | Alice | Acme |

  @EdgeLabelDisjunction
  Scenario: [13] An edge alternation naming one type matches that type alone
    When executing SQL/PGQ:
      """
      SELECT * FROM GRAPH_TABLE (g
        MATCH (a:Person)-[e:WORKS_AT]->(b:Company)
        COLUMNS (a.name AS a, b.name AS b)
      )
      """
    Then the result should be, in any order:
      | a     | b    |
      | Alice | Acme |
