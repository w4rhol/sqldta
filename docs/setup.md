# Setting up sqldta

This guide is for whoever installs `sqldta` for a site, or for their own use: installation, the settings file, the connection to SQL Server, the label table, and the menu item for the dialog. The [README](../README.md) is for the people who use the command, and `help sqldta` is the full reference; this guide is not installed with the package.

## What a site needs

- Stata 16 or later. Stata 16 must be updated to 1 September 2020 or later (type `update all`), because earlier copies of Stata 16 had faults with temporary frames, which `sqldta` uses. The package is tested on Stata 18 and 19.
- Microsoft SQL Server, and an ODBC driver for SQL Server on each machine that runs Stata. The package's tests pass through ODBC Driver 18, ODBC Driver 13, SQL Server Native Client 11.0 and the "SQL Server" driver of Windows.
- Databases with a case-insensitive collation, which is the default when SQL Server is installed. `sqldta` matches column names without regard to case, so it does not support databases with a case-sensitive collation, in which two columns or tables can have names that differ only in case.
- Column names that are valid Stata names: letters, digits and underscores, not starting with a digit, at most 32 characters, and not a reserved word such as `in` or `long`. `sqldta` leaves out a column whose name is not valid, with a note; a view that renames such columns with `AS` can be loaded instead.
- Permission for each user's login to read the tables and views, and the label table if there is one. SQL Server's permissions decide what each user can load; `sqldta` has no list of users.
- Optionally, a label table in each database (see [The label table](#the-label-table)). Without one, `sqldta` loads the data without labels.

## Installing

From GitHub, in Stata:

```stata
net install sqldta, from("https://raw.githubusercontent.com/w4rhol/sqldta/main/src/")
```

This installs into the PLUS folder. For every user of a shared installation of Stata, install it into a folder that every user's ado-path includes: the SITE folder (`net set ado SITE` before `net install`), or a shared PLUS folder that a site's `profile.do` sets with `sysdir set PLUS`. Type `sysdir` to see the folders.

Where Stata cannot reach GitHub, copy the folder `src/` of the repository to a place that Stata can read, and install from it:

```stata
net install sqldta, from("C:/path/to/sqldta/src") replace
```

Where the network needs a proxy, set it first, for example in the site's start-up program (see [The menu item](#the-menu-item-and-the-dialog)):

```stata
set httpproxy on
set httpproxyhost "proxy.example.org"
set httpproxyport 8080
```

To update an installed copy:

```stata
adoupdate sqldta, update
```

`adoupdate` compares the Distribution-Date of the installed copy with that of the copy where it was installed from. A copy installed into SITE is updated with `adoupdate sqldta, update dir(SITE)`.

## The settings file

A site sets `sqldta`'s settings in a text file named `sqldta_site.cfg`, in a folder on the ado-path that every user reads, such as SITE or a shared PERSONAL folder. `sqldta` reads the first file of this name along the ado-path each time it runs, so:

- the settings stay in force after `macro drop _all`, which a user's do-file may run, and after `clear all`;
- a change to the file takes effect at the next command, without restarting Stata;
- the ado-path is searched in its order, `BASE`, `SITE`, the current directory, `PERSONAL`, `PLUS` and then `OLDPLACE` by default, so a file in SITE comes before a file in the current directory, and a file in a project's folder comes before one in PERSONAL.

### Making the settings file from the example

`net install` installs an example of the settings file, `sqldta_site_example.cfg`, with every setting and a comment on each. `sqldta` never reads a file of that name, so the example has no effect until it is copied or renamed to `sqldta_site.cfg`. To see where it was installed:

```stata
findfile sqldta_site_example.cfg
```

A site administrator copies it, as `sqldta_site.cfg`, to the SITE folder or to a shared PERSONAL folder, and edits the copy. For SITE:

```stata
findfile sqldta_site_example.cfg
copy "`r(fn)'" "`c(sysdir_site)'sqldta_site.cfg"
doedit "`c(sysdir_site)'sqldta_site.cfg"
```

For a shared PERSONAL folder, write its path, or `` `c(sysdir_personal)' `` in a session where PERSONAL is that folder, in place of `` `c(sysdir_site)' ``. Writing to SITE may need an administrator's rights.

A single user can instead copy or rename the example to `sqldta_site.cfg` in the folder where it was installed:

```stata
findfile sqldta_site_example.cfg
local cfg = subinstr(r(fn), "sqldta_site_example.cfg", "sqldta_site.cfg", 1)
copy "`r(fn)'" "`cfg'"
doedit "`cfg'"
```

That folder is in PLUS unless the package was installed elsewhere, and PLUS comes after SITE, the current directory and PERSONAL on the ado-path, so a copy there is read only when none of those holds a `sqldta_site.cfg`.

`adoupdate` replaces the example with that of the new version, or puts it back if it was renamed, and `ado uninstall sqldta` removes it. Neither changes `sqldta_site.cfg`, which is not one of the package's files, so a site's settings survive both; compare the example of a new version with the site's copy to see whether it has a setting the copy lacks. `sqldta settings` shows which file is read.

### What a settings file holds

Each line holds the name of a setting, in any case, then a space or a tab, then its value. Blank lines, and lines that begin with `*` or `//`, are passed over. A line with any other name is passed over with a note, so that a mistyped name is noticed. `SQLDTA_CONNECTION` may be given on several lines; for the other settings, a later line replaces an earlier one.

| Setting | Meaning | Default |
|---|---|---|
| `SQLDTA_SERVERS` | server names, separated by spaces; the first is the default of `server()` | none, so `server()` is required |
| `SQLDTA_CONNECTION` | a connection template; on several lines, templates tried in order (see [Connecting](#connecting)) | the ODBC data source named after the server |
| `SQLDTA_DATASCHEMA` | the schema of a table named in `dataset()` without one | `dbo` |
| `SQLDTA_LABELTABLE` | the label table, as `schema.table`, or `table`, which is then in `ref` | `ref.DataProperties` |
| `SQLDTA_DATABASES` | databases that the dialog lists for every server, separated by spaces | the databases on the server that the login can open |
| `SQLDTA_DEFAULTDB` | the database that the dialog selects first: words separated by spaces, each a database for every server, or `server=database` for one server | the first listed |
| `SQLDTA_DLGREMEMBER` | anything other than `0` makes the dialog reopen at the server, database and schema chosen last in the session | `0` |
| `SQLDTA_DTTEXT` | anything other than `0` loads date-time columns as text converted with `clock()`, an earlier and slower method that gives the same values; a fallback, should a problem appear with the present method | `0` |

Each setting may also be set as a global macro of the same name, which replaces the line of the file for the rest of the session or until `macro drop _all`; an option of `sqldta`, where there is one, replaces both. Personal settings are best kept that way, in a user's own `profile.do`, so that the site's file stays the same for everyone.

`sqldta settings` shows the file read, each setting and where it comes from, and tries each connection template on the first server; `sqldta settings, server(name)` tries them on another.

## Connecting

`sqldta` connects through `odbc load` with a connection template, an ODBC connection string in which it replaces `%server%` with the server name and `%database%` with the database name, for example:

```
Driver={ODBC Driver 18 for SQL Server};Server=%server%;Trusted_Connection=yes;TrustServerCertificate=yes;
```

`Trusted_Connection=yes` logs in as the user's Windows account. `sqldta` names every object in full, as `[database].[schema].[table]`, so the template needs no database; `Database=%database%;` makes object names that are not qualified, such as a subquery on another table in `sqlwhere()`, resolve in the database of the load rather than in the login's default database.

### Several templates, one for each driver

Machines at one site often have different drivers: a current driver on a managed server, older ones on laptops. The settings file may list one template for each, the preferred first:

```
SQLDTA_CONNECTION  Driver={ODBC Driver 18 for SQL Server};Server=%server%;Trusted_Connection=yes;TrustServerCertificate=yes;
SQLDTA_CONNECTION  Driver={ODBC Driver 17 for SQL Server};Server=%server%;Trusted_Connection=yes;
SQLDTA_CONNECTION  Driver={ODBC Driver 13 for SQL Server};Server=%server%;Trusted_Connection=yes;
SQLDTA_CONNECTION  Driver={SQL Server Native Client 11.0};Server=%server%;Trusted_Connection=yes;
SQLDTA_CONNECTION  Driver={SQL Server};Server=%server%;Trusted_Connection=yes;
```

The first time `sqldta` connects to a server in a Stata session, it tries the templates in order with `SELECT 1` and uses the first that connects for the rest of the session. If that is not the first template, it displays a note that names the driver, so that a machine that falls back on an older driver is noticed. It tries them again if the lines change, after `clear mata` or `clear all`, or if none connected. If none connects, a note says so and `sqldta` connects through the ODBC data source named after the server. A single template is used as it is, without an attempt, so a load through a template that cannot connect stops with the driver's message.

An attempt through a driver that is not installed fails at once, and a successful one takes a fraction of a second. An attempt to a server that does not answer waits for the driver's login time-out, 15 seconds by default, for each template tried; ODBC Driver 18.7 and later accept `ConnectTimeout=n;` to shorten it.

The word `dsn`, in place of a template, means the ODBC data source named after the server, which must then be set up on each machine in the ODBC Data Source Administrator. A user can type `global SQLDTA_CONNECTION dsn` to use it although the file lists templates.

### Drivers

| Driver | In a template | Notes |
|---|---|---|
| ODBC Driver 18 for SQL Server | `Driver={ODBC Driver 18 for SQL Server}` | Microsoft's current driver; encrypts by default and checks the server's certificate |
| ODBC Driver 17 for SQL Server | `Driver={ODBC Driver 17 for SQL Server}` | supported by Microsoft to January 2028; does not encrypt unless `Encrypt=yes` is given |
| ODBC Driver 13 for SQL Server | `Driver={ODBC Driver 13 for SQL Server}` | Microsoft's mainstream support ended in October 2022 |
| SQL Server Native Client 11.0 | `Driver={SQL Server Native Client 11.0}` | no longer updated or shipped with SQL Server |
| SQL Server | `Driver={SQL Server}` | ships with Windows and is deprecated; returns date columns as text, which `sqldta` converts |

`sqldta` sends the columns whose types drivers handle differently as expressions that every driver reads the same way, so the data loaded are the same through each of these drivers; the package's tests show this for every SQL Server data type. A driver released later works as soon as a template names it.

### Encryption

ODBC Driver 18 encrypts the connection and checks that the server's certificate is issued by an authority that the machine trusts. Many servers have a certificate that SQL Server made itself, and Driver 18 then refuses to connect unless the template has `TrustServerCertificate=yes`, which keeps the encryption but does not check the certificate. A certificate from an authority that the machines trust, installed on the server by its administrator, removes the need for it. Earlier drivers do not encrypt unless the template has `Encrypt=yes`, with `TrustServerCertificate=yes` for such a certificate.

### Checking the connection

```stata
sqldta settings
sqldta settings, server(MYSERVER2)
```

shows each template's return code and the seconds it took, and which one `sqldta` uses. A template with a password, `PWD=` or `Password=`, is shown with the password masked; Windows logins, through `Trusted_Connection=yes`, keep passwords out of the settings file altogether.

## The label table

The label table is optional. It holds the labels, formats and notes of the tables in its database, one row for each item, and may be a table or a view. Its default name is `ref.DataProperties`, which `SQLDTA_LABELTABLE` or the option `labeltable()` can change; it must be in the same database as the data.

| Column | Meaning |
|---|---|
| `TableSchema` | schema of the table or view the row applies to |
| `TableName` | name of that table or view |
| `ColumnName` | column name; empty for DatasetNote and DatasetLabel rows; for Link rows, the key column |
| `PropertyType` | `ValueLabel` (value label), `VariableLabel` (variable label), `VariableFormat` (display format), `VariableNote` (variable note), `DatasetNote` (dataset note), `DatasetLabel` (data label) or `Link` (linked table of a split table), in any case |
| `PropertyCode` | for ValueLabel rows, the integer code; for VariableNote and DatasetNote rows, optionally, the order in which the notes are applied |
| `PropertyText` | the label or note text; for VariableFormat rows, the format, such as `%9.2fc`; for DatasetLabel rows, the data label; for Link rows, the linked table as `table` (in the schema of the main table) or `schema.table` |

The rows of a table are those whose TableSchema and TableName are its schema and name, so tables of the same name in different schemas have rows of their own. Rows of the types `Format` and `DataLabel`, the names that `sqldta` 1.0.0 used, are read as `VariableFormat` and `DatasetLabel` rows, so a label table or view made for that version keeps working; new rows should use the new names. All the columns are of character types, so that other software can read the same table; `sqldta` checks that a ValueLabel row's PropertyCode is a whole number before it applies it. Other columns may be present and are not read. `help sqldta` sets out how each kind of row is applied and when a row is skipped.

For example:

```sql
CREATE TABLE ref.DataProperties (
    TableSchema  nvarchar(128) NOT NULL,
    TableName    nvarchar(128) NOT NULL,
    ColumnName   nvarchar(128) NULL,
    PropertyType nvarchar(20)  NOT NULL,
    PropertyCode nvarchar(50)  NULL,
    PropertyText nvarchar(max) NULL
);
CREATE INDEX IX_DataProperties_Table ON ref.DataProperties (TableSchema, TableName, PropertyType);
```

| TableSchema | TableName | ColumnName | PropertyType | PropertyCode | PropertyText |
|---|---|---|---|---|---|
| dbo | MyTable | sex | ValueLabel | 1 | Male |
| dbo | MyTable | sex | ValueLabel | 2 | Female |
| dbo | MyTable | sex | VariableLabel | | Sex of the patient |
| dbo | MyTable | amount | VariableFormat | | %9.2fc |
| dbo | MyTable | age | VariableNote | 1 | Age at admission |
| dbo | MyTable | | DatasetNote | | Extracted each month |
| dbo | MyTable | | DatasetLabel | | Hospital admissions |
| dbo | MyTable | id | Link | | MyTablePart2 |

The index is optional. `sqldta` selects label rows by TableSchema, TableName and PropertyType, for each load and for each table chosen in the dialog, so on a large label table the index saves reading the whole table each time. It needs those columns to be of a type with a length, such as `varchar(128)` or `nvarchar(128)`, not `varchar(max)` or `nvarchar(max)`. `sqldta` compares them with Unicode text, so in a database whose collation is a SQL collation, with a name that begins with `SQL_`, the index is used only if they are `nvarchar`; with a Windows collation, such as `Latin1_General_CI_AS`, `varchar` columns can use it too.

### Split tables

A table whose columns are split across several tables that share a key column can be loaded as one. The label table holds one Link row for each linked table, with the main table's schema and name in TableSchema and TableName, the key in ColumnName, and the linked table in PropertyText. `sqldta` then joins the linked tables to the main table on the server, with a left join. Only 1:1 links are supported: `sqldta` stops with error 459 if the key repeats in a linked table.

### A label table of another layout

A label table that other software reads, and that cannot be changed, can be given this layout by a view over it. For example, for a table `ref.MyLabels` with the columns `TableName`, `Field`, `Kind` and `Text`, which uses the codes `V` for variable labels and `N` for variable notes, and whose tables are all in `dbo`:

```sql
CREATE VIEW ref.DataProperties AS
SELECT N'dbo' AS TableSchema,
       TableName,
       Field AS ColumnName,
       CASE Kind WHEN 'V' THEN 'VariableLabel' WHEN 'N' THEN 'VariableNote' ELSE Kind END AS PropertyType,
       CAST(NULL AS nvarchar(50)) AS PropertyCode,
       Text AS PropertyText
FROM ref.MyLabels;
```

A label table that lacks any of the six columns is not read: `sqldta` displays a note that names them and loads the data without labels.

## The menu item and the dialog

`db sqldta` opens the dialog. A site can add it to Stata's User menu when Stata starts, from `profile.do` or `sysprofile.do`, which Stata runs at start-up (see "Executing commands every time Stata is started" in Stata's Getting Started manual); Stata runs `sysprofile.do` first, then `profile.do`. [examples/site_setup_example.ado](../examples/site_setup_example.ado) is a start-up program that adds the item and, if the network needs one, sets the proxy:

```stata
window menu append item "stUser" "Access server data" "db sqldta"
window menu refresh
```

Menu items last until Stata exits. `window menu clear` removes every item that any program has added, so a start-up program is better without it.

The dialog lists the servers in `SQLDTA_SERVERS`, the databases in `SQLDTA_DATABASES` or on the server, and selects the database in `SQLDTA_DEFAULTDB` first; `SQLDTA_DLGREMEMBER` makes it reopen at the server, database and schema chosen last.

## When something goes wrong

| Message | Cause and remedy |
|---|---|
| `server() is required because no server is set` | `SQLDTA_SERVERS` is not set in the settings file or as a global; check with `sqldta settings` that the file is found |
| `Data source name not found and no default driver specified` | the template names a driver that is not installed, or no template is set and there is no ODBC data source named after the server |
| a message about the certificate chain or SSL | ODBC Driver 18 does not trust the server's certificate; add `TrustServerCertificate=yes;` to the template, or have a trusted certificate installed on the server |
| `note: connected to ... via fallback driver ...` | the earlier templates did not connect, usually because the machine lacks their drivers; `sqldta settings` shows the result of each; install the preferred driver, or accept the fallback |
| `label table ... not found or not readable, so no labels applied` | the label table does not exist in that database, has another name or schema, or the login cannot read it |
| `label table ... lacks columns of its layout` | the label table is not of the layout above; a view can give it that layout |
| `columns left out because their names are not valid Stata names` | rename those columns in a view, with `AS` |
| `variable x was long now double` | `odbc load` read an `int` column that holds a value above 2,147,483,620, the largest `long`, such as 2,147,483,647; the values are exact |
