-- tests/create_fixtures.sql
--
-- Creates and fills every object that tests/test_sqldta.do reads, in the
-- database _sqldtaTesting, which holds nothing but these objects. The tests
-- read nothing else. The database is created by hand, once, with the
-- server's default collation, which must be case-insensitive:
--     CREATE DATABASE [_sqldtaTesting];
-- Open this file in SQL Server Management Studio (SSMS) and execute it, on the
-- server named in TEST_SERVER, and again whenever it changes. Another site can
-- create a database of the same name, or change the name in the USE line and
-- in the check below it, and set TEST_FIXDATABASE in
-- tests/test_config_local.do.
--
-- It makes:
--   - the fixture label table sqldta_test.sqldta_test_labels, and the view
--     ref.DataProperties of it, which is sqldta's default label table, so that
--     both names give the same rows;
--   - sqldta_test.sqldta_test_known, a generated table of 1,000 rows and 11
--     columns, for the tests that load a table with its labels and notes;
--   - sqldta_test.sqldta_test_adm, a generated table of 20,000 admissions,
--     for the tests of the README's examples of sqlwhere() and the if
--     qualifier;
--   - small tables written out in full, for the tests of links, sqlselect(),
--     the if qualifier, display formats, the data label, the order of notes,
--     the SQL Server data types, date-time and time values, unicode(), the
--     label step, and tables of the same name in two schemas;
--   - sqldta_test.sqldta_test_otherlayout, a label table without the columns
--     of the layout, and dbo.sqldta_test_dflt, a table in the default schema;
--   - sqldta_test.sqldta_test_oldlabels, a label table of the predecessor's
--     layout, for the tests of SQLDTA_LABELFALLBACK;
--   - sqldta_test.sqldta_test_version, which the tests read before test 1.
-- It drops every object it creates first, and nothing else.
--
-- The generated tables take their values from the function
-- sqldta_test.sqldta_test_rnd(seed, row, column), which uses whole-number
-- arithmetic only, so that the same seed gives the same tables on any version
-- and edition of SQL Server:
--   x = (7 * seed + 1000003 * row + 7919 * column) mod 2147483646 + 1
--   x = 48271 * x mod 2147483647
--   x = x * x mod 2147483647
--   x = 48271 * x mod 2147483647
-- The multiplier 48271 and the modulus 2147483647 are those of Park and
-- Miller's minimal standard generator; squaring makes the values of different
-- rows and columns independent of one another. The seed and the version of the
-- fixtures are in sqldta_test.sqldta_test_version. A change to any fixture or
-- to the generator raises the version, here and in tests/test_sqldta.do, so
-- that the tests stop with a message until this file has been run again.
--
-- The file is kept in ASCII: characters outside ASCII are written with
-- NCHAR() and CHAR(), so that it reads the same whatever encoding SSMS
-- assumes.

USE [_sqldtaTesting];
GO

-- Stop unless the current database is _sqldtaTesting, for example because
-- the database does not exist and USE failed, so that nothing is dropped or
-- created in any other database. SET NOEXEC ON compiles the rest of the file
-- without running it; the last line turns it off again.
IF DB_NAME() <> N'_sqldtaTesting'
BEGIN
    RAISERROR(N'The current database is not _sqldtaTesting. Create it, or correct the USE line, and run this file again.', 16, 1);
    SET NOEXEC ON;
END;
GO

-- Drop every view, function and table that this file creates, views first,
-- in a batch of their own. SQL Server compiles a batch as a whole, so a
-- statement that names a column that a table does not have as it still exists
-- stops the whole batch before an earlier DROP in it has run. The drops are
-- therefore in this batch, ended by GO, and any object added to this file is
-- dropped here too (CLAUDE.md, Coding conventions).
IF OBJECT_ID(N'ref.DataProperties', N'V') IS NOT NULL DROP VIEW ref.DataProperties;
IF OBJECT_ID(N'sqldta_test.sqldta_test_view', N'V') IS NOT NULL DROP VIEW sqldta_test.sqldta_test_view;
IF OBJECT_ID(N'sqldta_test.sqldta_test_rnd', N'FN') IS NOT NULL DROP FUNCTION sqldta_test.sqldta_test_rnd;
IF OBJECT_ID(N'sqldta_test.sqldta_test_labels', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_labels;
IF OBJECT_ID(N'sqldta_test.sqldta_test_known', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_known;
IF OBJECT_ID(N'sqldta_test.sqldta_test_adm', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_adm;
IF OBJECT_ID(N'sqldta_test.sqldta_test_main', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_main;
IF OBJECT_ID(N'ref.sqldta_test_part', N'U') IS NOT NULL DROP TABLE ref.sqldta_test_part;
IF OBJECT_ID(N'sqldta_test.sqldta_test_part2', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_part2;
IF OBJECT_ID(N'sqldta_test.sqldta_test_bad', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_bad;
IF OBJECT_ID(N'sqldta_test.sqldta_test_dupkey', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_dupkey;
IF OBJECT_ID(N'sqldta_test.sqldta_test_badnames', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_badnames;
IF OBJECT_ID(N'sqldta_test.sqldta_test_types', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_types;
IF OBJECT_ID(N'sqldta_test.sqldta_test_rare', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_rare;
IF OBJECT_ID(N'sqldta_test.sqldta_test_dt', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_dt;
IF OBJECT_ID(N'sqldta_test.sqldta_test_wide', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_wide;
IF OBJECT_ID(N'sqldta_test.sqldta_test_umain', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_umain;
IF OBJECT_ID(N'sqldta_test.sqldta_test_upart', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_upart;
IF OBJECT_ID(N'sqldta_test.sqldta_test_lbl', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_lbl;
IF OBJECT_ID(N'sqldta_test.sqldta_test_same', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_same;
IF OBJECT_ID(N'sqldta_alt.sqldta_test_same', N'U') IS NOT NULL DROP TABLE sqldta_alt.sqldta_test_same;
IF OBJECT_ID(N'sqldta_test.sqldta_test_samepart', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_samepart;
IF OBJECT_ID(N'sqldta_alt.sqldta_test_samepart', N'U') IS NOT NULL DROP TABLE sqldta_alt.sqldta_test_samepart;
IF OBJECT_ID(N'ref.sqldta_test_samex', N'U') IS NOT NULL DROP TABLE ref.sqldta_test_samex;
IF OBJECT_ID(N'sqldta_test.sqldta_test_otherlayout', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_otherlayout;
IF OBJECT_ID(N'sqldta_test.sqldta_test_oldlabels', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_oldlabels;
IF OBJECT_ID(N'dbo.sqldta_test_dflt', N'U') IS NOT NULL DROP TABLE dbo.sqldta_test_dflt;
IF OBJECT_ID(N'sqldta_test.sqldta_test_version', N'U') IS NOT NULL DROP TABLE sqldta_test.sqldta_test_version;
GO

-- The schemas, then every function, table and view, created and filled.
-- CREATE SCHEMA, CREATE FUNCTION and CREATE VIEW must each begin a batch, so
-- they are run through EXEC.
IF SCHEMA_ID(N'sqldta_test') IS NULL EXEC (N'CREATE SCHEMA sqldta_test');
IF SCHEMA_ID(N'sqldta_alt') IS NULL EXEC (N'CREATE SCHEMA sqldta_alt');
IF SCHEMA_ID(N'ref') IS NULL EXEC (N'CREATE SCHEMA ref');

-- The generator described at the top of this file
EXEC (N'CREATE FUNCTION sqldta_test.sqldta_test_rnd (@seed bigint, @row bigint, @col bigint)
RETURNS bigint
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @x bigint = (7 * @seed + 1000003 * @row + 7919 * @col) % 2147483646 + 1;
    SET @x = (48271 * @x) % 2147483647;
    SET @x = (@x * @x) % 2147483647;
    SET @x = (48271 * @x) % 2147483647;
    RETURN @x;
END');

-- The seed of the generated tables, and the version of the fixtures, which
-- tests/test_sqldta.do expects
DECLARE @seed bigint = 20261021;
DECLARE @version int = 3;

-- The layout of a label table (CLAUDE.md, Metadata contract): the rows of a
-- table are those whose TableSchema and TableName are its schema and name.
CREATE TABLE sqldta_test.sqldta_test_labels (
    TableSchema  nvarchar(128) NOT NULL,
    TableName    nvarchar(128) NOT NULL,
    ColumnName   nvarchar(128) NULL,
    PropertyType nvarchar(20)  NOT NULL,
    DataType     nvarchar(20)  NULL,
    PropertyCode nvarchar(50)  NULL,
    PropertyText nvarchar(max) NULL
);

-- DataType is not used by sqldta; the column is kept, with a mix of values,
-- so that the tests show that its values, and other columns, make no
-- difference.
--
-- The index that docs/setup.md recommends for a label table, so that its
-- queries, which select by TableSchema, TableName and PropertyType, need not
-- read the whole table
CREATE INDEX IX_sqldta_test_labels_Table ON sqldta_test.sqldta_test_labels (TableSchema, TableName, PropertyType);

-- Label rows for the generated table sqldta_test_known (below): its column
-- Category has value labels and a variable label, and Score has variable
-- notes. Expected result of loading sqldta_test_known with every label type,
-- labels(all): value-label sets 1, variable labels 1, variable notes 4,
-- dataset notes 3, label rows skipped 4.
DECLARE @dataset sysname = N'sqldta_test_known';
DECLARE @valvar  sysname = N'Category';
DECLARE @notevar sysname = N'Score';
DECLARE @nosuch  sysname = N'sqldta_no_such_column';
DECLARE @other   sysname = N'sqldta_other_dataset';

INSERT INTO sqldta_test.sqldta_test_labels (TableSchema, TableName, ColumnName, PropertyType, DataType, PropertyCode, PropertyText) VALUES

-- Value labels for @valvar; all form one label set. The row of code 8 has its
-- PropertyType in lower case, which is matched without regard to case.
(N'sqldta_test', @dataset, @valvar,        N'ValueLabel', N'INT', N'1',  N'Plain label'),
(N'sqldta_test', @dataset, @valvar,        N'ValueLabel', N'INT', N'2',  N'Double "quotes" inside'),
(N'sqldta_test', @dataset, @valvar,        N'ValueLabel', N'INT', N'3',  N'Single ''quotes'', a comma, a colon: and a semicolon;'),
(N'sqldta_test', @dataset, @valvar,        N'ValueLabel', N'INT', N'4',  N'A lone backquote ` and a macro-like `name'' reference'),
(N'sqldta_test', @dataset, @valvar,        N'ValueLabel', N'INT', N'5',  N'Dollar signs: $100, $HOME and ${HOME}'),
(N'sqldta_test', @dataset, @valvar,        N'ValueLabel', N'INT', N'6',  N'Compound `"quoted"'' text'),
(N'sqldta_test', @dataset, @valvar,        N'ValueLabel', N'INT', N'-9', N'Negative code'),
(N'sqldta_test', @dataset, LOWER(@valvar), N'ValueLabel', N'INT', N'7',  N'ColumnName written in lower case'),
(N'sqldta_test', @dataset, @valvar,        N'valuelabel', N'int', N'8',  N'DataType written in lower case'),
(N'sqldta_test', @dataset, @valvar,        N'ValueLabel', N'VARCHAR', N'10', N'DataType VARCHAR, which sqldta does not use'),
(N'sqldta_test', @dataset, @valvar,        N'ValueLabel', NULL,   N'11', N'No DataType'),

-- A value-label row that is not fetched (empty text)
(N'sqldta_test', @dataset, @valvar,        N'ValueLabel', N'INT', N'9',  N''),

-- Value-label rows that are fetched and skipped (skipped rows 1 and 2)
(N'sqldta_test', @dataset, @valvar,        N'ValueLabel', N'INT', N'1.5', N'Not an integer code, so skipped'),
(N'sqldta_test', @dataset, @nosuch,        N'ValueLabel', N'INT', N'1',  N'No such column, so skipped'),

-- Variable labels; the first is written in upper case and is applied to @valvar
(N'sqldta_test', @dataset, UPPER(@valvar), N'VariableLabel', NULL, NULL, N'Variable label with "double quotes", a `backquote'' and $HOME'),
(N'sqldta_test', @dataset, @notevar,       N'VariableLabel', NULL, NULL, N''),
(N'sqldta_test', @dataset, @nosuch,        N'VariableLabel', NULL, NULL, N'No such column, so skipped'),

-- Variable notes for @notevar; the last row is skipped (skipped row 4)
(N'sqldta_test', @dataset, @notevar,       N'VariableNote', NULL, NULL, N'Note with "double quotes" and ''single quotes'''),
(N'sqldta_test', @dataset, @notevar,       N'VariableNote', NULL, NULL, N'Note with a lone backquote `, a macro-like `name'' and $HOME'),
(N'sqldta_test', @dataset, @notevar,       N'VariableNote', NULL, NULL, N'Note with TS as a separate word'),
(N'sqldta_test', @dataset, @notevar,       N'VariableNote', NULL, NULL, N'Long note: ' + REPLICATE(CAST(N'0123456789' AS nvarchar(max)), 300)),
(N'sqldta_test', @dataset, @nosuch,        N'VariableNote', NULL, NULL, N'No such column, so skipped'),

-- Dataset notes; the duplicate row is fetched once because of SELECT DISTINCT
(N'sqldta_test', @dataset, NULL,           N'DatasetNote', NULL, NULL, N'Dataset note with "double quotes"'),
(N'sqldta_test', @dataset, N'',            N'DatasetNote', NULL, NULL, N'Dataset note: a colon, $HOME and a `backquote'''),
(N'sqldta_test', @dataset, NULL,           N'DatasetNote', NULL, NULL, N'Dataset note entered twice'),
(N'sqldta_test', @dataset, NULL,           N'DatasetNote', NULL, NULL, N'Dataset note entered twice'),

-- Rows for another table, and for a table of the same name in another schema;
-- none of these is fetched
(N'sqldta_test', @other,   NULL,           N'DatasetNote', NULL, NULL, N'Belongs to another dataset, so not fetched'),
(N'sqldta_test', @other,   @valvar,        N'ValueLabel', N'INT', N'1',  N'Belongs to another dataset, so not fetched'),
(N'dbo',         @dataset, NULL,           N'DatasetNote', NULL, NULL, N'Filed under the schema dbo, so not fetched'),
(N'dbo',         @dataset, @valvar,        N'ValueLabel', N'INT', N'1',  N'Filed under the schema dbo, so not fetched');

-- Fixture data tables, written out in full, in the schema sqldta_test.
--
-- sqldta_test_main is linked by id to ref.sqldta_test_part (named with its
-- schema) and to sqldta_test_part2 (named without one, so it is looked for in
-- the schema of the main table, sqldta_test). sqldta follows Link rows in the
-- order of their PropertyText, which SQL Server sorts by the database's
-- collation; sqldta_test_part is in ref so that 'ref.sqldta_test_part' comes
-- before 'sqldta_test_part2' under any collation, which would not hold for a
-- full stop against an underscore. Loaded together they give 8 observations
-- and 11 variables:
-- [bad name] is left out because it is not a valid Stata name, and the shared
-- column of sqldta_test_part is left out because the main table has one. The
-- datetime column of sqldta_test_part2 is sent as text and converted, so the
-- joined table carries an expression in its column list.
-- sqldta_test_bad is linked to sqldta_test_dupkey, whose key repeats.
-- sqldta_test_badnames has no column with a valid Stata name, so sqldta stops
-- with error 111 and a message that says so (added on 20 Oct 2026).

CREATE TABLE sqldta_test.sqldta_test_main (
    id         int           NOT NULL,
    num        int           NULL,
    amount     decimal(9,2)  NULL,
    grp        nvarchar(20)  NULL,
    dob        date          NULL,
    [Order]    int           NULL,
    shared     int           NULL,
    [bad name] int           NULL
);
INSERT INTO sqldta_test.sqldta_test_main (id, num, amount, grp, dob, [Order], shared, [bad name]) VALUES
(1,    1,  10.50, N'abc',      '2020-01-01', 1, 100, 0),
(2,    2,   NULL, N'ABC',      '2019-06-30', 2, 200, 0),
(3,    3,   3.25, N'',         NULL,         3, 300, 0),
(4, NULL,   0.00, NULL,        '2021-12-31', 4, 400, 0),
(5,    5,  -1.00, N'O''Brien', '2020-01-02', 5, 500, 0),
(6,   -9,  99.99, N'x "y"',    '1959-12-31', 6, 600, 0),
(7,    0,   NULL, N'abd',      '2020-01-01', 7, 700, 0),
(8, NULL,   5.00, N'Abc',      NULL,         8, 800, 0);

CREATE TABLE ref.sqldta_test_part (
    id     int          NOT NULL,
    extra1 int          NULL,
    extra2 nvarchar(20) NULL,
    shared int          NULL
);
-- id 7 has no row here, so its extra1 and extra2 are missing after the join
INSERT INTO ref.sqldta_test_part (id, extra1, extra2, shared) VALUES
(1, 10, N'p1', -1), (2, 20, N'p2', -1), (3, 30, N'p3', -1), (4, 40, N'p4', -1),
(5, 50, N'p5', -1), (6, 60, N'p6', -1), (8, 80, N'p8', -1);

CREATE TABLE sqldta_test.sqldta_test_part2 (id int NOT NULL, extra3 int NULL, stamp datetime NULL);
INSERT INTO sqldta_test.sqldta_test_part2 (id, extra3, stamp) VALUES
(1, 1001, '2020-01-01T12:00:00.500'), (2, 1002, '2020-01-02T12:00:00.500'),
(3, 1003, '2020-01-03T12:00:00.500'), (4, 1004, '2020-01-04T12:00:00.500'),
(5, 1005, '2020-01-05T12:00:00.500'), (6, 1006, '2020-01-06T12:00:00.500'),
(7, 1007, '2020-01-07T12:00:00.500'), (8, 1008, '2020-01-08T12:00:00.500');

CREATE TABLE sqldta_test.sqldta_test_bad (id int NOT NULL, v int NULL);
INSERT INTO sqldta_test.sqldta_test_bad (id, v) VALUES (1, 1), (2, 2);

CREATE TABLE sqldta_test.sqldta_test_dupkey (id int NOT NULL, w int NULL);
INSERT INTO sqldta_test.sqldta_test_dupkey (id, w) VALUES (1, 1), (1, 2), (2, 3);

CREATE TABLE sqldta_test.sqldta_test_badnames ([01 First Column] int NULL, [Second Column] int NULL, [in] int NULL);
INSERT INTO sqldta_test.sqldta_test_badnames ([01 First Column], [Second Column], [in]) VALUES (1, 1, 1), (2, 2, 2);

-- Label rows for the fixture data tables. Expected result of loading
-- sqldta_test_main with labels(variables formats varnotes dtanotes datalabel),
-- or with labels(all), since it has no value labels: variable labels 1,
-- display formats 2, variable notes 7, dataset notes 2, label rows skipped 1
-- (the row whose format is not valid), and the data label from DatasetLabel.
INSERT INTO sqldta_test.sqldta_test_labels (TableSchema, TableName, ColumnName, PropertyType, DataType, PropertyCode, PropertyText) VALUES
(N'sqldta_test', N'sqldta_test_main', N'id',     N'Link',     NULL, NULL,  N'ref.sqldta_test_part'),
(N'sqldta_test', N'sqldta_test_main', N'id',     N'Link',     NULL, NULL,  N'sqldta_test_part2'),
(N'sqldta_test', N'sqldta_test_bad',  N'id',     N'Link',     NULL, NULL,  N'sqldta_test.sqldta_test_dupkey'),
(N'ref', N'sqldta_test_part', N'extra1', N'VariableLabel',      NULL, NULL,  N'Extra one, labelled under the linked table'),
(N'sqldta_test', N'sqldta_test_main', NULL,      N'DatasetLabel', NULL, NULL,  N'Fixture main table'),
(N'sqldta_test', N'sqldta_test_main', N'amount', N'VariableFormat', NULL, NULL,  N'%9.2fc'),
(N'sqldta_test', N'sqldta_test_main', N'dob',    N'VariableFormat', NULL, NULL,  N'%tdDD/NN/CCYY'),
(N'sqldta_test', N'sqldta_test_main', N'num',    N'VariableFormat', NULL, NULL,  N'not a format'),
(N'sqldta_test', N'sqldta_test_main', N'num',    N'VariableNote',  NULL, N'2',  N'Second note on num'),
(N'sqldta_test', N'sqldta_test_main', N'num',    N'VariableNote',  NULL, N'10', N'Third note on num'),
(N'sqldta_test', N'sqldta_test_main', N'num',    N'VariableNote',  NULL, N'1',  N'First note on num'),
(N'sqldta_test', N'sqldta_test_main', N'num',    N'VariableNote',  NULL, NULL,  N'Note on num without an order'),
(N'sqldta_test', N'sqldta_test_main', N'grp',    N'VariableNote',  NULL, N'b',  N'Second note on grp'),
(N'sqldta_test', N'sqldta_test_main', N'grp',    N'VariableNote',  NULL, N'c',  N'Third note on grp'),
(N'sqldta_test', N'sqldta_test_main', N'grp',    N'VariableNote',  NULL, N'a',  N'First note on grp'),
(N'sqldta_test', N'sqldta_test_main', NULL,      N'DatasetNote',  NULL, N'2',  N'Second dataset note'),
(N'sqldta_test', N'sqldta_test_main', NULL,      N'DatasetNote',  NULL, N'1',  N'First dataset note');

-- Fixture tables of SQL Server data types. sqldta_test_types has one column
-- of each type that tables for analysis commonly have; sqldta_test_rare has
-- types that they seldom have and that odbc load may not support, so that a
-- failure there does not stop the tests on the common types. Each column is
-- named after its type, and its VariableLabel row gives the type in full, so
-- that the type report in tests/test_sqldta.do can show it.
--
-- Rows of sqldta_test_types: 1 typical values, 2 extreme or unusual values,
-- 3 all NULL, 4 other extremes, empty strings and zero, 5 small values, 6 an
-- e with an acute accent in the char, varchar(max) and text columns and
-- trailing spaces in the varchar and nvarchar columns, with the other columns
-- NULL.
-- Dates and times are written in the ISO form with a T, which SQL Server
-- reads the same way whatever the login's language and DATEFORMAT; datetime
-- and smalldatetime read 'yyyy-mm-dd hh:mm:ss' according to DATEFORMAT.
-- Characters outside ASCII are written with NCHAR() and CHAR(), so that the
-- file reads the same whatever encoding the editor assumes.
--
-- Expected result of loading sqldta_test_types with labels(all):
-- value-label sets 2, variable labels 30, display formats 2, variable notes
-- 1, dataset notes 1, label rows skipped 0. The ValueLabel row for xvarchar
-- is passed over, and not counted as skipped, because the column is a string.

CREATE TABLE sqldta_test.sqldta_test_types (
    id                int               NOT NULL,
    xbit              bit               NULL,
    xtinyint          tinyint           NULL,
    xsmallint         smallint          NULL,
    xint              int               NULL,
    xbigint           bigint            NULL,
    xdecimal          decimal(9,2)      NULL,
    xdecimal38        decimal(38,10)    NULL,
    xnumeric          numeric(18,0)     NULL,
    xmoney            money             NULL,
    xsmallmoney       smallmoney        NULL,
    xfloat            float             NULL,
    xreal             real              NULL,
    xdate             date              NULL,
    xtime             time(7)           NULL,
    xdatetime         datetime          NULL,
    xdatetime2        datetime2(7)      NULL,
    xsmalldatetime    smalldatetime     NULL,
    xdatetimeoffset   datetimeoffset(7) NULL,
    xchar             char(5)           NULL,
    xvarchar          varchar(50)       NULL,
    xvarcharmax       varchar(max)      NULL,
    xnchar            nchar(5)          NULL,
    xnvarchar         nvarchar(50)      NULL,
    xnvarcharmax      nvarchar(max)     NULL,
    xtext             text              NULL,
    xntext            ntext             NULL,
    xuniqueidentifier uniqueidentifier  NULL,
    xnumeric5         numeric(5,0)      NULL,
    xdecimal15        decimal(15,3)     NULL,
    xdecimal16        decimal(16,2)     NULL
);

INSERT INTO sqldta_test.sqldta_test_types (id, xbit, xtinyint, xsmallint, xint, xbigint,
    xdecimal, xdecimal38, xnumeric, xmoney, xsmallmoney, xfloat, xreal,
    xdate, xtime, xdatetime, xdatetime2, xsmalldatetime, xdatetimeoffset,
    xchar, xvarchar, xvarcharmax, xnchar, xnvarchar, xnvarcharmax, xtext, xntext,
    xuniqueidentifier, xnumeric5, xdecimal15, xdecimal16) VALUES
-- 1: typical values, with fractions of a second
(1, 1, 1, 1, 1, 1,
    1.25, 1.2345678901, 1, 1.2345, 1.5, 1.5, 1.5,
    '2020-01-01', '13:45:30.1234567', '2020-01-01T13:45:30.123', '2020-01-01T13:45:30.1234567',
    '2020-01-01T13:45:00', '2020-01-01T13:45:30.1234567+10:00',
    'ab', 'abc', 'abc', N'ab', N'abc', N'abc', 'abc', N'abc',
    '6F9619FF-8B86-D011-B42D-00C04FC964FF', 12345, 123456789012.345, 12345678901234.56),
-- 2: extremes: 2^53 + 1, which a double cannot hold, the largest money value,
-- 38 digits, the earliest datetime and datetime2, strings longer than 2045
-- characters, an e with an acute accent in a varchar (in a Latin1 code page),
-- and characters outside ASCII in the Unicode columns
(2, 0, 255, -32768, 2147483647, 9007199254740993,
    9999999.99, 1234567890123456789012345678.0123456789, 123456789012345678,
    922337203685477.5807, -214748.3648, 1e300, 1e30,
    '1900-01-01', '00:00:00', '1753-01-01T00:00:00', '0001-01-01T00:00:00',
    '1900-01-01T00:00:00', '2020-06-30T23:59:59.9999999+00:00',
    'abcde', 'caf' + CHAR(233), REPLICATE(CAST('x' AS varchar(max)), 3000),
    NCHAR(256) + NCHAR(274) + NCHAR(298) + NCHAR(332) + NCHAR(362),
    N'Z' + NCHAR(252) + N'rich ' + NCHAR(26481) + NCHAR(20140),
    REPLICATE(CAST(NCHAR(233) AS nvarchar(max)), 3000),
    REPLICATE(CAST('z' AS varchar(max)), 3000),
    N'M' + NCHAR(257) + N'ori',
    '00000000-0000-0000-0000-000000000000', 99999, 999999999999.999, 99999999999999.99),
-- 3: every column NULL
(3, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL),
-- 4: the latest dates and times, zero, negative values and empty strings
(4, 0, 0, 5, -5, -9,
    -0.5, -0.0000000001, 0, 0, 0, -2.5, 0.25,
    '9999-12-31', '23:59:59.9999999', '9999-12-31T23:59:59.997', '9999-12-31T23:59:59.9999999',
    '2079-06-06T23:59:00', '1959-12-31T23:00:00-01:00',
    '', '', '', N'', N'', N'', '', N'',
    'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF', -5, -0.001, -0.01),
-- 5: small values; the varchar(max) value is 10,000 characters long
(5, 1, 3, 3, 3, 3,
    3.00, 3, 3, 3, 3, 3, 3,
    '2019-06-30', '06:00:00', '2019-06-30T06:00:00', '2019-06-30T06:00:00',
    '2019-06-30T06:00:00', '2019-06-30T06:00:00+10:00',
    'abc', 'O''Brien', REPLICATE(CAST('y' AS varchar(max)), 10000), N'abd', N'abd', N'x "y"', 'z', N'z',
    '6F9619FF-8B86-D011-B42D-00C04FC964FF', 3, 3.000, 3.00),
-- 6: an e with an acute accent in char, varchar(max) and text, and two
-- trailing spaces in varchar and nvarchar
(6, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL,
    'caf' + CHAR(233), 'ab  ', 'caf' + CHAR(233), NULL, N'ab  ', NULL, 'caf' + CHAR(233), NULL,
    NULL, NULL, NULL, NULL);

CREATE TABLE sqldta_test.sqldta_test_rare (
    id           int           NOT NULL,
    xbinary      binary(4)     NULL,
    xvarbinary   varbinary(16) NULL,
    ximage       image         NULL,
    xxml         xml           NULL,
    xsqlvariant  sql_variant   NULL,
    xhierarchyid hierarchyid   NULL,
    xgeography   geography     NULL,
    xgeometry    geometry      NULL,
    xrowversion  rowversion
);

-- xrowversion is filled in by SQL Server
INSERT INTO sqldta_test.sqldta_test_rare (id, xbinary, xvarbinary, ximage, xxml, xsqlvariant,
    xhierarchyid, xgeography, xgeometry) VALUES
(1, 0x01020304, 0xDEADBEEF, 0x89504E47, N'<a b="1">text</a>', CAST(42 AS sql_variant),
    hierarchyid::Parse(N'/1/2/'), geography::Point(10, 20, 4326), geometry::STGeomFromText(N'POINT (1 2)', 0)),
(2, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- sqldta_test_dt holds date-time and time values around one instant,
-- 2020-01-01 13:45:30.123, for the tests of the if qualifier, which compare
-- the rows that sqldta selects with the rows that keep if leaves. sqldta loads
-- whole milliseconds, so rows 1 and 2 load the same datetime2 value and row 3
-- one millisecond less. Rows: 1 the instant; 2 just after it, below the next
-- millisecond, and for datetimeoffset the same instant at offset +00:00; 3
-- just before it; 4 and 5 the datetime steps .003 and .007; 6 every column
-- NULL; 7 the earliest values, with datetime2 values before 01jan0100, which
-- Stata cannot hold; 8 the latest values; 9 01jan1960 00:00, which is 0 in
-- Stata; 10 midnight, and a time below one millisecond; 11 the end of the day
-- before; 12 another date, with half a second.

CREATE TABLE sqldta_test.sqldta_test_dt (
    id              int               NOT NULL,
    xdatetime       datetime          NULL,
    xdatetime2      datetime2(7)      NULL,
    xdatetime2_3    datetime2(3)      NULL,
    xdatetime2_0    datetime2(0)      NULL,
    xsmalldatetime  smalldatetime     NULL,
    xdatetimeoffset datetimeoffset(7) NULL,
    xtime           time(7)           NULL,
    xtime0          time(0)           NULL,
    xdate           date              NULL
);

INSERT INTO sqldta_test.sqldta_test_dt (id, xdatetime, xdatetime2, xdatetime2_3, xdatetime2_0,
    xsmalldatetime, xdatetimeoffset, xtime, xtime0, xdate) VALUES
(1,  '2020-01-01T13:45:30.123', '2020-01-01T13:45:30.1230000', '2020-01-01T13:45:30.123',
     '2020-01-01T13:45:30', '2020-01-01T13:45:00', '2020-01-01T13:45:30.1230000+10:00',
     '13:45:30.1230000', '13:45:30', '2020-01-01'),
(2,  '2020-01-01T13:45:30.127', '2020-01-01T13:45:30.1234567', '2020-01-01T13:45:30.124',
     '2020-01-01T13:45:31', '2020-01-01T13:46:00', '2020-01-01T03:45:30.1234567+00:00',
     '13:45:30.1234567', '13:45:31', '2020-01-02'),
(3,  '2020-01-01T13:45:30.120', '2020-01-01T13:45:30.1229999', '2020-01-01T13:45:30.122',
     '2020-01-01T13:45:29', '2020-01-01T13:44:00', '2020-01-01T13:45:30.1229999-01:00',
     '13:45:30.1229999', '13:45:29', '2019-12-31'),
(4,  '2020-01-01T13:45:30.003', '2020-01-01T13:45:30.0030000', '2020-01-01T13:45:30.003',
     '2020-01-01T13:45:30', '2020-01-01T13:45:00', '2020-01-01T13:45:30.0030000+05:30',
     '13:45:30.0030000', '13:45:30', '2020-01-01'),
(5,  '2020-01-01T13:45:30.007', '2020-01-01T13:45:30.0070001', '2020-01-01T13:45:30.007',
     '2020-01-01T13:45:30', '2020-01-01T13:45:00', '2020-01-01T13:45:30.0069999-05:00',
     '13:45:30.0070001', '13:45:30', '2020-01-01'),
(6,  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(7,  '1753-01-01T00:00:00', '0001-01-01T00:00:00', '0099-12-31T23:59:59.999',
     '0100-01-01T00:00:00', '1900-01-01T00:00:00', '0001-01-01T00:00:00+00:00',
     '00:00:00', '00:00:00', '1900-01-01'),
(8,  '9999-12-31T23:59:59.997', '9999-12-31T23:59:59.9999999', '9999-12-31T23:59:59.999',
     '9999-12-31T23:59:59', '2079-06-06T23:59:00', '9999-12-31T23:59:59.9999999+14:00',
     '23:59:59.9999999', '23:59:59', '9999-12-31'),
(9,  '1960-01-01T00:00:00', '1960-01-01T00:00:00', '1960-01-01T00:00:00',
     '1960-01-01T00:00:00', '1960-01-01T00:00:00', '1960-01-01T00:00:00+00:00',
     '00:00:00', '00:00:00', '1960-01-01'),
(10, '2020-01-01T00:00:00', '2020-01-01T00:00:00', '2020-01-01T00:00:00',
     '2020-01-01T00:00:00', '2020-01-01T00:00:00', '2020-01-01T00:00:00-01:00',
     '00:00:00.0004', '00:00:01', '2020-01-01'),
(11, '2019-12-31T23:59:59.997', '2019-12-31T23:59:59.9999999', '2019-12-31T23:59:59.999',
     '2019-12-31T23:59:59', '2019-12-31T23:59:00', '2019-12-31T23:59:59.9999999+10:00',
     '23:59:59.9995', '12:00:00', '2019-12-31'),
(12, '2021-06-15T08:00:00', '2021-06-15T08:00:00.5', '2021-06-15T08:00:00.5',
     '2021-06-15T08:00:00', '2021-06-15T08:00:00', '2021-06-15T08:00:00+09:30',
     '08:00:00.5', '08:00:00', '2021-06-15');

-- Label rows for the data-type tables: a VariableLabel row for every column,
-- giving its type, and ValueLabel, VariableFormat, VariableNote, DatasetNote
-- and data label rows for the types table. The format of xdate and the data
-- label are in rows of the types Format and DataLabel, the names that sqldta
-- 1.0.0 used for VariableFormat and DatasetLabel, which sqldta still reads.
INSERT INTO sqldta_test.sqldta_test_labels (TableSchema, TableName, ColumnName, PropertyType, DataType, PropertyCode, PropertyText) VALUES
(N'sqldta_test', N'sqldta_test_types', N'xbit',              N'VariableLabel', NULL, NULL, N'bit'),
(N'sqldta_test', N'sqldta_test_types', N'xtinyint',          N'VariableLabel', NULL, NULL, N'tinyint'),
(N'sqldta_test', N'sqldta_test_types', N'xsmallint',         N'VariableLabel', NULL, NULL, N'smallint'),
(N'sqldta_test', N'sqldta_test_types', N'xint',              N'VariableLabel', NULL, NULL, N'int'),
(N'sqldta_test', N'sqldta_test_types', N'xbigint',           N'VariableLabel', NULL, NULL, N'bigint'),
(N'sqldta_test', N'sqldta_test_types', N'xdecimal',          N'VariableLabel', NULL, NULL, N'decimal(9,2)'),
(N'sqldta_test', N'sqldta_test_types', N'xdecimal38',        N'VariableLabel', NULL, NULL, N'decimal(38,10)'),
(N'sqldta_test', N'sqldta_test_types', N'xnumeric',          N'VariableLabel', NULL, NULL, N'numeric(18,0)'),
(N'sqldta_test', N'sqldta_test_types', N'xmoney',            N'VariableLabel', NULL, NULL, N'money'),
(N'sqldta_test', N'sqldta_test_types', N'xsmallmoney',       N'VariableLabel', NULL, NULL, N'smallmoney'),
(N'sqldta_test', N'sqldta_test_types', N'xfloat',            N'VariableLabel', NULL, NULL, N'float'),
(N'sqldta_test', N'sqldta_test_types', N'xreal',             N'VariableLabel', NULL, NULL, N'real'),
(N'sqldta_test', N'sqldta_test_types', N'xdate',             N'VariableLabel', NULL, NULL, N'date'),
(N'sqldta_test', N'sqldta_test_types', N'xtime',             N'VariableLabel', NULL, NULL, N'time(7)'),
(N'sqldta_test', N'sqldta_test_types', N'xdatetime',         N'VariableLabel', NULL, NULL, N'datetime'),
(N'sqldta_test', N'sqldta_test_types', N'xdatetime2',        N'VariableLabel', NULL, NULL, N'datetime2(7)'),
(N'sqldta_test', N'sqldta_test_types', N'xsmalldatetime',    N'VariableLabel', NULL, NULL, N'smalldatetime'),
(N'sqldta_test', N'sqldta_test_types', N'xdatetimeoffset',   N'VariableLabel', NULL, NULL, N'datetimeoffset(7)'),
(N'sqldta_test', N'sqldta_test_types', N'xchar',             N'VariableLabel', NULL, NULL, N'char(5)'),
(N'sqldta_test', N'sqldta_test_types', N'xvarchar',          N'VariableLabel', NULL, NULL, N'varchar(50)'),
(N'sqldta_test', N'sqldta_test_types', N'xvarcharmax',       N'VariableLabel', NULL, NULL, N'varchar(max)'),
(N'sqldta_test', N'sqldta_test_types', N'xnchar',            N'VariableLabel', NULL, NULL, N'nchar(5)'),
(N'sqldta_test', N'sqldta_test_types', N'xnvarchar',         N'VariableLabel', NULL, NULL, N'nvarchar(50)'),
(N'sqldta_test', N'sqldta_test_types', N'xnvarcharmax',      N'VariableLabel', NULL, NULL, N'nvarchar(max)'),
(N'sqldta_test', N'sqldta_test_types', N'xtext',             N'VariableLabel', NULL, NULL, N'text'),
(N'sqldta_test', N'sqldta_test_types', N'xntext',            N'VariableLabel', NULL, NULL, N'ntext'),
(N'sqldta_test', N'sqldta_test_types', N'xuniqueidentifier', N'VariableLabel', NULL, NULL, N'uniqueidentifier'),
(N'sqldta_test', N'sqldta_test_types', N'xnumeric5',         N'VariableLabel', NULL, NULL, N'numeric(5,0)'),
(N'sqldta_test', N'sqldta_test_types', N'xdecimal15',        N'VariableLabel', NULL, NULL, N'decimal(15,3)'),
(N'sqldta_test', N'sqldta_test_types', N'xdecimal16',        N'VariableLabel', NULL, NULL, N'decimal(16,2)'),
(N'sqldta_test', N'sqldta_test_types', N'xtinyint',  N'ValueLabel', N'INT', N'0',   N'zero'),
(N'sqldta_test', N'sqldta_test_types', N'xtinyint',  N'ValueLabel', N'INT', N'1',   N'one'),
(N'sqldta_test', N'sqldta_test_types', N'xtinyint',  N'ValueLabel', N'INT', N'3',   N'three'),
(N'sqldta_test', N'sqldta_test_types', N'xtinyint',  N'ValueLabel', N'INT', N'255', N'largest'),
(N'sqldta_test', N'sqldta_test_types', N'xbit',      N'ValueLabel', N'INT', N'0',   N'No'),
(N'sqldta_test', N'sqldta_test_types', N'xbit',      N'ValueLabel', N'INT', N'1',   N'Yes'),
(N'sqldta_test', N'sqldta_test_types', N'xtinyint',  N'ValueLabel', NULL,   N'2',   N'two, with no DataType'),
(N'sqldta_test', N'sqldta_test_types', N'xvarchar',  N'ValueLabel', N'INT', N'1',   N'A string column, so passed over and not counted'),
(N'sqldta_test', N'sqldta_test_types', N'xdatetime', N'VariableFormat', NULL, NULL, N'%tcCCYY-NN-DD_HH:MM:SS.sss'),
(N'sqldta_test', N'sqldta_test_types', N'xdate',     N'Format',  NULL, NULL, N'%tdCCYY-NN-DD'),
(N'sqldta_test', N'sqldta_test_types', N'xdatetime', N'VariableNote', NULL, NULL, N'Note on a datetime column'),
(N'sqldta_test', N'sqldta_test_types', NULL,         N'DatasetNote', NULL, NULL, N'Each column has a different SQL Server data type'),
(N'sqldta_test', N'sqldta_test_types', NULL,         N'DataLabel', NULL, NULL, N'Fixture table of SQL Server data types'),
(N'sqldta_test', N'sqldta_test_rare',  N'xbinary',      N'VariableLabel', NULL, NULL, N'binary(4)'),
(N'sqldta_test', N'sqldta_test_rare',  N'xvarbinary',   N'VariableLabel', NULL, NULL, N'varbinary(16)'),
(N'sqldta_test', N'sqldta_test_rare',  N'ximage',       N'VariableLabel', NULL, NULL, N'image'),
(N'sqldta_test', N'sqldta_test_rare',  N'xxml',         N'VariableLabel', NULL, NULL, N'xml'),
(N'sqldta_test', N'sqldta_test_rare',  N'xsqlvariant',  N'VariableLabel', NULL, NULL, N'sql_variant'),
(N'sqldta_test', N'sqldta_test_rare',  N'xhierarchyid', N'VariableLabel', NULL, NULL, N'hierarchyid'),
(N'sqldta_test', N'sqldta_test_rare',  N'xgeography',   N'VariableLabel', NULL, NULL, N'geography'),
(N'sqldta_test', N'sqldta_test_rare',  N'xgeometry',    N'VariableLabel', NULL, NULL, N'geometry'),
(N'sqldta_test', N'sqldta_test_rare',  N'xrowversion',  N'VariableLabel', NULL, NULL, N'rowversion'),
(N'sqldta_test', N'sqldta_test_dt',    N'xdatetime',       N'VariableLabel', NULL, NULL, N'datetime'),
(N'sqldta_test', N'sqldta_test_dt',    N'xdatetime2',      N'VariableLabel', NULL, NULL, N'datetime2(7)'),
(N'sqldta_test', N'sqldta_test_dt',    N'xdatetime2_3',    N'VariableLabel', NULL, NULL, N'datetime2(3)'),
(N'sqldta_test', N'sqldta_test_dt',    N'xdatetime2_0',    N'VariableLabel', NULL, NULL, N'datetime2(0)'),
(N'sqldta_test', N'sqldta_test_dt',    N'xsmalldatetime',  N'VariableLabel', NULL, NULL, N'smalldatetime'),
(N'sqldta_test', N'sqldta_test_dt',    N'xdatetimeoffset', N'VariableLabel', NULL, NULL, N'datetimeoffset(7)'),
(N'sqldta_test', N'sqldta_test_dt',    N'xtime',           N'VariableLabel', NULL, NULL, N'time(7)'),
(N'sqldta_test', N'sqldta_test_dt',    N'xtime0',          N'VariableLabel', NULL, NULL, N'time(0)'),
(N'sqldta_test', N'sqldta_test_dt',    N'xdate',           N'VariableLabel', NULL, NULL, N'date');

-- sqldta_test_view is a view of three columns of sqldta_test_main, for the
-- tests of the dialog helper, which lists tables and views, and of loading a
-- view. Its DatasetLabel and DatasetNote rows contain double quotes, a backquote
-- and a dollar sign, so that the description the helper returns can be compared
-- exactly with the rows.
EXEC (N'CREATE VIEW sqldta_test.sqldta_test_view AS SELECT id, num, grp FROM sqldta_test.sqldta_test_main');

INSERT INTO sqldta_test.sqldta_test_labels (TableSchema, TableName, ColumnName, PropertyType, DataType, PropertyCode, PropertyText) VALUES
(N'sqldta_test', N'sqldta_test_view', NULL, N'DatasetLabel', NULL, NULL, N'View of the "main" fixture table'),
(N'sqldta_test', N'sqldta_test_view', NULL, N'DatasetNote',  NULL, N'2',  N'Second note on the view'),
(N'sqldta_test', N'sqldta_test_view', NULL, N'DatasetNote',  NULL, N'1',  N'First note on the view, with "double quotes", a `backquote'' and $HOME');

-- sqldta_test_wide has an id and 1,000 varchar(10) columns, c0001 to c1000,
-- for the test of loading with clear into a frame that holds data: with
-- unicode(*), sqldta sends each varchar column as an expression, so its query
-- is long. odbc load's own clear did not empty the frame after a long query,
-- and stopped with r(18) (archive 46d4e17). Rows: 1 with c0001 'a' and c1000 'z'; 2 with c0001 'b' and
-- c1000 NULL. The table is made with dynamic SQL, so that the file stays
-- short.
DECLARE @widecols nvarchar(max) = N'';
DECLARE @widei int = 1;
WHILE @widei <= 1000
BEGIN
    SET @widecols = @widecols + N', c' + RIGHT(N'000' + CAST(@widei AS nvarchar(4)), 4) + N' varchar(10) NULL';
    SET @widei = @widei + 1;
END;
EXEC (N'CREATE TABLE sqldta_test.sqldta_test_wide (id int NOT NULL' + @widecols + N')');
EXEC (N'INSERT INTO sqldta_test.sqldta_test_wide (id, c0001, c1000) VALUES (1, ''a'', ''z''), (2, ''b'', NULL)');

-- sqldta_test_umain is linked by id, through a Link row, to sqldta_test_upart,
-- for unicode() on the columns of a main table and of a linked table. Their
-- varchar and char columns hold text outside ASCII, written with CHAR() in
-- the database's code page (1252 under Latin1_General collations): umain.utext
-- row 2 'cafe' with an e acute; upart.ulinked row 1 'naive' with an i
-- diaeresis; upart.uchar row 2 'ete' with two e acutes, in char(6), so padded.
-- uplain is varchar holding ASCII only.
CREATE TABLE sqldta_test.sqldta_test_umain (id int NOT NULL, utext varchar(20) NULL, uplain varchar(20) NULL);
INSERT INTO sqldta_test.sqldta_test_umain (id, utext, uplain) VALUES
(1, 'abc', 'one'), (2, 'caf' + CHAR(233), 'two'), (3, NULL, NULL);
CREATE TABLE sqldta_test.sqldta_test_upart (id int NOT NULL, ulinked varchar(20) NULL, uchar char(6) NULL);
INSERT INTO sqldta_test.sqldta_test_upart (id, ulinked, uchar) VALUES
(1, 'na' + CHAR(239) + 've', 'x'), (2, 'plain', CHAR(233) + 't' + CHAR(233)), (3, NULL, NULL);
INSERT INTO sqldta_test.sqldta_test_labels (TableSchema, TableName, ColumnName, PropertyType, DataType, PropertyCode, PropertyText) VALUES
(N'sqldta_test', N'sqldta_test_umain', N'id', N'Link', NULL, NULL, N'sqldta_test_upart');

-- sqldta_test_lbl has an id, 20 int columns v01 to v20 and a varchar column
-- vs, with 3 rows, for the label step: 1,000 generated ValueLabel rows, codes
-- 1 to 50 for each of v01 to v20 with the text 'v01 code 1' and so on, and a
-- VariableLabel row for each, 'Variable v01' and so on. Further ValueLabel
-- rows: v03 code 51 with
-- quotes, a backquote and $; v04 codes -2147483647 and 2147483620, the ends
-- of the range of a long, which sqldta sets with st_vlmodify(), and code
-- 2147483647, above that range, which goes to label define, so that the test
-- can compare the result with label define's own (added after the test log
-- of archive 717d9c3); and rows that must count as skipped: v05 code
-- 99999999999, which label define refuses; v06 code 1.5, not a whole number;
-- and a row for a column that does not exist. A ValueLabel row for the string
-- column vs is passed over and not counted. Expected result of loading it
-- with labels(all): value-label sets 20, variable labels 20, label rows
-- skipped 3, or 4 if label define refuses code 2147483647.
CREATE TABLE sqldta_test.sqldta_test_lbl (id int NOT NULL,
    v01 int NULL, v02 int NULL, v03 int NULL, v04 int NULL, v05 int NULL,
    v06 int NULL, v07 int NULL, v08 int NULL, v09 int NULL, v10 int NULL,
    v11 int NULL, v12 int NULL, v13 int NULL, v14 int NULL, v15 int NULL,
    v16 int NULL, v17 int NULL, v18 int NULL, v19 int NULL, v20 int NULL,
    vs varchar(10) NULL);
INSERT INTO sqldta_test.sqldta_test_lbl (id, v01, v02, v03, v04, v05, vs) VALUES
(1, 1, 2, 51, -2147483647, 50, 'a'), (2, 50, 49, 3, 2147483647, NULL, 'b'), (3, NULL, NULL, NULL, NULL, 7, NULL);
WITH n AS (SELECT TOP (50) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS k FROM sys.all_objects),
v AS (SELECT TOP (20) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS j FROM sys.all_objects)
INSERT INTO sqldta_test.sqldta_test_labels (TableSchema, TableName, ColumnName, PropertyType, DataType, PropertyCode, PropertyText)
SELECT N'sqldta_test', N'sqldta_test_lbl', N'v' + RIGHT(N'0' + CAST(v.j AS nvarchar(2)), 2), N'ValueLabel', N'INT',
    CAST(n.k AS nvarchar(50)),
    N'v' + RIGHT(N'0' + CAST(v.j AS nvarchar(2)), 2) + N' code ' + CAST(n.k AS nvarchar(10))
FROM v CROSS JOIN n;
WITH v AS (SELECT TOP (20) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS j FROM sys.all_objects)
INSERT INTO sqldta_test.sqldta_test_labels (TableSchema, TableName, ColumnName, PropertyType, DataType, PropertyCode, PropertyText)
SELECT N'sqldta_test', N'sqldta_test_lbl', N'v' + RIGHT(N'0' + CAST(v.j AS nvarchar(2)), 2), N'VariableLabel', NULL, NULL,
    N'Variable v' + RIGHT(N'0' + CAST(v.j AS nvarchar(2)), 2)
FROM v;
INSERT INTO sqldta_test.sqldta_test_labels (TableSchema, TableName, ColumnName, PropertyType, DataType, PropertyCode, PropertyText) VALUES
(N'sqldta_test', N'sqldta_test_lbl', N'v03', N'ValueLabel', NULL, N'51', N'He said "it''s" `x'' and $y'),
(N'sqldta_test', N'sqldta_test_lbl', N'v04', N'ValueLabel', NULL, N'-2147483647', N'smallest'),
(N'sqldta_test', N'sqldta_test_lbl', N'v04', N'ValueLabel', NULL, N'2147483620', N'largest'),
(N'sqldta_test', N'sqldta_test_lbl', N'v04', N'ValueLabel', NULL, N'2147483647', N'above the largest'),
(N'sqldta_test', N'sqldta_test_lbl', N'v05', N'ValueLabel', NULL, N'99999999999', N'out of range'),
(N'sqldta_test', N'sqldta_test_lbl', N'v06', N'ValueLabel', NULL, N'1.5', N'not a whole number'),
(N'sqldta_test', N'sqldta_test_lbl', N'nocolumn', N'ValueLabel', NULL, N'1', N'no such column'),
(N'sqldta_test', N'sqldta_test_lbl', N'vs', N'ValueLabel', NULL, N'1', N'on a string column');

-- Tables of the same name in two schemas (archive HANDOVER.md, section 4.14).
-- sqldta_test.sqldta_test_same and sqldta_alt.sqldta_test_same each have
-- their own label rows, filed under their own schema, and a Link row that
-- names sqldta_test_samepart without a schema, so that each joins the table
-- of that name in its own schema; the one in sqldta_alt also has a Link row to
-- ref.sqldta_test_samex, in another schema, whose own rows are filed under
-- ref ('ref.' sorts before 'sqldta_' under any collation). A row filed under
-- dbo, where there is no such table, is not fetched. Expected results with
-- labels(all):
--   sqldta_test.sqldta_test_same: 3 observations, variables id a b pr, linked
--   table sqldta_test.sqldta_test_samepart, value-label sets 1, variable
--   labels 2, dataset notes 1, label rows skipped 0, data label 'Same name, in
--   sqldta_test';
--   sqldta_alt.sqldta_test_same: 2 observations, variables id a c x pa,
--   linked tables ref.sqldta_test_samex and sqldta_alt.sqldta_test_samepart
--   (in the order of their PropertyText), value-label sets 1, variable labels
--   4, dataset notes 1, label rows skipped 0, data label 'Same name, in
--   sqldta_alt'.

CREATE TABLE sqldta_test.sqldta_test_same (id int NOT NULL, a int NULL, b int NULL);
INSERT INTO sqldta_test.sqldta_test_same (id, a, b) VALUES (1, 1, 10), (2, 2, 20), (3, NULL, 30);
CREATE TABLE sqldta_alt.sqldta_test_same (id int NOT NULL, a int NULL, c int NULL);
INSERT INTO sqldta_alt.sqldta_test_same (id, a, c) VALUES (1, 1, 100), (2, 1, 200);
CREATE TABLE sqldta_test.sqldta_test_samepart (id int NOT NULL, pr int NULL);
INSERT INTO sqldta_test.sqldta_test_samepart (id, pr) VALUES (1, 11), (2, 12), (3, 13);
CREATE TABLE sqldta_alt.sqldta_test_samepart (id int NOT NULL, pa int NULL);
INSERT INTO sqldta_alt.sqldta_test_samepart (id, pa) VALUES (1, 21), (2, 22);
CREATE TABLE ref.sqldta_test_samex (id int NOT NULL, x int NULL);
INSERT INTO ref.sqldta_test_samex (id, x) VALUES (1, 31), (2, 32), (3, 33);

INSERT INTO sqldta_test.sqldta_test_labels (TableSchema, TableName, ColumnName, PropertyType, DataType, PropertyCode, PropertyText) VALUES
(N'sqldta_test', N'sqldta_test_same',     N'id', N'Link',          NULL, NULL, N'sqldta_test_samepart'),
(N'sqldta_test', N'sqldta_test_same',     N'a',  N'VariableLabel', NULL, NULL, N'a, filed under sqldta_test'),
(N'sqldta_test', N'sqldta_test_same',     N'a',  N'ValueLabel',    NULL, N'1', N'one, filed under sqldta_test'),
(N'sqldta_test', N'sqldta_test_same',     NULL,  N'DatasetLabel',  NULL, NULL, N'Same name, in sqldta_test'),
(N'sqldta_test', N'sqldta_test_same',     NULL,  N'DatasetNote',   NULL, NULL, N'Note filed under sqldta_test'),
(N'sqldta_test', N'sqldta_test_samepart', N'pr', N'VariableLabel', NULL, NULL, N'pr, filed under sqldta_test.sqldta_test_samepart'),
(N'sqldta_alt',  N'sqldta_test_same',     N'id', N'Link',          NULL, NULL, N'sqldta_test_samepart'),
(N'sqldta_alt',  N'sqldta_test_same',     N'id', N'Link',          NULL, NULL, N'ref.sqldta_test_samex'),
(N'sqldta_alt',  N'sqldta_test_same',     N'a',  N'VariableLabel', NULL, NULL, N'a, filed under sqldta_alt'),
(N'sqldta_alt',  N'sqldta_test_same',     N'a',  N'ValueLabel',    NULL, N'1', N'one, filed under sqldta_alt'),
(N'sqldta_alt',  N'sqldta_test_same',     N'c',  N'VariableLabel', NULL, NULL, N'c, filed under sqldta_alt'),
(N'sqldta_alt',  N'sqldta_test_same',     NULL,  N'DatasetLabel',  NULL, NULL, N'Same name, in sqldta_alt'),
(N'sqldta_alt',  N'sqldta_test_same',     NULL,  N'DatasetNote',   NULL, NULL, N'Note filed under sqldta_alt'),
(N'sqldta_alt',  N'sqldta_test_samepart', N'pa', N'VariableLabel', NULL, NULL, N'pa, filed under sqldta_alt.sqldta_test_samepart'),
(N'ref',         N'sqldta_test_samex',    N'x',  N'VariableLabel', NULL, NULL, N'x, filed under ref.sqldta_test_samex'),
(N'dbo',         N'sqldta_test_same',     N'a',  N'VariableLabel', NULL, NULL, N'Filed under dbo, so not fetched');

-- sqldta_test_known: 1,000 rows of generated values, in 11 columns whose
-- names are in mixed case, for the tests of lowercase and of names typed in
-- another case. Its label rows are above. Category holds the codes of its
-- value labels (-9, 1 to 8, 10 and 11) or NULL; Score is 0 to 100 or NULL;
-- StartDate and EndDate are date columns, which the legacy "SQL Server" driver
-- returns as text and sqldta converts; Total is bigint below 2^53, which
-- sqldta makes numeric. Column numbers 1 to 10 of the generator give the
-- values of the columns after id.
CREATE TABLE sqldta_test.sqldta_test_known (
    id        int           NOT NULL,
    Category  int           NULL,
    Score     int           NULL,
    Label     varchar(20)   NULL,
    Code      char(4)       NULL,
    StartDate date          NULL,
    EndDate   date          NULL,
    Updated   datetime      NULL,
    Amount    decimal(9,2)  NULL,
    Total     bigint        NULL,
    Flag      bit           NULL
);

WITH d AS (SELECT v FROM (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)) AS t (v)),
n AS (SELECT a.v + 10 * b.v + 100 * c.v + 1 AS r FROM d AS a CROSS JOIN d AS b CROSS JOIN d AS c)
INSERT INTO sqldta_test.sqldta_test_known (id, Category, Score, Label, Code, StartDate, EndDate,
    Updated, Amount, Total, Flag)
SELECT n.r,
    CASE g.g1 % 12 WHEN 0 THEN -9 WHEN 9 THEN 10 WHEN 10 THEN 11 WHEN 11 THEN NULL ELSE g.g1 % 12 END,
    CASE WHEN g.g2 % 20 = 0 THEN NULL ELSE (g.g2 / 20) % 101 END,
    CHOOSE(g.g3 % 12 + 1, 'alpha', 'bravo', 'charlie', 'delta', 'echo', 'foxtrot',
        'golf', 'hotel', 'india', 'juliett', 'kilo', 'lima'),
    CHAR(65 + g.g4 % 26) + CHAR(65 + (g.g4 / 26) % 26) + RIGHT('0' + CAST((g.g4 / 676) % 100 AS varchar(2)), 2),
    s.sd,
    CASE WHEN g.g6 % 10 = 0 THEN NULL ELSE DATEADD(day, (g.g6 / 10) % 366, s.sd) END,
    DATEADD(millisecond, g.g7 % 86400000, CAST(s.sd AS datetime)),
    CAST(((g.g8 % 2000001) - 1000000) / 100.0 AS decimal(9,2)),
    g.g9 * 1000 + n.r,
    CASE g.g10 % 3 WHEN 2 THEN NULL ELSE CAST(g.g10 % 3 AS bit) END
FROM n
CROSS APPLY (SELECT
    sqldta_test.sqldta_test_rnd(@seed, n.r, 1) AS g1, sqldta_test.sqldta_test_rnd(@seed, n.r, 2) AS g2,
    sqldta_test.sqldta_test_rnd(@seed, n.r, 3) AS g3, sqldta_test.sqldta_test_rnd(@seed, n.r, 4) AS g4,
    sqldta_test.sqldta_test_rnd(@seed, n.r, 5) AS g5, sqldta_test.sqldta_test_rnd(@seed, n.r, 6) AS g6,
    sqldta_test.sqldta_test_rnd(@seed, n.r, 7) AS g7, sqldta_test.sqldta_test_rnd(@seed, n.r, 8) AS g8,
    sqldta_test.sqldta_test_rnd(@seed, n.r, 9) AS g9, sqldta_test.sqldta_test_rnd(@seed, n.r, 10) AS g10) AS g
CROSS APPLY (SELECT DATEADD(day, g.g5 % 1827, CAST('20200101' AS date)) AS sd) AS s;

-- sqldta_test_adm: 20,000 generated admissions, with the column names of the
-- README's examples of sqlwhere() and the if qualifier, which tests 213 to 222
-- check on it for January 2023. Rows are admissions; personid repeats, so that
-- people have several. admdate is 1 Jan 2022 to 31 Dec 2024, sepdate 0 to 44
-- days later or NULL, admitted the date of admdate at a generated second, and
-- age 0 to 100 or NULL. Column numbers 1 to 9 of the generator give these and
-- the number of diagnoses of the row, 1 to 8, or 20 for one row in 25; column
-- 100 + k gives diagk, which is NULL after the last diagnosis of the row.
-- The codes have the form of ICD-10-AM codes with their dots, so that the
-- examples' patterns occur and some codes just miss them: I21.0 to I21.9, half
-- of them I21.4; C00.0 to C99.9, of which C98 and C99 fall outside the
-- example's range; J10.0 to J19.9, of which J19 falls outside J1[0-8]; E10.0
-- to E19.9, of which E15 to E19 fall outside E1[0-4]; and other codes. One code
-- in 40 is in lower case and one in 40 ends with a space, which T-SQL ignores
-- in these comparisons and the if qualifier does not.
CREATE TABLE sqldta_test.sqldta_test_adm (
    id       int        NOT NULL,
    personid int        NULL,
    diag1    varchar(8) NULL, diag2  varchar(8) NULL, diag3  varchar(8) NULL, diag4  varchar(8) NULL,
    diag5    varchar(8) NULL, diag6  varchar(8) NULL, diag7  varchar(8) NULL, diag8  varchar(8) NULL,
    diag9    varchar(8) NULL, diag10 varchar(8) NULL, diag11 varchar(8) NULL, diag12 varchar(8) NULL,
    diag13   varchar(8) NULL, diag14 varchar(8) NULL, diag15 varchar(8) NULL, diag16 varchar(8) NULL,
    diag17   varchar(8) NULL, diag18 varchar(8) NULL, diag19 varchar(8) NULL, diag20 varchar(8) NULL,
    admdate  date       NULL,
    sepdate  date       NULL,
    admitted datetime   NULL,
    age      int        NULL
);

WITH d AS (SELECT v FROM (VALUES (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)) AS t (v)),
n AS (SELECT a.v + 10 * b.v + 100 * c.v + 1000 * e.v + 10000 * f.v + 1 AS r
      FROM d AS a CROSS JOIN d AS b CROSS JOIN d AS c CROSS JOIN d AS e CROSS JOIN d AS f)
INSERT INTO sqldta_test.sqldta_test_adm (id, personid, admdate, sepdate, admitted, age)
SELECT n.r,
    1 + g.g1 % 8000,
    s.ad,
    CASE WHEN g.g4 % 50 = 0 THEN NULL ELSE DATEADD(day, g.g3 % 45, s.ad) END,
    DATEADD(second, g.g5 % 86400, CAST(s.ad AS datetime)),
    CASE WHEN g.g7 % 40 = 0 THEN NULL ELSE g.g6 % 101 END
FROM n
CROSS APPLY (SELECT
    sqldta_test.sqldta_test_rnd(@seed, n.r, 1) AS g1, sqldta_test.sqldta_test_rnd(@seed, n.r, 2) AS g2,
    sqldta_test.sqldta_test_rnd(@seed, n.r, 3) AS g3, sqldta_test.sqldta_test_rnd(@seed, n.r, 4) AS g4,
    sqldta_test.sqldta_test_rnd(@seed, n.r, 5) AS g5, sqldta_test.sqldta_test_rnd(@seed, n.r, 6) AS g6,
    sqldta_test.sqldta_test_rnd(@seed, n.r, 7) AS g7) AS g
CROSS APPLY (SELECT DATEADD(day, g.g2 % 1096, CAST('20220101' AS date)) AS ad) AS s
WHERE n.r <= 20000;

-- The diagnosis columns, one UPDATE for each, run through sp_executesql so
-- that the column's name and number can be put in the statement
DECLARE @k int = 1;
DECLARE @sql nvarchar(max);
WHILE @k <= 20
BEGIN
    SET @sql = N'UPDATE sqldta_test.sqldta_test_adm SET diag' + CAST(@k AS nvarchar(2)) + N' =
    CASE (v.x / 10000000) % 40 WHEN 0 THEN LOWER(c.code) WHEN 1 THEN c.code + '' '' ELSE c.code END
FROM sqldta_test.sqldta_test_adm AS a
CROSS APPLY (SELECT sqldta_test.sqldta_test_rnd(@seed, a.id, 100 + @k) AS x,
    CASE WHEN sqldta_test.sqldta_test_rnd(@seed, a.id, 9) % 25 = 0 THEN 20
         ELSE 1 + sqldta_test.sqldta_test_rnd(@seed, a.id, 8) % 8 END AS ndiag) AS v
CROSS APPLY (SELECT CASE
    WHEN v.x % 100 < 6 THEN CASE WHEN (v.x / 100) % 2 = 0 THEN ''I21.4''
                               ELSE ''I21.'' + CAST((v.x / 1000) % 10 AS varchar(1)) END
    WHEN v.x % 100 < 16 THEN ''C'' + RIGHT(''0'' + CAST((v.x / 100) % 100 AS varchar(2)), 2) + ''.''
                             + CAST((v.x / 10000) % 10 AS varchar(1))
    WHEN v.x % 100 < 22 THEN ''J1'' + CAST((v.x / 100) % 10 AS varchar(1)) + ''.''
                             + CAST((v.x / 1000) % 10 AS varchar(1))
    WHEN v.x % 100 < 30 THEN ''E1'' + CAST((v.x / 100) % 10 AS varchar(1)) + ''.''
                             + CAST((v.x / 1000) % 10 AS varchar(1))
    ELSE CHAR(65 + (v.x / 100) % 26) + RIGHT(''0'' + CAST((v.x / 10000) % 100 AS varchar(2)), 2) + ''.''
         + CAST((v.x / 1000000) % 10 AS varchar(1))
    END AS code) AS c
WHERE @k <= v.ndiag';
    EXEC sp_executesql @sql, N'@seed bigint, @k int', @seed = @seed, @k = @k;
    SET @k = @k + 1;
END;

-- sqldta_test_otherlayout: a label table without the columns of the layout,
-- for test 202. sqldta displays a note that names the missing columns and
-- loads the data without labels and without following Link rows.
CREATE TABLE sqldta_test.sqldta_test_otherlayout (
    TableName nvarchar(128) NOT NULL,
    ItemName  nvarchar(128) NULL,
    ItemText  nvarchar(max) NULL
);
INSERT INTO sqldta_test.sqldta_test_otherlayout (TableName, ItemName, ItemText) VALUES
(N'sqldta_test_main', N'num', N'A label in a layout that sqldta does not read');

-- sqldta_test_oldlabels: a label table of the predecessor's layout, which
-- sqldta reads when SQLDTA_LABELFALLBACK names it and the label table is not
-- found (tests 222 to 225). Its rows are filed by the table's name alone, in
-- Dataset. It holds a copy of the rows of the fixture label table for the
-- known table, the split table sqldta_test_main with its linked table
-- ref.sqldta_test_part, and the types table, with their DataType values: the
-- types table's rows keep the current names, and the others take the
-- predecessor's (Opt, Var, NoteVar, NoteDta) and the earlier Format and
-- DtaLabel, so that the table mixes the two, as a site's may. Loaded through
-- it, these tables get the same labels as through the fixture label table.
-- Four rows for sqldta_test_same, which apply to the tables of that name in
-- sqldta_test and sqldta_alt alike, have a type in lower case and a value
-- label whose DataType is not INT: loaded through it, each of the two tables
-- gets value-label sets 1, variable labels 1, dataset notes 1, label rows
-- skipped 0, the data label 'Same name, from the earlier layout', and no
-- linked table. 89 rows.
CREATE TABLE sqldta_test.sqldta_test_oldlabels (
    Dataset   varchar(128) NOT NULL,
    VarName   varchar(128) NULL,
    LabelType varchar(20)  NOT NULL,
    DataType  varchar(20)  NULL,
    DataCode  varchar(50)  NULL,
    LabelName varchar(max) NULL
);
INSERT INTO sqldta_test.sqldta_test_oldlabels (Dataset, VarName, LabelType, DataType, DataCode, LabelName)
SELECT TableName,
       ColumnName,
       CASE WHEN TableName = N'sqldta_test_types' THEN PropertyType
            ELSE CASE PropertyType
                     WHEN N'ValueLabel'     THEN N'Opt'
                     WHEN N'VariableLabel'  THEN N'Var'
                     WHEN N'VariableFormat' THEN N'Format'
                     WHEN N'VariableNote'   THEN N'NoteVar'
                     WHEN N'DatasetNote'    THEN N'NoteDta'
                     WHEN N'DatasetLabel'   THEN N'DtaLabel'
                     ELSE PropertyType
                 END
       END,
       DataType,
       PropertyCode,
       PropertyText
FROM sqldta_test.sqldta_test_labels
WHERE (TableSchema = N'sqldta_test'
       AND TableName IN (N'sqldta_test_known', N'sqldta_test_main', N'sqldta_test_types'))
   OR (TableSchema = N'ref' AND TableName = N'sqldta_test_part');
INSERT INTO sqldta_test.sqldta_test_oldlabels (Dataset, VarName, LabelType, DataType, DataCode, LabelName) VALUES
('sqldta_test_same', 'a',  'var',          NULL,      NULL, 'a, from the earlier layout'),
('sqldta_test_same', 'a',  'Opt',          'VARCHAR', '1',  'one, from the earlier layout'),
('sqldta_test_same', NULL, 'NoteDta',      NULL,      NULL, 'Note from the earlier layout'),
('sqldta_test_same', NULL, 'DatasetLabel', NULL,      NULL, 'Same name, from the earlier layout');

-- dbo.sqldta_test_dflt: a table in dbo, for test 158, which names it without
-- a schema
CREATE TABLE dbo.sqldta_test_dflt (id int NOT NULL, d int NULL);
INSERT INTO dbo.sqldta_test_dflt (id, d) VALUES (1, 1), (2, 2);

-- ref.DataProperties: sqldta's default label table, here a view of the
-- fixture label table, so that a load that names no label table gets the
-- fixture rows, and a label table that is a view is tested too
EXEC (N'CREATE VIEW ref.DataProperties AS
SELECT TableSchema, TableName, ColumnName, PropertyType, PropertyCode, PropertyText
FROM sqldta_test.sqldta_test_labels');

-- The version of the fixtures and the seed of the generated tables, which
-- tests/test_sqldta.do reads before test 1
CREATE TABLE sqldta_test.sqldta_test_version (FixtureVersion int NOT NULL, GeneratorSeed bigint NOT NULL);
INSERT INTO sqldta_test.sqldta_test_version (FixtureVersion, GeneratorSeed) VALUES (@version, @seed);

-- The number of rows of each fixture table. Expected: sqldta_test_labels
-- 1,156, sqldta_test_known 1,000, sqldta_test_adm 20,000, sqldta_test_main 8,
-- sqldta_test_types 6, sqldta_test_dt 12, sqldta_test_wide 2,
-- ref.DataProperties 1,156, sqldta_test_oldlabels 89.
SELECT N'sqldta_test_labels' AS fixture, COUNT(*) AS n_rows FROM sqldta_test.sqldta_test_labels
UNION ALL SELECT N'sqldta_test_known', COUNT(*) FROM sqldta_test.sqldta_test_known
UNION ALL SELECT N'sqldta_test_adm', COUNT(*) FROM sqldta_test.sqldta_test_adm
UNION ALL SELECT N'sqldta_test_main', COUNT(*) FROM sqldta_test.sqldta_test_main
UNION ALL SELECT N'sqldta_test_types', COUNT(*) FROM sqldta_test.sqldta_test_types
UNION ALL SELECT N'sqldta_test_dt', COUNT(*) FROM sqldta_test.sqldta_test_dt
UNION ALL SELECT N'sqldta_test_wide', COUNT(*) FROM sqldta_test.sqldta_test_wide
UNION ALL SELECT N'ref.DataProperties', COUNT(*) FROM ref.DataProperties
UNION ALL SELECT N'sqldta_test_oldlabels', COUNT(*) FROM sqldta_test.sqldta_test_oldlabels;
GO

SET NOEXEC OFF;
