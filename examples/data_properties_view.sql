-- examples/data_properties_view.sql
--
-- For a site whose label table has the layout of sqldta's predecessor and
-- cannot be changed, because other software reads it. Agreed with the
-- maintainer on 21 Oct 2026 (archive HANDOVER.md, section 4.14).
--
-- Builds the label table that sqldta reads by default, ref.DataProperties, as
-- a view over the earlier table, here ref.MyLabelTable, which is not
-- changed. A new table, ref.DataPropertyTables, says which tables each set of
-- rows of the earlier table applies to, so that:
--   - tables of the same name in different schemas can have different labels;
--   - one set of rows can serve several tables, in one schema or in several,
--     under the same name or not, without copying the rows.
-- In a database without the view, the setting SQLDTA_LABELFALLBACK can name
-- the earlier table instead; sqldta then reads it directly, with each set of
-- rows applied to every table of its name, whatever the schema.
--
-- The layout of the view, which sqldta reads:
--   TableSchema   schema of the table or view the row applies to
--   TableName     name of that table or view
--   ColumnName    the column; empty for rows about the table itself
--   PropertyType  ValueLabel, VariableLabel, VariableFormat, VariableNote,
--                 DatasetNote, DatasetLabel or Link
--   PropertyCode  the code of a value label; the order of a note
--   PropertyText  the label, note, display format, data label or linked table
-- The view takes them from ref.MyLabelTable as follows:
--   Dataset   -> TableName, through ref.DataPropertyTables, with TableSchema
--   VarName   -> ColumnName
--   LabelType -> PropertyType: Opt -> ValueLabel, Var -> VariableLabel,
--                Format -> VariableFormat, NoteVar -> VariableNote,
--                NoteDta -> DatasetNote, DtaLabel -> DatasetLabel, Link -> Link
--   DataCode  -> PropertyCode
--   LabelName -> PropertyText
-- Other columns of ref.MyLabelTable, such as DataType, are not passed on.
-- The names VariableFormat and DatasetLabel need sqldta 1.1.0 or later.
--
-- Run it in SQL Server Management Studio, in the database of the data, after
-- replacing MyDatabase in the USE line and ref.MyLabelTable throughout. Steps
-- 1 and 2 can be run again: they create the table only if it does not exist
-- and add only rows that are not there. Step 3 replaces the view. Nothing
-- here changes ref.MyLabelTable.
-- To remove what it creates:
--   DROP VIEW ref.DataProperties;
--   DROP TABLE ref.DataPropertyTables;

USE [MyDatabase];
GO

-- 1. ref.DataPropertyTables: one row for each table or view that takes its
-- labels from ref.MyLabelTable, with the value of Dataset under which its rows
-- are filed there. A table appears at most once. Two tables that share a set
-- of rows have a row each, with the same LabelDataset.
--
-- LabelDataset should have the type and collation of ref.MyLabelTable.Dataset,
-- so that the join in the view can use the index on (Dataset, LabelType), and
-- so that comparing the two raises no collation conflict; varchar(128) is a
-- placeholder. This shows the type:
--   SELECT TYPE_NAME(user_type_id) AS type_name, max_length
--   FROM sys.columns
--   WHERE object_id = OBJECT_ID(N'ref.MyLabelTable') AND name = N'Dataset';

IF OBJECT_ID(N'ref.DataPropertyTables', N'U') IS NULL
BEGIN
    CREATE TABLE ref.DataPropertyTables (
        TableSchema  sysname      NOT NULL,
        TableName    sysname      NOT NULL,
        LabelDataset varchar(128) NOT NULL,
        CONSTRAINT PK_DataPropertyTables PRIMARY KEY (TableSchema, TableName)
    );
    CREATE INDEX IX_DataPropertyTables_LabelDataset
        ON ref.DataPropertyTables (LabelDataset);
END;
GO

-- 2. A first filling, from the catalogue: for each set of rows in
-- ref.MyLabelTable that has no row in ref.DataPropertyTables yet, and whose
-- Dataset is the name of a table or view of this database, the table or view
-- of that name in dbo if there is one, otherwise the one in the only schema
-- that has a table or view of that name. Names held by several schemas other
-- than dbo are left for a decision; check (b) in step 4 lists them. Rows
-- already in the table are kept, so this can be run again when sets are added
-- to ref.MyLabelTable.

INSERT INTO ref.DataPropertyTables (TableSchema, TableName, LabelDataset)
SELECT s.name, o.name, d.Dataset
FROM (SELECT DISTINCT Dataset FROM ref.MyLabelTable
      WHERE Dataset IS NOT NULL AND Dataset <> '') AS d
JOIN sys.objects AS o
    ON o.name = d.Dataset COLLATE DATABASE_DEFAULT
   AND o.type IN ('U', 'V') AND o.is_ms_shipped = 0
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
WHERE (s.name = N'dbo'
       OR NOT EXISTS (SELECT 1 FROM sys.objects AS o2
                      WHERE o2.name = o.name
                        AND o2.type IN ('U', 'V') AND o2.is_ms_shipped = 0
                        AND o2.object_id <> o.object_id))
  AND NOT EXISTS (SELECT 1 FROM ref.DataPropertyTables AS m
                  WHERE m.LabelDataset = d.Dataset)
  AND NOT EXISTS (SELECT 1 FROM ref.DataPropertyTables AS m
                  WHERE m.TableSchema = s.name AND m.TableName = o.name);
GO

-- Rows are added by hand for the cases the first filling leaves out, for
-- example a second table that shares the rows of an existing set:
--   INSERT INTO ref.DataPropertyTables (TableSchema, TableName, LabelDataset)
--   VALUES (N'MySchema', N'MyTable', 'MyTable');

-- 3. ref.DataProperties, the view that sqldta reads. It has two parts.
--
-- PART 1 gives the rows of each set to every table that ref.DataPropertyTables
-- lists for it.
--
-- PART 2 gives the rows of a set that ref.DataPropertyTables does not mention
-- to the table of the same name in dbo, so that a set added to
-- ref.MyLabelTable without a row in ref.DataPropertyTables keeps working for
-- a table in dbo. It is switched on
-- and off in one place, the line marked PART 2 SWITCH: 1 = 1 keeps it on, and
-- 1 = 0 turns it off, so that every set must then be listed. After changing
-- the switch, run this step again. To remove the part altogether, delete from
-- UNION ALL to the end of the view.
--
-- Each part selects by the table's schema and name in a way that the indexes
-- can serve: the primary key of ref.DataPropertyTables, then the index on
-- (Dataset, LabelType) of ref.MyLabelTable. sqldta compares TableName with an
-- N'...' literal, so under a SQL collation (a name that begins SQL_) PART 2
-- cannot use that index when Dataset is varchar, and reads the whole table;
-- SELECT DATABASEPROPERTYEX(DB_NAME(), 'Collation') shows the collation.
--
-- Rows already of the current types (ValueLabel and so on) pass through the
-- CASE unchanged, so ref.MyLabelTable may hold both kinds. CREATE OR ALTER
-- needs SQL Server 2016 SP1 or later.

CREATE OR ALTER VIEW ref.DataProperties
AS
-- PART 1: the sets listed in ref.DataPropertyTables, for each table listed
SELECT m.TableSchema,
       m.TableName,
       L.VarName AS ColumnName,
       CASE L.LabelType
           WHEN 'Opt'      THEN 'ValueLabel'
           WHEN 'Var'      THEN 'VariableLabel'
           WHEN 'Format'   THEN 'VariableFormat'
           WHEN 'NoteVar'  THEN 'VariableNote'
           WHEN 'NoteDta'  THEN 'DatasetNote'
           WHEN 'DtaLabel' THEN 'DatasetLabel'
           WHEN 'Link'     THEN 'Link'
           ELSE L.LabelType
       END AS PropertyType,
       L.DataCode AS PropertyCode,
       L.LabelName AS PropertyText
FROM ref.DataPropertyTables AS m
JOIN ref.MyLabelTable AS L ON L.Dataset = m.LabelDataset
UNION ALL
-- PART 2: the sets not listed in ref.DataPropertyTables, for the table of the
-- same name in dbo
SELECT N'dbo',
       L.Dataset,
       L.VarName,
       CASE L.LabelType
           WHEN 'Opt'      THEN 'ValueLabel'
           WHEN 'Var'      THEN 'VariableLabel'
           WHEN 'Format'   THEN 'VariableFormat'
           WHEN 'NoteVar'  THEN 'VariableNote'
           WHEN 'NoteDta'  THEN 'DatasetNote'
           WHEN 'DtaLabel' THEN 'DatasetLabel'
           WHEN 'Link'     THEN 'Link'
           ELSE L.LabelType
       END,
       L.DataCode,
       L.LabelName
FROM ref.MyLabelTable AS L
WHERE 1 = 1  -- PART 2 SWITCH: 1 = 1 on, 1 = 0 off
  AND NOT EXISTS (SELECT 1 FROM ref.DataPropertyTables AS m
                  WHERE m.LabelDataset = L.Dataset);
GO

-- 4. Checks, to be read before the view is relied on.

-- (a) Sets of rows whose Dataset is not the name of any table or view of this
-- database. PART 2 of the view, when it is on, files them under dbo, where
-- they apply to nothing until such a table is created.
SELECT L.Dataset, COUNT(*) AS label_rows
FROM ref.MyLabelTable AS L
WHERE NOT EXISTS (SELECT 1 FROM sys.objects AS o
                  WHERE o.name = L.Dataset COLLATE DATABASE_DEFAULT
                    AND o.type IN ('U', 'V') AND o.is_ms_shipped = 0)
GROUP BY L.Dataset
ORDER BY L.Dataset;

-- (b) Names that tables or views hold in more than one schema, with the set of
-- rows that each now takes from ref.DataPropertyTables (NULL if none) and
-- whether ref.MyLabelTable has a set of that name. Under the earlier layout
-- every one of them took the rows of the set of its name.
SELECT o.name AS TableName, s.name AS TableSchema, m.LabelDataset,
       CASE WHEN EXISTS (SELECT 1 FROM ref.MyLabelTable AS L
                         WHERE L.Dataset = o.name COLLATE DATABASE_DEFAULT)
            THEN 1 ELSE 0 END AS set_of_that_name
FROM sys.objects AS o
JOIN sys.schemas AS s ON s.schema_id = o.schema_id
LEFT JOIN ref.DataPropertyTables AS m
    ON m.TableSchema = s.name AND m.TableName = o.name
WHERE o.type IN ('U', 'V') AND o.is_ms_shipped = 0
  AND o.name IN (SELECT o2.name FROM sys.objects AS o2
                 WHERE o2.type IN ('U', 'V') AND o2.is_ms_shipped = 0
                 GROUP BY o2.name HAVING COUNT(*) > 1)
ORDER BY o.name, s.name;

-- (c) Rows of ref.DataPropertyTables whose table or view does not exist, for
-- example after it has been dropped or renamed.
SELECT m.TableSchema, m.TableName, m.LabelDataset
FROM ref.DataPropertyTables AS m
WHERE OBJECT_ID(QUOTENAME(m.TableSchema) + N'.' + QUOTENAME(m.TableName)) IS NULL
ORDER BY m.TableSchema, m.TableName;

-- (d) Rows of ref.DataPropertyTables whose set has no rows in ref.MyLabelTable.
SELECT m.TableSchema, m.TableName, m.LabelDataset
FROM ref.DataPropertyTables AS m
WHERE NOT EXISTS (SELECT 1 FROM ref.MyLabelTable AS L WHERE L.Dataset = m.LabelDataset)
ORDER BY m.TableSchema, m.TableName;

-- (e) The rows of the view for each table, by type, to compare with the rows
-- of ref.MyLabelTable for the same set.
SELECT TableSchema, TableName, PropertyType, COUNT(*) AS n
FROM ref.DataProperties
GROUP BY TableSchema, TableName, PropertyType
ORDER BY TableSchema, TableName, PropertyType;

-- 5. Permissions. Users who read ref.MyLabelTable through a grant on the schema
-- ref, or on the whole database, can read the view as well. Users granted
-- SELECT on ref.MyLabelTable alone also need SELECT on the view; when the view
-- and the two tables have the same owner, that is all they need:
--   GRANT SELECT ON ref.DataProperties TO MyRole;
