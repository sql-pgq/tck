#
# SQL/PGQ TCK - CREATE PROPERTY GRAPH with EDGE TABLES
#
# Tests for EDGE TABLES clause in CREATE PROPERTY GRAPH statements
#

Feature: CreatePropertyGraph2 - EDGE TABLES clause

  Scenario: [1] Create property graph with single edge table
    Given an empty property graph registry
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id)
      )
      EDGE TABLES (
        knows SOURCE KEY (src) REFERENCES persons (id)
              DESTINATION KEY (dst) REFERENCES persons (id)
      )
      """
    Then the property graph "g" should exist
    And the property graph "g" should have 1 vertex table
    And the property graph "g" should have 1 edge table

  Scenario: [2] Create property graph with edge table and label
    Given an empty property graph registry
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id)
      )
      EDGE TABLES (
        knows SOURCE KEY (src) REFERENCES persons (id)
              DESTINATION KEY (dst) REFERENCES persons (id)
              LABEL KNOWS
      )
      """
    Then the property graph "g" should exist
    And edge table "knows" should have label "KNOWS"

  Scenario: [3] Create property graph with edge table properties
    Given an empty property graph registry
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id)
      )
      EDGE TABLES (
        knows SOURCE KEY (src) REFERENCES persons (id)
              DESTINATION KEY (dst) REFERENCES persons (id)
              PROPERTIES (since, weight)
      )
      """
    Then the property graph "g" should exist
    And edge table "knows" should have properties:
      | property |
      | since    |
      | weight   |

  Scenario: [4] Create property graph with multiple edge tables
    Given an empty property graph registry
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id),
        companies KEY (id)
      )
      EDGE TABLES (
        knows SOURCE KEY (src) REFERENCES persons (id)
              DESTINATION KEY (dst) REFERENCES persons (id),
        works_at SOURCE KEY (person_id) REFERENCES persons (id)
                 DESTINATION KEY (company_id) REFERENCES companies (id)
      )
      """
    Then the property graph "g" should exist
    And the property graph "g" should have 2 vertex tables
    And the property graph "g" should have 2 edge tables

  Scenario: [5] Create property graph with edge referencing different vertex tables
    Given an empty property graph registry
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        accounts KEY (id) LABEL Account,
        transactions KEY (id) LABEL Transaction
      )
      EDGE TABLES (
        transfers SOURCE KEY (from_account) REFERENCES accounts (id)
                  DESTINATION KEY (to_transaction) REFERENCES transactions (id)
                  LABEL TRANSFERS
      )
      """
    Then the property graph "g" should exist
    And edge table "transfers" should have source reference "accounts"
    And edge table "transfers" should have destination reference "transactions"

  Scenario: [6] Create property graph with edge table property aliases
    Given an empty property graph registry
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id)
      )
      EDGE TABLES (
        knows SOURCE KEY (src) REFERENCES persons (id)
              DESTINATION KEY (dst) REFERENCES persons (id)
              PROPERTIES (relationship_date AS since, strength AS weight)
      )
      """
    Then the property graph "g" should exist
    And edge table "knows" should have property mapping:
      | property | column            |
      | since    | relationship_date |
      | weight   | strength          |

  Scenario: [7] Create property graph with self-referencing edge
    Given an empty property graph registry
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        employees KEY (id)
      )
      EDGE TABLES (
        manages SOURCE KEY (manager_id) REFERENCES employees (id)
                DESTINATION KEY (employee_id) REFERENCES employees (id)
                LABEL MANAGES
      )
      """
    Then the property graph "g" should exist
    And edge table "manages" should have source reference "employees"
    And edge table "manages" should have destination reference "employees"

  Scenario: [8] Create property graph with composite edge keys
    Given an empty property graph registry
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        orders KEY (order_id, line_num)
      )
      EDGE TABLES (
        order_deps SOURCE KEY (src_order, src_line) REFERENCES orders (order_id, line_num)
                   DESTINATION KEY (dst_order, dst_line) REFERENCES orders (order_id, line_num)
      )
      """
    Then the property graph "g" should exist
    And edge table "order_deps" should have source columns:
      | column    |
      | src_order |
      | src_line  |

  @NoPropertiesClause
  Scenario: [9] Create property graph with no properties on edge
    Given an empty property graph registry
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        nodes KEY (id)
      )
      EDGE TABLES (
        links SOURCE KEY (src) REFERENCES nodes (id)
              DESTINATION KEY (dst) REFERENCES nodes (id)
              NO PROPERTIES
      )
      """
    Then the property graph "g" should exist
    And edge table "links" should have no properties

  Scenario: [10] Create property graph with edge and vertex sharing same properties
    Given an empty property graph registry
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) PROPERTIES (name, created_at)
      )
      EDGE TABLES (
        follows SOURCE KEY (follower) REFERENCES persons (id)
                DESTINATION KEY (followed) REFERENCES persons (id)
                PROPERTIES (created_at)
      )
      """
    Then the property graph "g" should exist
    And vertex table "persons" should have properties:
      | property   |
      | name       |
      | created_at |
    And edge table "follows" should have properties:
      | property   |
      | created_at |
