#
# SQL/PGQ TCK - CREATE PROPERTY GRAPH
#
# Tests for CREATE PROPERTY GRAPH statement (SQL:2023 Part 16)
#

Feature: CreatePropertyGraph1 - Basic vertex table definitions

  Background:
    Given an empty property graph registry

  Scenario: [1] Create property graph with single vertex table
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (persons)
      """
    Then the property graph "g" should exist
    And the property graph "g" should have 1 vertex table

  Scenario: [2] Create property graph with vertex table and KEY
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (persons KEY (id))
      """
    Then the property graph "g" should exist
    And vertex table "persons" should have key columns:
      | column |
      | id     |

  Scenario: [3] Create property graph with vertex table and composite KEY
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (persons KEY (id1, id2))
      """
    Then the property graph "g" should exist
    And vertex table "persons" should have key columns:
      | column |
      | id1    |
      | id2    |

  Scenario: [4] Create property graph with vertex table and LABEL
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (persons LABEL Person)
      """
    Then the property graph "g" should exist
    And vertex table "persons" should have label "Person"

  Scenario: [5] Create property graph with vertex table alias
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (persons AS p LABEL Person)
      """
    Then the property graph "g" should exist
    And vertex table "persons" should have alias "p"

  Scenario: [6] Create property graph with PROPERTIES clause
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (persons KEY (id) PROPERTIES (name, age))
      """
    Then the property graph "g" should exist
    And vertex table "persons" should have properties:
      | property |
      | name     |
      | age      |

  Scenario: [7] Create property graph with property aliases
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (persons PROPERTIES (first_name AS name, years AS age))
      """
    Then the property graph "g" should exist
    And vertex table "persons" should have property mapping:
      | property | column     |
      | name     | first_name |
      | age      | years      |

  Scenario: [8] Create property graph with multiple vertex tables
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH g
      VERTEX TABLES (
        persons KEY (id) LABEL Person,
        companies KEY (id) LABEL Company
      )
      """
    Then the property graph "g" should exist
    And the property graph "g" should have 2 vertex tables

  Scenario: [9] Create property graph IF NOT EXISTS when graph does not exist
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH IF NOT EXISTS g
      VERTEX TABLES (persons)
      """
    Then the property graph "g" should exist

  Scenario: [10] Create property graph IF NOT EXISTS when graph already exists
    Given property graph "g" exists with vertex tables:
      | table   |
      | persons |
    When executing SQL/PGQ:
      """
      CREATE PROPERTY GRAPH IF NOT EXISTS g
      VERTEX TABLES (companies)
      """
    Then the property graph "g" should exist
    And the property graph "g" should have 1 vertex table
    And no error should be raised
