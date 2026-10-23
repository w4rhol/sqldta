# Handover

This file carries context from one working session to the next: how the work is done, what has been learnt and on what evidence, what is still open, and the history of the test logs. CLAUDE.md holds the settled design and the rules; this file holds the rest. Read both at the start of a session. Keep this file current: update it in the same commit as any change it describes, and before a session ends.

The repository is public, so this file follows hard constraints 3 and 6 of CLAUDE.md: no real server names, database names other than `_sqldtaTesting`, usernames, email addresses, file-share paths or proxy details, and nothing about a site's tables. Test logs contain the server's name; never copy from a log into this file.

## 1. State

- sqldta 1.0.0, the first public release, was published on 22 Oct 2026 as the release v1.0.0, whose tag is on e9e6046, the first commit of this repository. The code of `src/` is that of archive 37e355f, whose test log showed 212 passed and 0 failed (Stata 19 SE, ODBC Driver 18), with only comments, version lines, the help file's text and the package description changed since (section 5).
- The tests read only the fixtures that `tests/create_fixtures.sql` creates in `_sqldtaTesting` (CLAUDE.md, hard constraint 6). Their log at e9e6046, from a fresh clone of this repository on 22 Oct 2026 (Stata 19 SE, ODBC Driver 18), shows 220 passed and 0 failed, as did the log at ab7e6c9 on the archive's branch (section 5).
- Earlier logs, in the archive, covered Stata 18 SE, and ODBC Driver 13 and SQL Server Native Client 11.0 as the template (section 8).
- Not tried: Stata 16 and 17, which the maintainer does not have; ODBC Driver 17; installing from GitHub with `net install`, and `adoupdate` (section 5, step 13). The dialog is tried by hand only.
- sqldta 1.1.0, on the branch `claude/eloquent-cannon-xfrjit`, renames the PropertyTypes Format and DataLabel to VariableFormat and DatasetLabel, and reads the old names as well; fixtures version 2. Its log at cc123bb, whose code is that of 27884a5, showed 220 passed and 0 failed, through ODBC Driver 13 as the template; the shorter note of a fallback driver, written after it, is untested (section 9).

## 2. The archive

Development up to the first release, from 17 to 21 Oct 2026, is in the private repository `w4rhol/sqldta-dev`, which the maintainer archived on 22 Oct 2026, after the release, so that it is read-only; the maintainer can unarchive it. Archived, it can still be read: a session attached it with read access and cloned it on 22 Oct 2026. CLAUDE.md, under The archive, says how to cite it and how a session can read it. Pull request numbers start again at #1 in this repository, so the archive's are written "archive pull request #12".

What it holds:

- `main`, 118 commits, ending at 06c4b92, the merge of its pull request #12; every commit cited as evidence in CLAUDE.md and here is in it.
- Pull requests #1 to #12 and their descriptions.
- Its HANDOVER.md: the discoveries and their evidence (section 3 there), the plans and decisions with their dates, among them the benchmark against the predecessor and the profile of sqldta's load (4.9, 4.12, 4.15), the two passes over the dialog (4.4, 4.13), the layout of the label table (4.14) and the settings file (4.16), the open questions (5), and every test log from 17 to 21 Oct 2026 (7).
- What this repository leaves out: the predecessor's code (`legacy/`), the benchmark against it, and files specific to the site where sqldta was first written.
- The branch `claude/optimistic-edison-kgstwr`, which holds the work of section 5 and ends at 2f7d4be, whose tree, 531b338, is that of this repository's first commit, e9e6046.

Its history also holds details of that site and two commits authored under the maintainer's personal address, which is why it stays private.

The state when it ended: the last full log, 212 passed and 0 failed, at archive 37e355f (Stata 19 SE, ODBC Driver 18); archive 133834e on Stata 18 SE, 211 passed and 0 failed; archive 2880551 through ODBC Driver 13 and through SQL Server Native Client 11.0, 211 passed and 0 failed each; the README's examples, 10 passed and 0 failed, at archive 7bb8ce9.

**Record of the end of the archive.** Archive pull request #12 was merged by the maintainer on 21 Oct 2026 at 22:15 AEDT with a merge commit, 06c4b92, whose parents are 3abd168 and 386f8f1, so all 12 of its commits, 37e355f among them, are in the archive's `main`; its head branch was deleted. The archive's branch `claude/laughing-lamport-bh1yt3` held one commit not in `main`, 6446af4, pushed eight minutes after archive pull request #11 was merged and so never part of it; pull request #12 overtook what it recorded, except the question of columns whose names are not valid Stata names, which is carried to section 6. The branch was deleted before the copy (section 5, step 6).

## 3. How the work is done

### Roles

The maintainer runs Stata and SQL Server Management Studio (SSMS). Claude writes the code and the documentation in a cloud session that has neither Stata nor access to the maintainer's server. The only evidence of how the code behaves is a test log that the maintainer runs and uploads. Code without a passing log is untested, and summaries say so.
### The loop

1. Claude commits and pushes to the session branch, says exactly what changed, and says what to run.
2. The maintainer brings the clone up to date with RStudio's Git pane on a machine that has git: choose the session branch in the branch list, then click Pull.
3. If `tests/create_fixtures.sql` changed, the maintainer opens it in SSMS and executes it. It works only in `_sqldtaTesting`, drops every object it creates first, and ends by listing the rows of each fixture table: 1,156 in the fixture label table and in `ref.DataProperties`, 1,000 in `sqldta_test_known` and 20,000 in `sqldta_test_adm`.
4. On the machine with Stata, which has no git, from the root of the clone, in a new Stata window: `do tests/test_sqldta.do`. The installed release is not touched (CLAUDE.md, Working method; docs/development.md). For interactive work, `do dev` switches a session to the clone's `src/`, and `do dev release` switches it back.
5. The maintainer uploads `tests/test_sqldta.log`. Claude checks that its `branch:` and `commit:` lines, near the top, match the pushed head, then reads the result, fixes what failed, says exactly what changed, and waits for the next log.

Reading a log:

- Logs are in Windows-1252, not UTF-8, so file-reading tools may refuse them or show replacement characters; `grep -a` reads them.
- `grep -a -n -E "^FAIL|SQLDTA TESTS|^Failed|^branch:|^commit:" <log>` gives the summary. The output of a failing test is just above its FAIL line.
- Before test 1, the log names the files of the package found in the clone's `src/` and the version of the fixtures; if either check fails, the run stops there with a message. When the version cannot be read, the driver's message is shown above it (since the change after the log at 5e732d3, section 9).
- The type report starts at the lines that begin `TYPE REPORT`.

### Branches, pull requests and releases

- Each session works on its own branch from `main` and opens a pull request into `main`, which is merged with a merge commit, only after a passing log on its head. With a merge commit the branch's commits stay in `main`'s history, so the commits cited as evidence can be found in any clone.
- Work after a merge belongs in a new session, which starts a new branch.
- Releases are tags on `main` (v1.0.0 and so on). The `*! version` lines and the Distribution-Date of `sqldta.pkg` are brought up to date in the release commit, so that `adoupdate` sees the change; other pull requests leave the Distribution-Date alone.
- Pull request descriptions give test results as counts and the commit, never names from a log.

### Commit identities

Sessions commit as `Claude <noreply@anthropic.com>`; the maintainer commits as `Warren Holroyd <4807208+w4rhol@users.noreply.github.com>` (CLAUDE.md, hard constraint 5). Two commits in the archive, made from RStudio's Git pane on 20 Oct 2026, carried the maintainer's personal address, because RStudio's Git pane runs git, which takes the author from its configuration (the clone's `.git/config`, then the user's `.gitconfig`, then the system's), and the machine's configuration held that address; GitHub's web pages used the noreply address, because the account keeps its address private there. The remedy, given to the maintainer on 21 Oct 2026, is the noreply address in each clone (`git config user.email ...`) and on the machine (`git config --global user.email ...`), checked with `git var GIT_AUTHOR_IDENT`, and GitHub's settings "Keep my email addresses private" and "Block command line pushes that expose my email" (section 5, step 1).

On 21 Oct 2026 the maintainer asked whether session commits could be made under the maintainer's noreply address. They can: a start-up hook in `.claude/settings.json` would set git's identity in each session's clone and turn off signing, since GitHub marks a commit "Unverified" when it is signed by a key that is not on the account of its committer's address. The maintainer chose to keep the Claude identity for sessions, so that the history shows which commits a session made, and those commits stay signed (CLAUDE.md, hard constraint 5). The maintainer set the noreply address in the machine's git configuration the same day, and confirmed it in each clone, with GitHub's two settings, before the copy (section 5, step 1).

### Rules for writing

- Australian English, in plain factual prose, with no em dashes and no rhetorical flourishes. This applies to documentation, comments, commit messages and pull request descriptions.
- Commit messages are one line in the present tense.
- Placeholders: MYSERVER, MyDatabase, MyTable, user.one, C:/path/to/sqldta and proxy.example.org.
- Give the maintainer instructions in terms of RStudio's Git pane and GitHub's web pages wherever they can do the job, and exact commands for RStudio's Terminal where a git command is needed; the maintainer prefers not to use the git command line.
- The help file changes in the same commit as any change to options or behaviour, and CLAUDE.md in the same commit as any change to a design decision.
- Before writing a large new part, present the plan and the tests and wait for the maintainer's approval.

### The cloud environment

- There is no Stata, and none will be added.
- `curl` through the session's proxy reaches www.stata.com, so Stata's manuals and its help files (`https://www.stata.com/help.cgi?<topic>`) are fetched with it into the scratchpad; the WebFetch tool does not resolve that host. The maintainer can also paste the output of `help` or `viewsource` from Stata.
- GitHub is reached through the GitHub tools of the session, not through `gh`.

## 4. Discoveries

Each item gives its evidence. "Log" means a test log run by the maintainer; a commit cited with the word archive is in the archive.

### 4.1 Stata

1. `syntax [if]` checks the variables of the expression against the data in memory, which for sqldta are columns on the server, so it stops with "variable not found" (log of archive 2636cee: "num not found"). sqldta splits the `if` expression from the options with a Mata function before `syntax` runs.
2. Mata functions defined in an ado-file are private to it. `mata which` does not see them (log of archive a97cbc8); the ado-file's own programs can call them; `clear mata` does not remove them (log of archive dfbc490). sqldta checks for them by calling a no-op function, `_sqldta_present()`.
3. The `notes` command turns a standalone `TS` into a time stamp and fails on a note that contains a lone backquote (first log, 17 Oct 2026). sqldta writes the characteristics `[note0]`, `[note1]` and so on directly, through Mata `st_global()`.
4. A local macro loses its leading spaces when it is defined. `local from ... AS m`joins'` produced `AS mLEFT JOIN` (log of archive 2636cee).
5. `local ++x` fails when `x` is not defined (first log).
6. `local x "a" "b"` strips the outer quotes; a list of quoted strings needs compound quotes.
7. Locals defined inside a `frame name { }` block are still defined after it; sqldta relies on this throughout.
8. Limits, from Stata's help: data labels and variable labels 80 characters; a value label 32,000 bytes; one note 67,784 bytes; 9,999 notes on `_dta` or on one variable; 100 frames; 135,600 bytes in a program; 264,392 characters in a macro in Stata/BE and 15,480,200 in Stata/MP.
9. In `frame name: command`, macros in the command, extended macro functions included, are expanded in the current frame before the prefix switches to `name` (log of archive fc0440b). `frame name: local t : type v` works, because there the extended macro function is part of the `local` command that runs in `name`. In a `frame name { }` block, each line is expanded inside the frame.
10. Dialogs, from the dialog programming manual, the source of `dynamic_list_control.class` (version 1.0.2, in Stata 19's `ado/base/d`) and StataCorp's posts on Statalist (Linhart, 25 Mar 2003; Hassell, 14 Nov 2006; Crow, 15 Mar 2007):
    - COMBOBOX and LISTBOX have no documented member that replaces their items. A dialog's LIST is a class array that belongs to the dialog object, `.dlgname_dlg.listname`; before the controls exist, in PREINIT, a helper can fill it with `.Arrdropall` and `.Arrpush "item"`, and the controls are then created from it.
    - After the controls exist, `dynamic_list_control` keeps the control and its LIST in step through the undocumented control members `clearlist` and `additem`.
    - `.setList` splits `newlist()` with `foreach ... of local`, so an item with spaces must be in double quotes, and passes each item through macro expansion. It ends with `.setvalue` of the items of `value()`, which is empty when `value()` is not given; `setvalue ""` on a LISTBOX stops with error 111 (trace at archive c244cb4), so `setList` always fails on a LISTBOX after it has added the items.
    - From an ado-file, `.dlgname_dlg.tab.control.member` calls a control's member, for example `setlabel` with the text in compound quotes; the current value of a control is `.dlgname_dlg.tab.control.value`, which must not be changed directly.
    - `stata hidden` runs a command at once during initialisation only with `SYNCHRONOUS_ONLY`; `stata hidden queue` runs it when Stata is idle. In a SCRIPT, `control.withvalue other.member "@"` calls a member of another control with the first control's value in place of `@`.
    - A LISTBOX's default selection is its `default()` item, or the first item; within a session a dialog remembers the item chosen in a list box, unless `nomemory` is given, so a list box with items always has one selected. In a PROGRAM, `control.iseq("text")` and `control.isdefault()` test a control's value; Stata 16's manual lists both. A LISTBOX's `ondblclick()` selects the item before its action runs.
    - A text in the .dlg file that begins with literal, char, global or class, or with c(, r(, e( or s(, is read as the source of a value, in `tooltip()` too (CLAUDE.md, Dialog).
11. Value-label codes (logs of archive 717d9c3 and 0898c5a): `label define` accepts -2,147,483,647 and 2,147,483,620, the ends of the range of a long, and refuses 2,147,483,647 with r(198) and 99,999,999,999. Mata's `st_vlmodify()` took 2,147,483,647 without an error, but the label was not found under that code afterwards. sqldta sets with `st_vlmodify()` only codes from `c(minlong)` to `c(maxlong)` and leaves others to `label define`.
12. `dir "folder/s"` lists the entry of the folder `s` itself, and not the files in it; `dir "folder/s/*"` lists them.
13. `net install` with an `F` line puts the file in the letter subfolder of its first letter, and a name that begins with an underscore goes to `_`; `findfile` searches the letter subfolders of each folder on the ado-path; `ado update` leaves a renamed copy of an installed file alone and puts the original back; `ado uninstall` removes the package's files, says nothing about one that is missing, and leaves a renamed copy (local runs at archive 37e355f).
14. Release history, checked on 21 Oct 2026 from the help files whatsnew16, whatsnew16to17, whatsnew17to18 and whatsnew18to19 at www.stata.com: nothing that `src/` uses (237 function names, 210 command words, the frame commands, `odbc load` and its options, and the dialog's controls and options) is listed as new in Stata 17, 18 or 19 or in any update to Stata 16; the newest are the frame commands and `st_framecurrent()`, of Stata 16.0. Stata 17 lists no change to frames; Stata 18 added alias variables and sets of frames saved in one file, and Stata 19 `frames modify`; sqldta uses none. Updates to Stata 16 fixed faults that touch sqldta: on 02 Jul 2019, `odbc load` failing with r(682) when the ODBC driver was set to Unicode; on 30 Sep 2019, temporary frames staying in memory, and variables lost when an ado-file ended in another frame; on 01 Sep 2020, variables lost when a current frame with a temporary name was dropped as a program ended; on 17 Sep 2020, `odbc load` storing NaN. Hence the floor of an updated Stata 16 (CLAUDE.md, hard constraint 2). Release notes do not list every change in behaviour, and no test has run on Stata 16 or 17.

### 4.2 odbc load and the drivers

Found by the type report of 18 Oct 2026 (archive 945af0d and f5e50c4), through the connection template with ODBC Driver 18 and through a DSN on the legacy "SQL Server" driver alike unless stated. This is what `odbc load` does on its own; sqldta sends most of these types as expressions (CLAUDE.md, Data types), so later type reports show what sqldta delivers instead:

| SQL type | Arrives in Stata as |
|---|---|
| bit | byte |
| tinyint | int |
| smallint | long |
| int | long; `odbc load` promotes it to double, with a message, when a value exceeds Stata's long range |
| bigint | a string, through both drivers |
| decimal, numeric, money, smallmoney, float, real | double. Values beyond 2^53 lose precision: numeric(18,0) 123456789012345678 became 123456789012345680. The format is %10.0g, so decimal(9,2) 9999999.99 shows as 10000000 |
| date | double with %td through Driver 18; a string through the legacy driver, which sqldta converts |
| datetime, smalldatetime | double with %tc through both, but `odbc load` drops fractions of a second: 13:45:30.123 arrived as 13:45:30.000 |
| datetime2 | double with %tc through Driver 18, fractions dropped and 0001-01-01 missing; str27 `yyyy-mm-dd hh:mm:ss.fffffff` through the legacy driver |
| time | skipped by `odbc load`, with a note, through Driver 18; str16 through the legacy driver |
| datetimeoffset | skipped, with a note, through Driver 18; str34 `yyyy-mm-dd hh:mm:ss.fffffff +hh:mm` through the legacy driver |
| uniqueidentifier, sql_variant | skipped through both |
| xml | skipped through Driver 18; text through the legacy driver |
| hierarchyid, geography, geometry | skipped through Driver 18; raw bytes through the legacy driver |
| binary, varbinary, image, rowversion | strL of raw bytes through both |
| char, nchar | strings with their trailing spaces |
| varchar | a string; a character outside ASCII (an e with an acute accent, in a Latin1 code page) arrives as a single byte that is not valid UTF-8 |
| nvarchar, nchar | correct UTF-8, including macrons and CJK characters |
| varchar(max), nvarchar(max), text, ntext | strL, in full (10,000 characters tested) |

Other findings:

- `odbc load` notes a skipped column as "x is of a type not supported in Stata; skipped". sqldta does not see the skip, so label rows for such a column are passed over without being counted as skipped.
- In a whole-table load through Driver 18, the date-time columns that came after a skipped `time` column got %10.0g instead of %tc, although each got %tc when loaded alone; `odbc load` seems to misplace formats after a skipped column.
- `odbc load`'s `bigintasdouble` option stops with an error if a value is too large to be held exactly; sqldta converts `bigint` itself instead.
- Driver 18 encrypts by default and rejects a server certificate that the client does not trust unless the template has `TrustServerCertificate=yes`; Driver 13, Native Client 11.0 and the legacy "SQL Server" driver connect without it (the maintainer's tests, 17 Oct 2026). Driver 17 has not been tried.
- With Driver 18, a column loaded through `sqlselect()` keeps the case of the name as typed (log of 17 Oct 2026).
- The legacy driver rounds decimal and numeric values of precision over 15 to about 15 significant digits: decimal(16,2) 99999999999999.99 arrived as 100000000000000, where Driver 18 gave 99999999999999.984375, the nearest double (log of archive fc0440b). sqldta sends the wider ones as text.
- varchar(max) and nvarchar(max) values arrive as strL through the legacy driver, and through Driver 18 as str# when short and strL when long; the values are the same.
- Stata accepts `tc()` with a time of day alone: `display %tcHH:MM:SS.sss tc(13:45:30.123)` shows 13:45:30.123 (log of archive fc0440b).
- An attempt through a driver that is not installed fails at once, a successful one takes about 0.1 s, and one to an address that does not answer waits for the login time-out, 15 s by default (logs and runs of 21 Oct 2026). ODBC Driver 18.7 and later accept `ConnectTimeout=n;`.

### 4.3 SQL Server

- `[database].sys.all_columns`, joined to `OBJECT_ID()` of each table, lists the columns of tables, views and system views such as INFORMATION_SCHEMA.TABLES. `TYPE_NAME(system_type_id)` gives the base type.
- `datetime` and `smalldatetime` read text of the form `yyyy-mm-dd hh:mm:ss` according to the login's language and DATEFORMAT, which under British English reads the day first. The form with a `T`, `yyyy-mm-ddThh:mm:ss`, and `'YYYYMMDD'` are read the same way everywhere. `date`, `datetime2` and `datetimeoffset` read `yyyy-mm-dd` the same way everywhere.
- SSMS may assume a file's encoding wrongly, so `tests/create_fixtures.sql` is kept in ASCII and writes other characters with `NCHAR()` and `CHAR()`.
- SQL Server compiles a batch as a whole. A statement that names a column that an existing table does not have fails when the batch is compiled, before any statement of the batch runs, so a DROP earlier in the same batch does not help; a table that does not exist yet is resolved when the statement runs. So a script that recreates its objects drops them in a batch of their own first (CLAUDE.md, Coding conventions).
- `ORDER BY` of text follows the database's collation, under which a full stop and an underscore may sort either way round; Link rows are followed in the order of their PropertyText, so the fixtures keep two linked tables in `ref`, whose name sorts before `sqldta_` under any collation (section 5).
- Trailing spaces: `char(n)` and `nchar(n)` are padded with spaces to `n`, and ODBC returns the padding. Comparisons with `=` ignore trailing spaces, and `LEN()` counts characters without them, whereas `DATALENGTH()` counts bytes with them. With the default ANSI_PADDING ON, a `varchar` value keeps any trailing spaces it was stored with.
- sqldta is specific to SQL Server (`TOP`, `NEWID()`, brackets, `N'...'`, `OBJECT_ID()`, collations), and its column query reads `sys.all_columns`; SQL Server's documentation advises against INFORMATION_SCHEMA for finding the schema of an object.
- Whether names compare with regard to case depends on the database collation; under a case-sensitive collation a table can have both `var1` and `Var1`. Stata names are case-sensitive.
- A table with a clustered columnstore index reads only the columns that a query names, and a whole-row read of such a table can be slow on the server itself, more so when it has a single row group, which one thread reads; loading fewer columns with `sqlselect()` is expected to help there. Not measured by a log (archive HANDOVER.md, section 3.3).

## 5. The move to the public repository

Decided by the maintainer on 21 Oct 2026, and planned and approved the same day: sqldta is published from a new public repository, `w4rhol/sqldta`, whose first commit holds the release tree prepared on the branch `claude/optimistic-edison-kgstwr`; the private repository is renamed `w4rhol/sqldta-dev` and archived.

### Decisions

- The public repository's first commit is authored and committed by the maintainer's noreply address, with neither of the two Claude lines in its message, and unsigned.
- Before the copy, the release tree is tested from a branch of the private repository (step 4), and the new repository is created private and made public only after its check (steps 8 to 12).
- Left out of the public tree: `legacy/`, the predecessor's code; the benchmark against the predecessor; and files specific to the site where sqldta was first written; kept: `examples/site_setup_example.ado`, which worked when the maintainer tried it by hand on 21 Oct 2026, and `images/`.
- The tests and the benchmark have a database of their own, `_sqldtaTesting` (CLAUDE.md, hard constraint 6), with the fixtures in the schemas `sqldta_test` and `sqldta_alt`, and in `dbo` and `ref` for the defaults; the benchmark, after the release, in `sqldta_bench`. Size is not a concern.
- "ICD-10-AM" stays in the README. The copyright is the maintainer's, under MIT. The floor stays at Stata 16, updated to 1 Sep 2020 or later (section 4.1, item 14).

### What was built, on the branch `claude/optimistic-edison-kgstwr`

- An orphan branch made from the archive's `main` at 06c4b92, so that it shares no history.
- `tests/create_fixtures.sql`, replacing the earlier fixture script, as approved: everything in `_sqldtaTesting`, with a check that stops it in any other database; the generated known table `sqldta_test_known` (1,000 rows, 11 columns, `Category` with value labels and `Score` with notes) and table of admissions `sqldta_test_adm` (20,000 rows); the view `ref.DataProperties` of the fixture label table; `sqldta_test_otherlayout` for test 202; `dbo.sqldta_test_dflt` for test 158; and `sqldta_test_version`, version 1. Two changes from the approved design:
  - The generator squares its value between two of Park and Miller's steps. With the multiplier alone, which is linear, each column would be a shifted copy of the others, so that, for example, the category of `diag2` would follow from that of `diag1`.
  - `sqldta_test_part` and `sqldta_test_samex` stay in `ref`, because Link rows are followed in the order of their PropertyText under the database's collation (section 4.3), and `ref.` sorts before `sqldta_` under any collation, where `sqldta_test.` against `sqldta_test_` would not.
- A reproduction of the generator in Python, run on 21 Oct 2026 before the push, gave for January 2023 554 admissions, of which each README example selects some: 31 with LIKE 'I21%', 30 with the `if` qualifier's `substr()`, 17 with `= 'I21.4'`, 77 in C00 to C97, 102 with E10 to E14 in any column, 168 with a stay over 30 days, 30 admitted on 15 Jan 2023, 10 aged 65 or more with J10 to J18, and 99 by the subquery; with 36 codes in lower case or with a trailing space, and near misses (C98 and C99, J19, E15 to E19). In the known table, every code of `Category` occurs, and `Total` stays below 2^53.
- `tests/test_sqldta.do`: the settings fixed but four (section 3, The loop); the two checks before test 1; the generated known table for tests 1 to 35; the fixture schema in `TEST_FIXSCHEMA`; tests 158, 160, 162, 163, 164, 197, 201 and 202 changed; tests 203 and 210 removed; the README's examples as tests 212 to 221, with a sample of 10 rather than 100, so that it samples; `clear mata` moved to 222. 220 tests in all.
- `dev.do`: `do dev release`, and a line that says which copy is in use.
- `src/`: version 1.0.0 in every `*! version` line, Distribution-Date 20261021; commit citations marked archive; one comment made general; the help file's Requirements with the floor, its paragraph on the site's view replaced by a pointer to the setup guide, and two mentions of unreleased versions reworded; the same rewording in the example settings file; the Requires line of `sqldta.pkg`.
- README, `docs/setup.md` and `docs/development.md` updated; CLAUDE.md and this file rewritten.

### The log at ab7e6c9

The maintainer created `_sqldtaTesting`, ran `tests/create_fixtures.sql` in SSMS, trimmed `tests/test_config_local.do` to `TEST_SERVER` and `TEST_SERVER2`, and ran the tests on 21 Oct 2026 (Stata 19 SE, through the default template, ODBC Driver 18). The log's branch and commit lines read `claude/optimistic-edison-kgstwr` and ab7e6c9, the pushed head. It shows:

- 220 passed and 0 failed; both checks before test 1 passed (every file of the package found in the clone's `src/`; fixtures version 1).
- The README's examples, tests 212 to 221, selected exactly the rows that the Python reproduction of the generator gave: 554 admissions in January 2023, and 31, 30, 17, 77, 102, 168, 30 and 10 rows for the eight examples compared with their Stata equivalents. So the generator in SQL and its reproduction agree.
- Tests 162 and 163 found the schemas `dbo`, `ref`, `sqldta_alt` and `sqldta_test`, and the linked tables in `ref`; tests 160 and 197 showed only the number of databases on each server.
- The log shows nothing from outside `_sqldtaTesting` beyond what CLAUDE.md, hard constraint 6, allows: the second server's name does not appear, and the first appears where the tests name the server. The clone's folder appears, in the output of `which` and of the first check before test 1, as in every earlier log, which is one more reason that logs stay out of the repository and off GitHub.
- Two notes from Mata, that `txt` and `vals` may be used before they are set, come from the test file's helper `t_labeldump()`, unchanged from the archive, and are harmless.

### The copy, and the log at e9e6046

- Step 9 was not needed. After the rename, the session that had prepared the branch could reach the new, empty `w4rhol/sqldta`, because a session's access to a repository goes by its name, and it did step 10.
- Step 10, on 22 Oct 2026: the tree of 2f7d4be was extracted with `git archive` into a new, empty repository, where `git write-tree` gave 531b3386244edd55ad95582a273b561708bed418, the tree the maintainer approved. One commit, e9e6046, with no parent, unsigned, with the maintainer's noreply address as author and committer and the message "sqldta 1.0.0", was pushed to `main` alone.
- Step 11: GitHub showed one branch, `main`, at e9e6046, credited to the maintainer's account. A fresh clone held one commit, of tree 531b338, and no email address but the two of CLAUDE.md, hard constraint 5. The maintainer cloned the repository afresh, copied `tests/test_config_local.do` into it, and ran the tests on 22 Oct 2026 (Stata 19 SE, ODBC Driver 18). The log's branch and commit lines read `main` and e9e6046; both checks before test 1 passed; 220 passed and 0 failed.
- Step 12: the repository was made public, with a ruleset on `main`, a description and topics.
- Step 13, in part: `stata.toc`, `sqldta.pkg` and the seven files that it lists, downloaded from the install URL by the session without signing in, were each the same, byte for byte, as in tree 531b338; and the maintainer installed the package from a clone with `net install`, and it worked. Installing from GitHub in Stata, and `adoupdate`, are still to be tried (section 6).
- Step 14: the release v1.0.0, "sqldta 1.0.0", was published on 22 Oct 2026, with its tag on e9e6046, as the latest release.
- Step 15: `w4rhol/sqldta-dev` was archived on 22 Oct 2026, and this record was made in the first pull request of this repository.

### The steps

| # | Step | Who | State |
|---|---|---|---|
| 0 | Merge archive pull request #12 | maintainer | done (section 2) |
| 1 | Commit identity: the noreply address in each clone and on the machine; GitHub's two email settings | maintainer | done |
| 2 | Create `_sqldtaTesting` | maintainer | done, 21 Oct 2026 |
| 3 | Design of the fixtures and tests, approved on 21 Oct 2026; the release tree on the branch | Claude | done |
| 4 | Test and review round: run `tests/create_fixtures.sql` and the tests; try `examples/site_setup_example.ado` by hand; review the help file; read CLAUDE.md and this file in full; search for terms only the maintainer knows | maintainer, with Claude's fixes | done, 21 Oct 2026: the log passed at ab7e6c9 (220 passed, 0 failed); the example worked; the help file, CLAUDE.md and this file read, and wording in them, the development guide and the comments of the test files changed at the maintainer's request; the maintainer's search found no term |
| 5 | Final commit on the branch, with the logs; the maintainer approves its tree hash; the fixtures of the earlier design removed from the databases where they were | Claude; maintainer | done: tree 531b338, at 2f7d4be, approved; fixtures removed, 21 Oct 2026 |
| 6 | Delete the archive's branch `claude/laughing-lamport-bh1yt3` | maintainer | done |
| 7 | Rename the repository to `sqldta-dev`; change the remote of every clone at once (`git remote set-url origin https://github.com/w4rhol/sqldta-dev.git`) | maintainer | done |
| 8 | Create `w4rhol/sqldta`, private and empty | maintainer | done |
| 9 | A new session on `w4rhol/sqldta-dev`, which attaches `w4rhol/sqldta` with push access | maintainer | not needed (above) |
| 10 | Copy: the approved tree alone, in a new empty repository, one commit, pushed to `main` | Claude | done, 22 Oct 2026: e9e6046 |
| 11 | Check, fresh clone and test run, while private | Claude; maintainer | done, 22 Oct 2026: 220 passed, 0 failed at e9e6046 |
| 12 | Make public; a ruleset that blocks deletion and force pushes on `main` | maintainer | done, 22 Oct 2026 |
| 13 | `net install` from GitHub into a temporary folder | maintainer | in part: the files that GitHub serves checked; installed from a clone; from GitHub, and `adoupdate`, to try |
| 14 | Release v1.0.0 on GitHub, which makes the tag; the site's copy updated | maintainer; Claude drafts the notes | the release published, 22 Oct 2026; the site's copy to be updated from GitHub |
| 15 | Record in this repository; archive `sqldta-dev` | Claude; maintainer | archived, 22 Oct 2026; this record in the first pull request |
| 16 | The benchmark on generated tables, as the first pull request | Claude; maintainer | to do |

The fixtures of the earlier design were dropped from the databases that held them by the maintainer on 21 Oct 2026 (the databases are not named here).

## 6. Open questions and work after the release

- Installing from GitHub with `net install`, and updating with `adoupdate`, have not yet been tried in Stata (section 5, step 13). When they have, record the result here and in section 5.
- The site's view over its label table of another layout still gives the PropertyTypes Format and DataLabel. Its updated definition, which gives VariableFormat and DatasetLabel, is to be run at the site once every copy of sqldta that reads the view is at 1.1.0 or later, since 1.0.0 does not read the new names (section 9).
- The benchmark on generated tables, in `sqldta_bench` of `_sqldtaTesting`: tables of many rows, many columns, character columns, date-time columns, bigint and wide decimal columns, many value-label rows, and a columnstore copy, made by `tests/create_bench_tables.sql` with the generator of the fixtures at a scale set at its top; and `tests/benchmark.do`, which compares the clone's `src/` with the latest release, installed from its tag into a temporary folder, and with `odbc load` alone, in one Stata session, switching by the ado-path and `discard`. Its results can be recorded here and in pull requests, because they are on generated data.
- Whether sqldta should offer to load columns whose names are not valid Stata names under names made valid, such as with `strtoname()`, with the original names in variable labels; the design leaves them out (CLAUDE.md, Column selection). The maintainer is willing to come back to it as an improvement after the first release (archive 6446af4, 21 Oct 2026).
- Databases with a case-sensitive collation: not supported (CLAUDE.md, Collation); the maintainer may look at them again after the first release.
- ODBC Driver 17 has not been tried; Stata 16 and 17 cannot be tested.
- Since 23 Oct 2026 the maintainer's Stata cannot find ODBC Driver 18, does not connect through Driver 17 either, and connects through Driver 13 (section 9). When Driver 18 is available again, run the tests through it, so that 1.1.0 has a log through Driver 18 as well.
- Whether to add a Char type for other characteristics, with the name in PropertyCode and the value in PropertyText.
- Whether `_sqldta_odbc` should also put `clear` and the connection before `exec()`; sqldta's own clearing of the target frame already avoids the error (test 168), so this is not needed for correctness.
- Whether the description in the dialog is fast enough on tables with many label rows; it could make fewer connections, for example by not running sqldta itself.
- An optional GitHub Actions check on pull requests that fails when a commit's author or committer address is not one of the allowed noreply addresses, or when a file contains a term from a list kept as a repository secret, printing only file names and line numbers.

## 7. Tests

`tests/test_sqldta.do` has 220 tests, each under `capture noisily`, and ends with `SQLDTA TESTS: <n> passed, <m> failed`. Every object it reads is made by `tests/create_fixtures.sql` in `_sqldtaTesting`. Test numbers match those of the archive's logs; 203 and 210 are not used.

| Tests | Cover |
|---|---|
| 1 to 35 | on the generated known table: loading into a new or the current frame, refusal without `clear`, `clear`, a table that does not exist, each label option through the default label table `ref.DataProperties`, no labels, a missing label table, the settings, `sqlselect()` with `lowercase` and in mixed case, `sqlwhere()`, `sqlrand()`, the default and required server, the connection template and `dsn()`, abbreviations, dates through both drivers, no leftover frames, the returned results, exact text from the fixture label table (31 to 34), `%database%` |
| 36 to 48 | Link-row joins with `sqlselect()`, `sqlrand()` and labels, a repeated key, `sqlselect()` wildcards, commas, unknown names, case and reserved words, skipped-row counting, VariableFormat and DatasetLabel rows, notes in PropertyCode order |
| 49 to 80 | the `if` qualifier, each expression compared with a full load followed by `keep if`; an unsupported expression; `if` with `sqlwhere()` |
| 81 to 100 | the data-type tables: the `if` qualifier on each supported type, `bigint` conversion, refusal of the types still unsupported, labels on several types, among them a format and a data label from rows under the old names Format and DataLabel (100) |
| 101 to 112 | how sqldta loads each type, and the same values through the template and the DSN |
| 113 to 152 | the `if` qualifier on date-time and time columns, each compared with `keep if`; refusals of comparisons of days with milliseconds |
| 153 to 159 | `labels()`; the options of the earlier syntax and names that are not `table` or `schema.table` refused; the default schemas `dbo` and `ref`, with real objects; a view loads |
| 160 to 167 | the query subcommands of `sqldta_dlg`: databases (checked, not shown) and from `SQLDTA_DATABASES`, schemas, tables and views, the description of a split table and of a view, a missing label table, and queries that fail |
| 168 | `clear` into a frame that holds data, for the wide fixture table and the types table |
| 169 to 179 | bit, and the `if` qualifier on it |
| 180 to 190 | text columns as they are and with `unicode()`; date-times as numbers against the text method, and `SQLDTA_DTTEXT`; the label step on `sqldta_test_lbl` |
| 191 to 199 | the dialog helper: `r(default)` from `SQLDTA_DEFAULTDB`, the text of each column, the time of a description (shown, not checked), two servers when `TEST_SERVER2` is set (checked, not shown), Find, a table with no valid column name |
| 200 | the strings of `src/sqldta.dlg` |
| 201 | tables of the same name in `sqldta_test` and `sqldta_alt`, each with its own rows and linked table, and a linked table in `ref` |
| 202 | a label table without the columns of the layout, `sqldta_test_otherlayout` |
| 204 to 209, 211 | the settings file, precedence of option, global and file, `macro drop _all`, connection templates tried in order, the helper's choice of template, the example settings file, and the example where `net install` puts it |
| 212 to 221 | the README's examples of `sqlwhere()` and the `if` qualifier on `sqldta_test_adm`, for January 2023, each compared with its Stata equivalent; a subquery and a sample of 10 |
| 222 | `clear mata`; it stays last, because it clears the test file's own Mata functions |

Before test 204, the type report shows the server's version, compatibility level and collation and how each column of the data-type tables arrives, and the clear report shows `odbc load` with `clear` after a long query; neither is counted. After test 222, the data-type tables and the known table are loaded into frames and left there for inspection.

## 8. History of test logs

| Date | Commit | Result | What it showed |
|---|---|---|---|
| 17 to 21 Oct 2026 | archive, 35 logs | to 212 passed, 0 failed | archive HANDOVER.md, section 7; the last at archive 37e355f |
| 21 Oct 2026 | ab7e6c9 (branch `claude/optimistic-edison-kgstwr`), Stata 19 SE, template through ODBC Driver 18 | 220 passed, 0 failed | the first run against `_sqldtaTesting`: both checks before test 1; the generated known table in tests 1 to 35; the README's examples (212 to 221) with the row counts that the Python reproduction of the generator gave (section 5) |
| 22 Oct 2026 | e9e6046 (`main`; the first commit of this repository, and the release v1.0.0), Stata 19 SE, template through ODBC Driver 18, from a fresh clone | 220 passed, 0 failed | the release's own commit, from a fresh clone: both checks before test 1 passed (section 5) |
| 23 Oct 2026 | 5e732d3 (branch `claude/eloquent-cannon-xfrjit`, pull request #2), Stata 19 SE, template through ODBC Driver 18 | stopped before test 1 | the files of the package were found; the version of the fixtures could not be read, r(682), the driver's message hidden by `capture` (section 9) |
| 23 Oct 2026 | 27884a5 (branch `claude/eloquent-cannon-xfrjit`, pull request #2), Stata 19 SE, template through ODBC Driver 18 | stopped before test 1 | the driver's message: the ODBC Driver Manager found no driver of the template's name (SQLSTATE IM002); the maintainer's Stata could not use ODBC Driver 18 that day (section 9) |
| 23 Oct 2026 | cc123bb (branch `claude/eloquent-cannon-xfrjit`, pull request #2; sqldta 1.1.0; the code of 27884a5, section 9), Stata 19 SE, template through ODBC Driver 13 | 220 passed, 0 failed | fixtures version 2; the renamed types and the old names Format and DataLabel (tests 47, 100, 111, 153, 154, 159, 164, 165, 201) (section 9) |

## 9. Version 1.1.0: VariableFormat and DatasetLabel

### Decisions

On 22 Oct 2026 the maintainer asked for two PropertyTypes of the label table to be renamed, Format to VariableFormat and DataLabel to DatasetLabel, so that the types about a variable begin with Variable and those about the dataset with Dataset. The plan was approved the same day, with its three recommendations:

1. sqldta reads the old names as well, as the new ones, so that label tables and views made for 1.0.0 keep working. Without this, the label query, which selects only the requested types, would no longer fetch rows under the old names, and their formats and data labels would be lost without a message.
2. The words of `labels()` stay as they are: `formats` and `datalabel`, so that scripts, `r(labels)`, `r(n_formats)` and the dialog do not change. The dialog's box already reads "Dataset label".
3. The change is released as 1.1.0 from this branch, because `net install` installs from `main`: the `*! version` lines of the files that changed, the Distribution-Date of `sqldta.pkg` and the README's status line are brought up to date here, and the maintainer publishes the release v1.1.0 after the merge.

### What changed

- `src/sqldta.ado`: `_sqldta_labeltypes` gives VariableFormat and DatasetLabel in `r(types)`; the label query adds `PropertyType = N'Format'` when VariableFormat is requested and `PropertyType = N'DataLabel'` when DatasetLabel is; `_sqldta_lblprep` reads `format` as `variableformat` and `datalabel` as `datasetlabel`; `_sqldta_apply` compares with the new names.
- `src/sqldta_dlg.ado`: the description's sentence for a table with no DatasetLabel or DatasetNote row; a comment.
- `src/sqldta.dlg`: the tooltips of the boxes for formats and the data label. Both still begin with `labels(`, which test 200 checks.
- `src/sqldta.sthlp`: the new names throughout, and one sentence on the old names under The label table.
- `tests/create_fixtures.sql`: the new names in every row but two, the Format row of `xdate` and the DataLabel row of `sqldta_test_types`, which keep the old names so that test 100, which asserts both, covers them; test 111 covers VariableFormat on the same table, and tests 47, 153, 154, 159, 164, 165 and 201 cover the new names elsewhere. No row was added or removed, so the counts that the script lists and that the tests expect are unchanged. Fixtures version 2, with `TEST_FIXVERSION` in `tests/test_sqldta.do`.
- `tests/test_sqldta.do`: the fixture version and comments; no assertion changed.
- `docs/setup.md`: the layout, the example rows, and one sentence on the old names. The README does not name the types; its status line gives 1.1.0.
- `CLAUDE.md`: the `labels()` paragraph, Labels, Data types, End of run, Dialog, the Metadata contract and Status.

### The site's view

The site where sqldta was first written reads its label table of another layout through a view of the package's layout, which gives Format and DataLabel. Its definition is in the archive, `examples/data_properties_view.sql` (agreed 21 Oct 2026, archive HANDOVER.md, section 4.14), and was left out of this repository because it names that site's label table and its columns (CLAUDE.md, hard constraint 3). In this session the archive was attached with read access and cloned, the file was found, and a copy that gives VariableFormat and DatasetLabel, with nothing else changed but its comments, was given to the maintainer to keep and run at the site. It is not in this repository, and the archive, which is read-only, was not changed.

Order at the site: sqldta 1.1.0 reads both names, but 1.0.0 reads only the old ones. So the site's copy of sqldta, and any copy that users installed themselves, is updated to 1.1.0 first, and the view is changed after; changed before, it would leave copies at 1.0.0 without formats and data labels, without a message.

### The logs

- 5e732d3, 23 Oct 2026: the branch and commit lines matched the pushed head. The run stopped at the second check before test 1: `odbc load` of the version of the fixtures failed with r(682), and the log opened and closed in the same second. The maintainer reported that `tests/create_fixtures.sql` had run in SSMS with the expected counts (1,156 rows in the fixture label table and in `ref.DataProperties`, 1,000, 20,000, 8, 6, 12 and 2). The code of the check is the same as at e9e6046, whose log passed it. Had the script not run at all, the check would have found version 1; r(682) at once means that the table did not exist when the query ran, as while the script is still running, between its drops and the end of its second batch, or that the connection was refused. The check ran `odbc load` under `capture`, which hid the driver's message, so the log cannot tell which. The next commit runs it under `capture noisily` and names both causes in its message; nothing else changed.
- 27884a5, 23 Oct 2026: the branch and commit lines matched the pushed head. The check showed the driver's message: "[Microsoft][ODBC Driver Manager] Data source name not found and no default driver specified", SQLSTATE IM002, which the Driver Manager gives when no driver of the name in the template is registered, before any connection to the server. So the first log failed the same way, and neither log ran any code of 1.1.0. The same day, the maintainer's installed sqldta, through the dialog in a new session, gave the note that it connected through template 3 of the 5 of the example settings file, ODBC Driver 13, because templates 1 and 2, ODBC Driver 18 and 17, did not connect. `_sqldta_settings.ado` and `_sqldta_odbc.ado` are the same as in 1.0.0, and the note is the warning of a fallback driver that the maintainer asked for on 21 Oct 2026, so the package behaved as designed. Driver 18 worked through the same template on 22 Oct 2026 (the log at e9e6046), so something on the machine that runs Stata changed between the two days. Until Driver 18 is back, the tests run through Driver 13, set as `TEST_CONNECTION` in `tests/test_config_local.do`; the whole suite passed through Driver 13 before, with the same results as through Driver 18 (archive logs of 2880551).
- cc123bb, 23 Oct 2026, through ODBC Driver 13 as the template: the branch and commit lines matched the pushed head; fixtures version 2; 220 passed and 0 failed. Among them: test 47, the DatasetLabel and VariableFormat rows of `sqldta_test_main`; test 100, the format of `xdate` and the data label of `sqldta_test_types` from rows under the old names Format and DataLabel; test 111, the VariableFormat row of `xdatetime`, with the counts expected; tests 153 and 154, each word of `labels()`; test 159, the view; tests 164 and 165, the dialog helper's descriptions; test 201, tables of the same name in two schemas. The notes of fallback templates in the log come from test 207, which puts a template that fails first on purpose. cc123bb changed only CLAUDE.md and HANDOVER.md, so the code it tested, `src/` and `tests/`, is that of 27884a5. At the maintainer's request, the branch was rewritten from 27884a5 on the same day, to reword commit messages and records: cc123bb and the commits after it were replaced by one commit, and are no longer in the branch's history; 5e732d3 and 27884a5 are unchanged.

### After the log at cc123bb

On 23 Oct 2026 the maintainer asked for a plainer note when sqldta connects through a template other than the first. The note of `_sqldta_cfg_note` in `_sqldta_settings.ado` (version 1.1.0) now reads, on two lines, `note: connected to <server> via fallback driver <driver>;` and `see sqldta settings`; a template that names no driver is named by its number, and the word `dsn` as the ODBC data source named after the server. The driver's name comes from a new function, `_sqldta_cfg_driver`, which `_sqldta_cfg_what` now uses too, so that `sqldta settings` shows the same as before. The note when no template connects is unchanged. No test checks the wording of either note; the setup guide's table of messages gives the new one. The maintainer chose not to run the tests again for this change, so it is untested.

### Steps

| # | Step | Who | State |
|---|---|---|---|
| 1 | The change, in one commit, pushed to `claude/eloquent-cannon-xfrjit` | Claude | done: 5e732d3 |
| 2 | Pull; run `tests/create_fixtures.sql` in SSMS (fixtures version 2); run `tests/test_sqldta.do`; upload the log | maintainer | fixtures run, 23 Oct 2026; the logs at 5e732d3 and 27884a5 stopped before test 1, because the maintainer's Stata could not find ODBC Driver 18 (above); the log at cc123bb, through Driver 13, passed: 220 passed, 0 failed |
| 3 | Fix what fails, until a log passes on the head | Claude; maintainer | done: nothing of 1.1.0 failed |
| 4 | Pull request #2 into `main`, merged with a merge commit | Claude; maintainer | opened 23 Oct 2026; to be merged |
| 5 | Release v1.1.0 on GitHub, with its tag on the merge commit; the site's copy updated | maintainer; Claude drafts the notes | to do |
| 6 | The site's view replaced by the updated definition, after step 5 | maintainer | to do |
