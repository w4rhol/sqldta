# Developing sqldta

This guide is for whoever changes the package: the layout of the repository, how to work on a clone, the tests and their fixtures, and how a release is made. [CLAUDE.md](../CLAUDE.md) records the design decisions and the reasons for them, and the rules for code and documentation; [HANDOVER.md](../HANDOVER.md) records the development process, what testing has found, the history of the test logs and the work still open.

The record of development before the first release is in a private repository, which HANDOVER.md calls the archive; CLAUDE.md explains how this repository refers to it.

## The repository

| Path | Holds |
|---|---|
| `src/` | the package, the files that `net install` installs: `sqldta.ado`; `_sqldta_odbc.ado`, the one program that runs `odbc load` for a query; `_sqldta_settings.ado`, which reads the settings file and chooses the connection; `sqldta.dlg`, the dialog, and `sqldta_dlg.ado`, its helper; `sqldta.sthlp`; `sqldta_site_example.cfg`, the example of the settings file, which `sqldta` never reads under that name; `sqldta.pkg` and `stata.toc` |
| `tests/` | `test_sqldta.do`, the tests; `create_fixtures.sql`, which creates every object they read |
| `examples/` | a start-up program for a site, which adds the dialog to the User menu |
| `docs/` | this guide and the setup guide |
| `images/` | the hex sticker, with a template and guidelines for stickers of other Stata packages |
| `dev.do` | switches a Stata session to the clone's copy of `sqldta`, and back |

## Trying a branch while a release is installed

Stata runs the first `sqldta.ado` it finds along the ado-path, and keeps a program it has loaded until `discard` or the end of the session. The ado-path belongs to one session. So a branch can be tried in one Stata window while another uses the installed release, and nothing is installed over anything:

- A branch is never installed. It runs from the clone's `src/`, put first on the ado-path for one session.
- The release is installed in one place, where the site keeps it, and changes only when a new release is installed there.

From the root of a clone, in Stata:

```stata
cd "C:/path/to/sqldta"
do dev
```

puts the clone's `src/` first on the ado-path for this session, runs `discard`, shows which copy of `sqldta` is in use with the branch and commit, and adds an item that opens the clone's dialog to the User menu. In that session, `sqldta`, `help sqldta` and `db sqldta` are the branch's. `do dev release` takes the clone's `src/` off the ado-path again, so that the session uses the installed release; closing the window does the same. Running `do dev` again after a pull reloads the clone's programs and dialog.

If neither a global nor a settings file sets `SQLDTA_SERVERS` or `SQLDTA_CONNECTION`, `do dev` sets them from `tests/test_config_local.do`. A `sqldta_site.cfg` at the root of the clone is read, because the current directory is on the ado-path, and `.gitignore` keeps it out of commits. Both copies of `sqldta` read the same settings file, so a setting that a branch adds goes into a site's file only after the release that reads it.

Before a release, `net install` can be tried from the clone into a temporary folder, never into PLUS or SITE:

```stata
local d "`c(tmpdir)'/sqldta_try"
capture mkdir "`d'"
net set ado "`d'"
net install sqldta, from("C:/path/to/sqldta/src") replace
ado describe sqldta, from("`d'")
ado uninstall sqldta, from("`d'")
net set ado PLUS
```

## The tests

`tests/test_sqldta.do` tests `sqldta` against a SQL Server. The tests read only objects that `tests/create_fixtures.sql` creates in a database of their own, `_sqldtaTesting`, which holds nothing else. They need:

- a server with the database `_sqldtaTesting`, created once, by hand, with the server's default collation, which must be case-insensitive:

  ```sql
  CREATE DATABASE [_sqldtaTesting];
  ```

- `tests/create_fixtures.sql`, opened in SQL Server Management Studio (SSMS) and executed, and again whenever it changes. It drops every object it creates, then creates them: the fixture label table and the view `ref.DataProperties` of it; a generated table of 1,000 rows, `sqldta_test.sqldta_test_known`; a generated table of 20,000 admissions, `sqldta_test.sqldta_test_adm`; and small tables written out in full, including tables with a column of each SQL Server data type. It stops before doing anything if the current database is not `_sqldtaTesting`;
- an ODBC data source named after the server, for the tests of the data source;
- `tests/test_config_local.do`, which `.gitignore` keeps out of commits, setting `TEST_SERVER`, and if they apply `TEST_SERVER2`, a second server for the tests of two servers, which are skipped when it is empty, `TEST_CONNECTION`, the connection template, and `TEST_FIXDATABASE`, the database, if it is not `_sqldtaTesting`. Every other setting of the tests is fixed in the test file.

The generated tables take their values from a function of a seed, the row number and the column number that uses whole-number arithmetic only, so that they are the same on any SQL Server; the comment at the top of `tests/create_fixtures.sql` gives the formula. The fixtures have a version, which the script writes in `sqldta_test.sqldta_test_version` and the test file expects; a change to the fixtures raises it in both.

From the root of the clone, in a new Stata window:

```stata
do tests/test_sqldta.do
```

Before test 1 it stops, with a message, if any file of `src/sqldta.pkg` is not found in the clone's `src/`, so that it cannot test an installed copy, or if the fixtures are not of the version it expects. The log is written to `tests/test_sqldta.log`, which `.gitignore` keeps out of commits because it holds the server's name. Its header shows Stata's version, the template, the branch and the commit, and it ends with `SQLDTA TESTS: n passed, m failed` and the names of the tests that failed. Each test runs under `capture noisily`, so one failure does not stop the others; the output of a failing test is just above its `FAIL` line.

- The tests load through the template in `TEST_CONNECTION` and through the data source, and compare the two. To test another ODBC driver, set `TEST_CONNECTION` to a template that names it and run the tests again; rename the log first, because each run replaces it.
- The tests put an empty settings file of their own first on the ado-path, so that a site's `sqldta_site.cfg` does not change them, and restore the site's `SQLDTA_` globals at the end.
- Tests 212 to 221 check the README's examples of `sqlwhere()` and the `if` qualifier on the generated table of admissions, for January 2023: the rows each example loads must be the rows that its Stata equivalent keeps after a full load of the month.
- Before the tests of the settings file, a type report, which is not counted, shows the server's version and collation and how each column of the data-type tables arrives in Stata, through the template and through the data source.
- When the tests finish, the data-type tables and the known table are left loaded in frames, for comparison with SSMS in the Data Editor.

The dialog cannot be tested by a do-file. The helper's `sqldta_dlg query` subcommands, which return in `r()` what the dialog shows, are tested; the dialog itself is tried by hand.

## Releases

A release is a tag on `main`, such as `v1.0.0`. In the same commit, the `*! version` lines of the files that changed and the `Distribution-Date` of `src/sqldta.pkg` are brought up to date, so that `adoupdate` sees the new release; other pull requests leave the Distribution-Date alone. The README's install line installs from `main`, so `main` holds only code with a passing test log.
