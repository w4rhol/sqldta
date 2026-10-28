* test_sqldta.do: tests for sqldta (Stata 16 or later)
*
* Run from the repository root in a new Stata session:
*     do tests/test_sqldta.do
* The log is written to tests/test_sqldta.log, which git ignores.
*
* The tests read only objects that tests/create_fixtures.sql creates in the
* test database, _sqldtaTesting, which holds nothing else (CLAUDE.md, Hard
* constraints). They need:
*   - a SQL Server with the database _sqldtaTesting, of a case-insensitive
*     collation, in which tests/create_fixtures.sql has been run since it last
*     changed; the tests stop before test 1 with a message if it has not;
*   - an ODBC data source (DSN) named after the server, for the tests of the
*     dsn() path;
*   - tests/test_config_local.do, which git ignores and which this file runs
*     if it exists, to set the four globals that are not fixed here:
*         global TEST_SERVER      "MYSERVER"
*         global TEST_SERVER2     "MYSERVER2"
*         global TEST_CONNECTION  "Driver={ODBC Driver 18 for SQL Server};Server=%server%;Trusted_Connection=yes;TrustServerCertificate=yes;"
*         global TEST_FIXDATABASE "_sqldtaTesting"
*     TEST_SERVER2 is a second server that the connection template reaches,
*     for the tests of two servers in $SQLDTA_SERVERS, which are skipped,
*     with a note, when it is empty; they read only master.sys.servers there
*     and check its list of databases without showing it. TEST_CONNECTION
*     and TEST_FIXDATABASE are needed only if they differ from the values
*     below.
*
* Every other TEST_ global is fixed below, because the fixtures are fixed. If
* tests/test_config_local.do sets any of them, or a global whose name begins
* EX_, the log notes it, and it is not used.
*
* Before test 1 the file checks that every file of src/sqldta.pkg is found in
* this clone's src/, so that it cannot test an installed copy of sqldta, and
* that the fixtures are of the version that this file expects.
*
* When the tests finish, the fixture tables of data types and the known table
* are left loaded in frames, for inspection in the Data Editor and comparison
* with SSMS: sqldta_test_types (the current frame), sqldta_test_rare,
* sqldta_test_dt and known.

version 16
clear all
set more off

capture confirm file "tests/test_sqldta.do"
if _rc {
	display as error "run this file from the repository root"
	exit 601
}

capture log close sqldtatest
log using "tests/test_sqldta.log", replace text name(sqldtatest)
display as text "Stata " c(stata_version) " " cond(c(MP), "MP", cond(c(SE), "SE", "BE")) ///
	", born " c(born_date) ", " c(os) " " c(osdtl)

* ---------------------------------------------------------------------------
* Settings
* ---------------------------------------------------------------------------

global TEST_SRC         "src"
global TEST_SERVER      "MYSERVER"
global TEST_SERVER2     ""
global TEST_FIXDATABASE "_sqldtaTesting"
global TEST_CONNECTION  "Driver={ODBC Driver 18 for SQL Server};Server=%server%;Trusted_Connection=yes;TrustServerCertificate=yes;"

* The globals fixed by the fixtures, emptied before tests/test_config_local.do
* runs, so that any it still sets can be noted
local t_fixed TEST_DATABASE TEST_SCHEMA TEST_TABLE TEST_N TEST_K TEST_VALVAR TEST_NOTEVAR ///
	TEST_LABELSCHEMA TEST_LABELTABLE TEST_FIXTABLE TEST_FIXSCHEMA
foreach g of local t_fixed {
	global `g'
}

capture confirm file "tests/test_config_local.do"
if _rc == 0 run "tests/test_config_local.do"
else display as text "note: tests/test_config_local.do not found; using placeholder values"

local t_unused
foreach g of local t_fixed {
	if `"${`g'}"' != "" local t_unused `t_unused' `g'
}
local t_ex : all globals "EX_*"
local t_unused `t_unused' `t_ex'
if "`t_unused'" != "" {
	display as text "note: tests/test_config_local.do sets globals that the tests no longer use:"
	display as text "  `t_unused'"
}

* The fixtures, all in $TEST_FIXDATABASE. The known table is the generated
* table sqldta_test_known, of $TEST_N rows and $TEST_K columns, whose column
* $TEST_VALVAR has value labels and a variable label and $TEST_NOTEVAR has
* variable notes. The fixture label table, sqldta_test_labels, is in the
* fixture schema, $TEST_FIXSCHEMA; the label table $TEST_LABELSCHEMA.$TEST_LABELTABLE
* is sqldta's default, ref.DataProperties, a view of it, so that both give
* the same rows.
global TEST_DATABASE    "$TEST_FIXDATABASE"
global TEST_FIXSCHEMA   "sqldta_test"
global TEST_SCHEMA      "sqldta_test"
global TEST_TABLE       "sqldta_test_known"
global TEST_N           1000
global TEST_K           11
global TEST_VALVAR      "Category"
global TEST_NOTEVAR     "Score"
global TEST_LABELSCHEMA "ref"
global TEST_LABELTABLE  "DataProperties"
global TEST_FIXTABLE    "sqldta_test_labels"
* The version of the fixtures that this file expects, which
* tests/create_fixtures.sql writes in sqldta_test_version
global TEST_FIXVERSION  4

display as text "test database: $TEST_FIXDATABASE"
* The driver of each log: the template names it, and the DSN's driver is the
* one set for the DSN named after the server in the ODBC Data Source
* Administrator
display as text `"connection template: $TEST_CONNECTION"'

local srcdir "`c(pwd)'/$TEST_SRC"
adopath ++ "`srcdir'"
which sqldta
which sqldta_dlg
which _sqldta_odbc
which _sqldta_settings

* A settings file of the tests' own, in a folder put first on the ado-path,
* so that a site's sqldta_site.cfg does not change the tests. t_reset empties
* it, and the tests of the settings file write their lines into it.
global T_CFGDIR "`c(tmpdir)'/sqldta_test_settings"
capture mkdir "$T_CFGDIR"
global T_CFGFILE "$T_CFGDIR/sqldta_site.cfg"
tempname cfgfh
file open `cfgfh' using "$T_CFGFILE", write text replace
file write `cfgfh' "* sqldta tests: no settings" _n
file close `cfgfh'
adopath ++ "$T_CFGDIR"

* Save the site's own SQLDTA globals; each test starts from a fixed baseline
local sqldta_globals SERVERS DATABASES DATASCHEMA LABELTABLE LABELFALLBACK CONNECTION DTTEXT DEFAULTDB DLGREMEMBER
foreach g of local sqldta_globals {
	global T_SAVED_`g' `"${SQLDTA_`g'}"'
}

global T_PASS 0
global T_FAIL 0
global T_FAILED

local src    server("$TEST_SERVER") database("$TEST_DATABASE") dataset("$TEST_SCHEMA.$TEST_TABLE")
local lbl    labeltable("$TEST_LABELSCHEMA.$TEST_LABELTABLE")
local fix    labeltable("$TEST_FIXSCHEMA.$TEST_FIXTABLE")
local alllab labels(all)
local nolab  labels(none)
local table  $TEST_DATABASE.$TEST_SCHEMA.$TEST_TABLE
* The fixture data tables, in the fixture schema fs, with the fixture label
* table
local fs     $TEST_FIXSCHEMA
local fsrc   server("$TEST_SERVER") database("$TEST_FIXDATABASE") `fix'
* The known table, for the rows of the fixture label table about its columns
local fknown server("$TEST_SERVER") database("$TEST_FIXDATABASE") dataset("$TEST_FIXSCHEMA.sqldta_test_known")
local fmain  `fsrc' dataset(`fs'.sqldta_test_main)
* The test database without a label table, for tests that name another
local fdb    server("$TEST_SERVER") database("$TEST_FIXDATABASE")

* ---------------------------------------------------------------------------
* Helpers
* ---------------------------------------------------------------------------

program define t_reset
	* One empty default frame, no SQLDTA globals except the connection
	* template, an empty settings file, and no connection kept by
	* _sqldta_settings
	frames reset
	foreach g in SERVERS DATABASES DATASCHEMA LABELTABLE LABELFALLBACK DTTEXT DEFAULTDB DLGREMEMBER {
		global SQLDTA_`g'
	}
	global SQLDTA_CONNECTION `"$TEST_CONNECTION"'
	t_cfgempty
	capture mata: mata drop _sqldta_conn
end

program define t_cfgempty
	* Empties the tests' settings file, $T_CFGFILE, or the file named, which
	* the test of macro drop _all names because the global is gone then
	args fn
	if `"`fn'"' == "" local fn `"$T_CFGFILE"'
	tempname fh
	file open `fh' using `"`fn'"', write text replace
	file write `fh' "* sqldta tests: no settings" _n
	file close `fh'
end

program define t_afterdrop, rclass
	* Runs macro drop _all, as a user's script may, then the command given.
	* It runs in a program of its own because macro drop _all also removes
	* the local macros of the context it runs in, and the command is kept in
	* Mata meanwhile. The caller saves and restores the globals.
	mata: t_cmd = st_local("0")
	macro drop _all
	mata: st_local("cmd", t_cmd)
	`cmd'
	return add
end

program define t_gitcommit
	* Displays the branch and commit checked out in the current directory, read
	* from .git because Stata cannot run git; the same code is in dev.do
	tempname fh
	capture file open `fh' using ".git/HEAD", read text
	if _rc {
		display as text "branch and commit unknown: .git/HEAD not found"
		exit
	}
	file read `fh' head
	file close `fh'
	local head = ustrtrim(`"`head'"')

	local branch (detached)
	local commit `head'
	if substr(`"`head'"', 1, 5) == "ref: " {
		local ref = substr(`"`head'"', 6, .)
		local branch = subinstr(`"`ref'"', "refs/heads/", "", 1)
		local commit unknown
		capture file open `fh' using ".git/`ref'", read text
		if _rc == 0 {
			file read `fh' commit
			file close `fh'
		}
		else {
			* Refs that git has packed are listed in .git/packed-refs
			capture file open `fh' using ".git/packed-refs", read text
			if _rc == 0 {
				file read `fh' line
				while r(eof) == 0 {
					if word(`"`line'"', 2) == `"`ref'"' local commit = word(`"`line'"', 1)
					file read `fh' line
				}
				file close `fh'
			}
		}
	}
	display as text "branch: `branch'"
	display as text "commit: " substr(ustrtrim(`"`commit'"'), 1, 7)
end

program define t_result
	args name rc
	if `rc' == 0 {
		global T_PASS = $T_PASS + 1
		display as result "PASS `name'"
	}
	else {
		global T_FAIL = $T_FAIL + 1
		global T_FAILED $T_FAILED `name'
		display as error "FAIL `name' (r(`rc'))"
	}
end

program define t_nnotes, rclass
	* Returns r(n), the number of notes on a variable or on _dta in the current frame
	args target
	local n : char `target'[note0]
	if "`n'" == "" local n 0
	return scalar n = `n'
end

program define t_firstvalue, rclass
	* Returns r(v), the smallest value of $TEST_VALVAR, and r(c), its count
	capture frame drop t_aux
	sqldta, server("$TEST_SERVER") database("$TEST_DATABASE") ///
		dataset("$TEST_SCHEMA.$TEST_TABLE") frame(t_aux) labels(none)
	frame t_aux {
		summarize $TEST_VALVAR, meanonly
		local v = r(min)
		quietly count if $TEST_VALVAR == `v'
		local c = r(N)
	}
	frame drop t_aux
	return scalar v = `v'
	return scalar c = `c'
end

program define t_datecheck
	* Checks that each SQL date column of the known table is numeric with a
	* date format in frame `target'; there is nothing to check if it has none
	args target
	capture frame drop t_aux
	sqldta, server("$TEST_SERVER") database("$TEST_DATABASE") ///
		dataset(INFORMATION_SCHEMA.COLUMNS) sqlselect(COLUMN_NAME) labels(none) ///
		sqlwhere(TABLE_SCHEMA = N'$TEST_SCHEMA' AND TABLE_NAME = N'$TEST_TABLE' AND DATA_TYPE = N'date') ///
		frame(t_aux)
	local n = r(N)
	forvalues i = 1/`n' {
		frame t_aux: local c = COLUMN_NAME[`i']
		frame `target' {
			confirm numeric variable `c', exact
			local f : format `c'
			display as text "  `c': numeric, format `f'"
			assert substr("`f'", 1, 2) == "%t"
		}
	}
	frame drop t_aux
	display as text "`n' date columns checked"
end

program define t_fixcheck
	* Compares the labels and notes in frame `target' with the fixture rows of
	* the known table sqldta_test_known, for the label types listed in `types'
	* (valuelabel variablelabel variablenote datasetnote)
	args target types
	local saved `"$SQLDTA_CONNECTION"'
	global SQLDTA_CONNECTION `"$TEST_CONNECTION"'
	capture frame drop t_aux
	sqldta, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset("$TEST_FIXSCHEMA.$TEST_FIXTABLE") frame(t_aux) labels(none)
	global SQLDTA_CONNECTION `"`saved'"'
	frame t_aux: mata: T_ROWS = st_sdata(., ("TableSchema", "TableName", "ColumnName", "PropertyType", "DataType", "PropertyCode", "PropertyText"))
	frame drop t_aux
	frame `target': mata: st_numscalar("t_bad", t_fixcheck_m(T_ROWS, "$TEST_FIXSCHEMA", "sqldta_test_known", "`types'"))
	display as text "fixture rows missing or altered: " scalar(t_bad)
	assert scalar(t_bad) == 0
end

program define t_ifcheck
	* Checks that sqldta if `expr' loads the rows that a full load followed by
	* keep if `expr' leaves, compared by id. The table is sqldta_test_main
	* unless `opts' gives dataset() and, if wanted, sqlselect().
	args expr opts
	if `"`opts'"' == "" local opts dataset($TEST_FIXSCHEMA.sqldta_test_main)
	local f server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		labeltable("$TEST_FIXSCHEMA.$TEST_FIXTABLE") `opts'
	capture frame drop t_ifall
	capture frame drop t_ifone
	quietly sqldta, `f' frame(t_ifall)
	local want
	frame t_ifall {
		quietly count if `expr'
		if r(N) > 0 quietly levelsof id if `expr', local(want)
	}
	sqldta if `expr', `f' frame(t_ifone)
	display as text `"  SQL: `r(sql)'"'
	local got
	if r(N) > 0 {
		frame t_ifone: quietly levelsof id, local(got)
	}
	display as text "  keep if: `want'"
	display as text "  sqldta:  `got'"
	frame drop t_ifall
	frame drop t_ifone
	assert "`got'" == "`want'"
end

program define t_serverinfo
	* Displays the version and edition of SQL Server and the compatibility
	* level and collation of the test database, read with odbc load directly
	* through the connection template
	local cs `"$TEST_CONNECTION"'
	local cs : subinstr local cs "%server%" "$TEST_SERVER", all
	local cs : subinstr local cs "%database%" "$TEST_DATABASE", all
	capture frame drop t_srv
	frame create t_srv
	frame t_srv: odbc load, exec(`"SELECT CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)) AS version, CAST(SERVERPROPERTY('Edition') AS nvarchar(128)) AS edition, CAST(name AS nvarchar(128)) AS name, CAST(compatibility_level AS int) AS compatibility, CAST(collation_name AS nvarchar(128)) AS collation FROM sys.databases WHERE name = N'$TEST_FIXDATABASE'"') connectionstring(`"`cs'"') clear
	frame t_srv: list, noobs
	frame drop t_srv
end

program define t_typereport
	* Loads each column in `cols' of the fixture table `dataset' on its own,
	* with its variable label, which gives its SQL type, and displays the
	* return code, the Stata storage type and display format, and the value of
	* each row in order of id. Strings are shown up to 40 characters, with
	* their length. Not a test: nothing is asserted.
	args path opts dataset cols
	display as text _n "TYPE REPORT `dataset', `path'"
	foreach c of local cols {
		capture frame drop t_tr
		capture sqldta, `opts' dataset($TEST_FIXSCHEMA.`dataset') sqlselect(id `c') frame(t_tr) labels(variables)
		local rc = _rc
		local conv `r(converted)'
		if `rc' {
			display as text "`c': r(`rc')"
			continue
		}
		local stype
		frame t_tr {
			capture confirm variable `c', exact
			if _rc == 0 {
				local sqltype : variable label `c'
				local stype : type `c'
				local fmt : format `c'
				local n = _N
				sort id
			}
		}
		if "`stype'" == "" {
			display as text "`c': loaded, but without the column"
			frame drop t_tr
			continue
		}
		local how
		if `: list c in conv' local how ", converted from a string by sqldta"
		display as text "`c' (`sqltype'): `stype' `fmt'`how'"
		forvalues i = 1/`n' {
			if substr("`stype'", 1, 3) == "str" {
				frame t_tr: local s = `c'[`i']
				local len = ustrlen(`"`macval(s)'"')
				local s = usubstr(`"`macval(s)'"', 1, 40)
				display as text `"    `i': "`macval(s)'" (`len' characters)"'
			}
			else {
				frame t_tr: local raw = string(`c'[`i'], "%21.0g")
				frame t_tr: local shown = string(`c'[`i'], "`fmt'")
				local extra
				if inlist(substr("`fmt'", 1, 3), "%tc", "%tC") {
					frame t_tr: local extra = "  " + string(`c'[`i'], "%tcCCYY-NN-DD_HH:MM:SS.sss")
				}
				display as text "    `i': `raw' [`shown']`extra'"
			}
		}
		frame drop t_tr
	}
end

program define t_samedata, rclass
	* Compares frames a and b, which hold one table loaded in two ways, in order
	* of id. Returns r(bad), the variables whose values differ, or "(names)" if
	* the frames hold different variables. Storage types and display formats
	* that differ are displayed but not counted.
	args a b
	frame `a': quietly ds
	local va `r(varlist)'
	frame `b': quietly ds
	local vb `r(varlist)'
	local bad
	if "`va'" != "`vb'" {
		display as text "  variables differ: `va' | `vb'"
		local bad (names)
	}
	frame `a': sort id
	frame `b': sort id
	foreach v of local va {
		if !`: list v in vb' continue
		frame `a': local ta : type `v'
		frame `b': local tb : type `v'
		frame `a': local fa : format `v'
		frame `b': local fb : format `v'
		local sa = substr("`ta'", 1, 3) == "str"
		local sb = substr("`tb'", 1, 3) == "str"
		local same 0
		if `sa' == `sb' {
			if `sa' {
				frame `a': mata: T_A = st_sdata(., "`v'")
				frame `b': mata: T_B = st_sdata(., "`v'")
			}
			else {
				frame `a': mata: T_A = st_data(., "`v'")
				frame `b': mata: T_B = st_data(., "`v'")
			}
			mata: st_local("same", strofreal(T_A == T_B))
		}
		if !`same' {
			display as text "  `v': values differ (`ta' `fa' and `tb' `fb')"
			local bad `bad' `v'
		}
		else if "`ta'" != "`tb'" | "`fa'" != "`fb'" {
			display as text "  `v': same values, stored as `ta' `fa' and `tb' `fb'"
		}
	}
	return local bad `bad'
end

program define t_vlcheck
	* Checks that the value label lbl in the current frame has k values, from
	* min to max
	args lbl k min max
	mata: t_V = .; t_T = ""; st_vlload("`lbl'", t_V, t_T); st_numscalar("t_k", rows(t_V)); st_numscalar("t_min", min(t_V)); st_numscalar("t_max", max(t_V))
	display as text "  `lbl': " scalar(t_k) " values, from " %12.0f scalar(t_min) " to " %12.0f scalar(t_max)
	assert scalar(t_k) == `k' & scalar(t_min) == `min' & scalar(t_max) == `max'
end

program define t_samelabels
	* Asserts that frames a and b hold the same variables, in the same order,
	* with the same display formats, variable labels, value labels and notes,
	* and the same data label and dataset notes. With sorted, the notes of
	* each variable and of the dataset are compared in sorted order, for
	* notes without a PropertyCode, whose order SQL Server does not guarantee.
	args a b sorted
	local srt = "`sorted'" != ""
	frame `a': local da : data label
	frame `b': local db : data label
	display as text `"  data labels: `da' | `db'"'
	frame `a': mata: t_LA = t_labeldump(`srt')
	frame `b': mata: t_LB = t_labeldump(`srt')
	mata: st_numscalar("t_same", t_LA == t_LB)
	if scalar(t_same) == 0 {
		mata: printf("{txt}  `a': %s\n  `b': %s\n", t_LA, t_LB)
	}
	assert scalar(t_same) == 1 & `"`da'"' == `"`db'"'
end

program define t_exsame
	* Asserts that frame f holds exactly the rows of frame t_adm whose
	* variable flag is 1, compared by id, and that it holds some (tests 212
	* to 219)
	args f flag
	frame t_adm: mata: t_A = t_keys("`flag'")
	frame `f': mata: t_B = t_keys("")
	mata: st_local("same", strofreal(rows(t_A) == rows(t_B) && (rows(t_A) == 0 || t_A == t_B)))
	mata: st_local("n", strofreal(rows(t_B)))
	display as text "  rows selected: `n', the same as the Stata equivalent: `same'"
	assert `same' & `n' > 0
end

program define t_exsubset
	* Asserts that every row of frame sub is in frame f, compared by id, and
	* that sub holds some (tests 220 and 221)
	args f sub
	frame `sub': mata: t_A = t_keys("")
	frame `f': mata: t_B = t_keys("")
	mata: st_local("isin", strofreal(t_isin(t_A, t_B)))
	mata: st_local("n", strofreal(rows(t_A)))
	display as text "  rows: `n' in `sub', all in `f': `isin'"
	assert `isin' & `n' > 0
end

mata:
// Writes the lines L to the settings file fn, with CRLF line ends if crlf is
// not 0 and a UTF-8 byte-order mark first if bom is not 0, as Notepad on
// Windows may save it
void t_writecfg(string scalar fn, string colvector L, real scalar crlf, real scalar bom)
{
	real scalar fh, i

	if (fileexists(fn)) unlink(fn)
	fh = fopen(fn, "w")
	if (bom) fwrite(fh, char((239, 187, 191)))
	for (i = 1; i <= rows(L); i++) fwrite(fh, L[i] + (crlf ? char(13) : "") + char(10))
	fclose(fh)
}

// Keeps every global macro but the system macros S_*, in the Mata external
// variable t_saved_globals, for the test of macro drop _all
void t_globals_save()
{
	string colvector n
	string matrix G
	pointer() scalar p
	real scalar i

	n = st_dir("global", "macro", "*")
	G = J(0, 2, "")
	for (i = 1; i <= rows(n); i++) {
		if (substr(n[i], 1, 2) != "S_") G = G \ (n[i], st_global(n[i]))
	}
	p = findexternal("t_saved_globals")
	if (p == NULL) p = crexternal("t_saved_globals")
	*p = G
}

// Sets again the globals kept by t_globals_save
void t_globals_restore()
{
	pointer() scalar p
	real scalar i

	p = findexternal("t_saved_globals")
	if (p == NULL) return
	for (i = 1; i <= rows(*p); i++) st_global((*p)[i, 1], (*p)[i, 2])
}

real scalar t_hasnote(string scalar v, string scalar txt)
{
	real scalar j, n

	n = strtoreal(st_global(v + "[note0]"))
	if (n >= .) n = 0
	for (j = 1; j <= n; j++) {
		if (st_global(v + "[note" + strofreal(j) + "]") == txt) return(1)
	}
	return(0)
}

// Checks each fixture row against the current frame. A row is expected to be
// applied if its type is requested, it is filed under the schema and table
// loaded, its text is not empty, its ColumnName matches a loaded variable
// without regard to case and, for ValueLabel rows, the variable is numeric and
// its code is an integer; DataType is not used. Returns the number of
// expected rows whose text is missing or altered, plus the number of dataset
// notes of other tables, or of the same table in another schema, that were
// applied. R holds TableSchema, TableName, ColumnName, PropertyType, DataType,
// PropertyCode and PropertyText.
real scalar t_fixcheck_m(string matrix R, string scalar schema, string scalar table, string scalar types)
{
	real scalar i, code, found, bad, mine
	real matrix k
	string scalar vn, lt, txt, v
	string rowvector vars

	vars = st_varname(1..st_nvar())
	bad = 0
	for (i = 1; i <= rows(R); i++) {
		mine = ustrlower(strtrim(R[i, 1])) == ustrlower(schema) & ustrlower(strtrim(R[i, 2])) == ustrlower(table)
		vn  = strtrim(R[i, 3])
		lt  = strlower(strtrim(R[i, 4]))
		txt = R[i, 7]
		if (strlen(txt) == 0) continue
		if (!strpos(" " + types + " ", " " + lt + " ")) continue
		if (lt == "datasetnote") {
			found = t_hasnote("_dta", txt)
			if (mine & !found) {
				printf("{err}dataset note missing or altered: %s\n", usubstr(txt, 1, 60))
				bad++
			}
			else if (!mine & found) {
				printf("{err}dataset note of another table applied: %s\n", usubstr(txt, 1, 60))
				bad++
			}
			continue
		}
		if (!mine) continue
		k = selectindex(ustrlower(vars) :== ustrlower(vn))
		if (length(k) == 0) continue
		v = vars[k[1]]
		if (lt == "valuelabel") {
			if (st_isstrvar(v)) continue
			code = strtoreal(strtrim(R[i, 6]))
			if (code >= . | code != floor(code)) continue
			if (st_varvaluelabel(v) != v) {
				printf("{err}value-label set %s not attached\n", v)
				bad++
			}
			else if (st_vlmap(v, code) != txt) {
				printf("{err}value label %s %g missing or altered: %s\n", v, code, usubstr(txt, 1, 60))
				bad++
			}
		}
		else if (lt == "variablelabel") {
			if (st_varlabel(v) != txt) {
				printf("{err}variable label of %s missing or altered: %s\n", v, usubstr(txt, 1, 60))
				bad++
			}
		}
		else if (lt == "variablenote") {
			if (!t_hasnote(v, txt)) {
				printf("{err}note on %s missing or altered: %s\n", v, usubstr(txt, 1, 60))
				bad++
			}
		}
	}
	return(bad)
}

// The ids of the rows of the current frame whose variable flag is 1, or of
// every row if flag is "", as text, sorted
string colvector t_keys(string scalar flag)
{
	real colvector r

	if (st_nobs() == 0) return(J(0, 1, ""))
	r = (flag == "" ? (1::st_nobs()) : selectindex(st_data(., flag)))
	if (rows(r) == 0) return(J(0, 1, ""))
	return(sort(strofreal(st_data(r, "id"), "%21.0g"), 1))
}

// Whether every element of A is in B
real scalar t_isin(string colvector A, string colvector B)
{
	transmorphic h
	real scalar i

	h = asarray_create()
	for (i = 1; i <= rows(B); i++) asarray(h, B[i], 1)
	for (i = 1; i <= rows(A); i++) {
		if (!asarray_contains(h, A[i])) return(0)
	}
	return(1)
}

// The notes of v (a variable, or _dta) in the current frame, as one string,
// in sorted order if sorted is 1
string scalar t_notedump(string scalar v, real scalar sorted)
{
	string scalar s
	string colvector t
	real scalar j, n

	n = strtoreal(st_global(v + "[note0]"))
	if (n >= .) n = 0
	t = J(n, 1, "")
	for (j = 1; j <= n; j++) t[j] = st_global(v + "[note" + strofreal(j) + "]")
	if (sorted & n > 1) t = sort(t, 1)
	s = ""
	for (j = 1; j <= n; j++) s = s + " note" + strofreal(j) + "=" + t[j]
	return(s)
}

// The labels of the current frame as one string: the dataset notes, then for
// each variable, in order, its name, display format, variable label, value
// label with its codes and texts, and notes, in sorted order if sorted is 1.
// The data label is compared apart, by t_samelabels.
string scalar t_labeldump(real scalar sorted)
{
	string scalar s, v, vl
	string colvector txt
	real colvector vals
	real scalar i, j

	s = "_dta:" + t_notedump("_dta", sorted)
	for (j = 1; j <= st_nvar(); j++) {
		v = st_varname(j)
		s = s + " | " + v + " " + st_varformat(j) + " [" + st_varlabel(j) + "]"
		vl = st_varvaluelabel(j)
		if (vl != "") {
			st_vlload(vl, vals, txt)
			s = s + " " + vl + ":"
			for (i = 1; i <= rows(vals); i++) s = s + " " + strofreal(vals[i], "%21.0g") + "=" + txt[i]
		}
		s = s + t_notedump(v, sorted)
	}
	return(s)
}
end

* ---------------------------------------------------------------------------
* Tests
* ---------------------------------------------------------------------------

t_gitcommit

* Not tests: two checks that stop the run, with a message, when every test
* would fail or would test the wrong code.
*
* First, every file of src/sqldta.pkg must be found first in this clone's src/
* along the ado-path, so that the tests run this clone's code and not a copy
* of sqldta installed in PLUS, SITE or elsewhere; clear all, at the top, has
* dropped any program already loaded.
local t_srcnorm = ustrregexra(subinstr(ustrlower(`"`srcdir'"'), "\", "/", .), "/+", "/")
local t_pkgfiles
tempname pkgfh
file open `pkgfh' using "$TEST_SRC/sqldta.pkg", read text
file read `pkgfh' line
while r(eof) == 0 {
	if inlist(substr(`"`line'"', 1, 2), "f ", "F ") local t_pkgfiles `t_pkgfiles' `=strtrim(substr(`"`line'"', 3, .))'
	file read `pkgfh' line
}
file close `pkgfh'
local t_wrong
foreach f of local t_pkgfiles {
	capture findfile `f'
	local rc = _rc
	local fn = ustrregexra(subinstr(ustrlower(`"`r(fn)'"'), "\", "/", .), "/+", "/")
	if `rc' | strpos(`"`fn'"', `"`t_srcnorm'/"') != 1 local t_wrong `t_wrong' `f'
}
if "`t_wrong'" != "" | "`t_pkgfiles'" == "" {
	display as error "files of the package not found first in `srcdir': `t_wrong'"
	display as error "the tests would not test this clone's code; run this file from the root of the clone, in a new Stata session"
	log close sqldtatest
	exit 9
}
display as text "files of the package, all found in `srcdir': `t_pkgfiles'"

* Second, the fixtures must be of the version that this file expects, which
* tests/create_fixtures.sql writes in sqldta_test_version. The query runs
* under capture noisily, so that a failure shows the driver's message, which
* tells a table that does not exist from a connection that failed.
local t_precs `"$TEST_CONNECTION"'
local t_precs : subinstr local t_precs "%server%" "$TEST_SERVER", all
local t_precs : subinstr local t_precs "%database%" "$TEST_FIXDATABASE", all
capture frame drop t_pre
frame create t_pre
capture noisily frame t_pre: odbc load, clear connectionstring(`"`t_precs'"') exec(`"SELECT FixtureVersion FROM [$TEST_FIXDATABASE].[$TEST_FIXSCHEMA].[sqldta_test_version]"')
local rc = _rc
local t_fv
if `rc' == 0 frame t_pre: local t_fv = FixtureVersion[1]
capture frame drop t_pre
if "`t_fv'" != "$TEST_FIXVERSION" {
	if `rc' {
		display as error "the version of the fixtures could not be read from $TEST_FIXDATABASE.$TEST_FIXSCHEMA.sqldta_test_version: r(`rc'), with the driver's message above"
		display as error "if the table does not exist, run tests/create_fixtures.sql in SSMS and let it finish; otherwise check the connection; then run this file again"
	}
	else {
		display as error "the fixtures are version `t_fv', and this file expects version $TEST_FIXVERSION"
		display as error "run tests/create_fixtures.sql in SSMS, then this file again"
	}
	log close sqldtatest
	exit 459
}
display as text "fixtures: version `t_fv'"

* 1. A new frame() with labels(none): expected size, no labels or notes,
*    current frame unchanged
t_reset
capture noisily {
	sqldta, `src' frame(t1) `nolab'
	assert r(N) == $TEST_N
	assert r(k) == $TEST_K
	assert "`r(frame)'" == "t1"
	assert "`r(labelstatus)'" == "none"
	assert "`r(labels)'" == ""
	assert "`c(frame)'" == "default"
	assert c(N) == 0 & c(k) == 0
	frame t1 {
		assert _N == $TEST_N
		assert c(k) == $TEST_K
		quietly label dir
		assert "`r(names)'" == ""
		t_nnotes _dta
		assert r(n) == 0
	}
}
t_result basic_newframe `=_rc'

* 2. No frame(): loads into the empty current frame
t_reset
capture noisily {
	sqldta, `src'
	assert "`r(frame)'" == "default"
	assert c(N) == $TEST_N
	assert c(k) == $TEST_K
}
t_result basic_current `=_rc'

* 3. Current frame holds data and clear is not given: error 4, data untouched
t_reset
capture noisily {
	set obs 3
	generate x = 1
	display as text "(error 4 is expected here)"
	capture noisily sqldta, `src'
	assert _rc == 4
	assert c(N) == 3 & c(k) == 1
	confirm variable x, exact
}
t_result refuse_current `=_rc'

* 4. frame() holds data and clear is not given: error 4, data untouched
t_reset
capture noisily {
	frame create t4
	frame t4 {
		set obs 3
		generate x = 1
	}
	display as text "(error 4 is expected here)"
	capture noisily sqldta, `src' frame(t4)
	assert _rc == 4
	frame t4: assert c(N) == 3 & c(k) == 1
}
t_result refuse_frame `=_rc'

* 5. As test 4 with clear: the data are replaced
t_reset
capture noisily {
	frame create t5
	frame t5 {
		set obs 3
		generate x = 1
	}
	sqldta, `src' frame(t5) clear
	assert r(N) == $TEST_N
	frame t5: assert c(N) == $TEST_N & c(k) == $TEST_K
}
t_result clear_replaces `=_rc'

* 6. A table that does not exist: an error, and no frame left behind
t_reset
capture noisily {
	display as text "(a query failure is expected here)"
	capture noisily sqldta, server("$TEST_SERVER") database("$TEST_DATABASE") ///
		dataset("$TEST_SCHEMA.sqldta_no_such_table") frame(t6)
	assert _rc != 0
	assert "`c(frame)'" == "default"
	capture frame create t6
	assert _rc == 0
}
t_result bad_table `=_rc'

* 7. labels(all) with the default label table, ref.DataProperties
t_reset
capture noisily {
	sqldta, `src' `lbl' frame(t7) `alllab'
	assert "`r(labelstatus)'" == "applied"
	assert r(n_vallabels) >= 1 & r(n_varlabels) >= 1
	assert r(n_varnotes) >= 1 & r(n_dtanotes) >= 1
	frame t7 {
		local lab : value label $TEST_VALVAR
		assert "`lab'" == "$TEST_VALVAR"
		quietly label list `lab'
		assert r(k) >= 1
		local vl : variable label $TEST_VALVAR
		assert `"`vl'"' != ""
		t_nnotes $TEST_NOTEVAR
		assert r(n) >= 1
		t_nnotes _dta
		assert r(n) >= 1
	}
}
t_result all_labels `=_rc'

* 8. labels(values) alone: value labels, no notes
t_reset
capture noisily {
	sqldta, `src' `lbl' frame(t8) labels(values)
	assert r(n_vallabels) >= 1
	assert r(n_varlabels) == 0 & r(n_varnotes) == 0 & r(n_dtanotes) == 0
	frame t8 {
		local lab : value label $TEST_VALVAR
		assert "`lab'" == "$TEST_VALVAR"
		t_nnotes $TEST_NOTEVAR
		assert r(n) == 0
		t_nnotes _dta
		assert r(n) == 0
	}
}
t_result vallabels_only `=_rc'

* 9. labels(varnotes) alone: variable notes, no value-label sets
t_reset
capture noisily {
	sqldta, `src' `lbl' frame(t9) labels(varnotes)
	assert r(n_varnotes) >= 1 & r(n_vallabels) == 0
	frame t9 {
		t_nnotes $TEST_NOTEVAR
		assert r(n) >= 1
		quietly label dir
		assert "`r(names)'" == ""
	}
}
t_result varnotes_only `=_rc'

* 10. A dataset with no rows in the label table (INFORMATION_SCHEMA.TABLES)
t_reset
capture noisily {
	sqldta, server("$TEST_SERVER") database("$TEST_DATABASE") ///
		dataset(INFORMATION_SCHEMA.TABLES) `lbl' frame(t10) `alllab'
	assert "`r(labelstatus)'" == "applied"
	assert r(N) >= 1
	assert r(n_vallabels) == 0 & r(n_varlabels) == 0 & r(n_varnotes) == 0
	assert r(n_dtanotes) == 0 & r(n_skipped) == 0
	frame t10 {
		quietly label dir
		assert "`r(names)'" == ""
		t_nnotes _dta
		assert r(n) == 0
	}
}
t_result no_labels `=_rc'

* 11. A label table that does not exist: data loaded, no labels, and the
*     summary line says so; the same without labels()
t_reset
capture noisily {
	sqldta, `src' labeltable("$TEST_LABELSCHEMA.sqldta_no_such_table") frame(t11) `alllab'
	assert "`r(labelstatus)'" == "notfound"
	assert r(N) == $TEST_N
	assert r(n_vallabels) == 0 & r(n_varnotes) == 0 & r(n_dtanotes) == 0
	frame t11 {
		quietly label dir
		assert "`r(names)'" == ""
		t_nnotes $TEST_NOTEVAR
		assert r(n) == 0
		t_nnotes _dta
		assert r(n) == 0
	}
	sqldta, `src' labeltable("$TEST_LABELSCHEMA.sqldta_no_such_table") frame(t11b)
	assert "`r(labelstatus)'" == "notfound"
	assert r(N) == $TEST_N
}
t_result missing_label_table `=_rc'

* 12. Site globals are read, and options override them. A label table named
*     without a schema is in the schema of the default label table; a table
*     named without a schema is in $SQLDTA_DATASCHEMA. With neither
*     labeltable() nor $SQLDTA_LABELTABLE, the label table is
*     ref.DataProperties: the same status and counts as with it named.
t_reset
capture noisily {
	global SQLDTA_LABELTABLE "$TEST_LABELSCHEMA.sqldta_no_such_table"
	sqldta, `src' frame(t12a) labels(values)
	assert "`r(labelstatus)'" == "notfound"
	sqldta, `src' labeltable("$TEST_LABELTABLE") frame(t12b) labels(values)
	assert "`r(labelstatus)'" == "applied"
	assert r(n_vallabels) >= 1
	global SQLDTA_DATASCHEMA "$TEST_SCHEMA"
	sqldta, server("$TEST_SERVER") database("$TEST_DATABASE") dataset("$TEST_TABLE") frame(t12c)
	assert "`r(table)'" == "`table'"
	assert r(N) == $TEST_N
	global SQLDTA_LABELTABLE
	global SQLDTA_DATASCHEMA
	sqldta, `src' frame(t12d) labels(values variables)
	local a `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)'
	sqldta, `src' labeltable(ref.DataProperties) frame(t12e) labels(values variables)
	local b `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)'
	display as text "default label table: `a'; ref.DataProperties: `b'"
	assert "`a'" == "`b'"
}
t_result settings_globals `=_rc'

* 13. sqlselect() with lowercase: two variables in lower case, labels attached,
*     and no value-label sets for variables that were not loaded
t_reset
capture noisily {
	sqldta, `src' `lbl' sqlselect($TEST_VALVAR, $TEST_NOTEVAR) lowercase labels(values varnotes) ///
		frame(t13)
	assert r(k) == 2
	local v = ustrlower("$TEST_VALVAR")
	local w = ustrlower("$TEST_NOTEVAR")
	frame t13 {
		confirm variable `v', exact
		confirm variable `w', exact
		local lab : value label `v'
		assert "`lab'" == "`v'"
		t_nnotes `w'
		assert r(n) >= 1
		quietly label dir
		assert "`r(names)'" == "`v'"
	}
}
t_result sqlselect_lowercase `=_rc'

* 14. sqlselect() in a different case without lowercase: labels still attached,
*     and the variable keeps the name as typed
t_reset
capture noisily {
	local typed = ustrupper("$TEST_VALVAR")
	if "`typed'" == "$TEST_VALVAR" local typed = ustrlower("$TEST_VALVAR")
	assert "`typed'" != "$TEST_VALVAR"
	sqldta, `src' `lbl' sqlselect(`typed') labels(values variables) frame(t14)
	assert r(k) == 1
	frame t14 {
		unab v : _all
		display as text "requested `typed', loaded as `v'"
		local lab : value label `v'
		assert "`lab'" == "`v'"
		local vl : variable label `v'
		assert `"`vl'"' != ""
		assert "`v'" == "`typed'"
	}
}
t_result sqlselect_case `=_rc'

* 15. lowercase without sqlselect(): every name in lower case
t_reset
capture noisily {
	sqldta, `src' lowercase frame(t15)
	assert r(k) == $TEST_K
	frame t15 {
		foreach v of varlist _all {
			assert "`v'" == ustrlower("`v'")
		}
	}
}
t_result lowercase_all `=_rc'

* 16. sqlwhere(): the row count matches a count made in Stata
t_reset
capture noisily {
	t_firstvalue
	local v = r(v)
	local c = r(c)
	sqldta, `src' sqlwhere($TEST_VALVAR = `v') frame(t16)
	assert r(N) == `c'
}
t_result sqlwhere `=_rc'

* 17. sqlwhere() that matches nothing, with labels(all): no error
t_reset
capture noisily {
	sqldta, `src' `lbl' sqlwhere(1 = 0) frame(t17) `alllab'
	assert r(N) == 0
	display as text "variables created for an empty result: " r(k)
}
t_result sqlwhere_empty `=_rc'

* 18. sqlrand(): row count and the SQL that was built
t_reset
capture noisily {
	sqldta, `src' sqlrand(3) frame(t18)
	assert strpos(`"`r(sql)'"', "TOP (3)") > 0
	assert strpos(`"`r(sql)'"', "ORDER BY NEWID()") > 0
	assert r(N) == min(3, $TEST_N)
	assert r(k) == $TEST_K
}
t_result sqlrand `=_rc'

* 19. sqlrand() larger than the table: every row
t_reset
capture noisily {
	local big = $TEST_N + 10
	sqldta, `src' sqlrand(`big') frame(t19)
	assert r(N) == $TEST_N
}
t_result sqlrand_large `=_rc'

* 20. sqlrand() with sqlwhere(): one row that meets the condition
t_reset
capture noisily {
	t_firstvalue
	local v = r(v)
	sqldta, `src' sqlrand(1) sqlwhere($TEST_VALVAR = `v') frame(t20)
	assert r(N) == 1
	frame t20: assert $TEST_VALVAR == `v'
}
t_result sqlrand_where `=_rc'

* 21. sqlrand(0) is rejected before any frame is created
t_reset
capture noisily {
	display as text "(a syntax error is expected here)"
	capture noisily sqldta, `src' sqlrand(0) frame(t21)
	assert _rc != 0
	capture frame create t21
	assert _rc == 0
}
t_result sqlrand_invalid `=_rc'

* 22. No server(): the first word of $SQLDTA_SERVERS is used
t_reset
capture noisily {
	global SQLDTA_SERVERS "$TEST_SERVER OTHERSERVER"
	sqldta, database("$TEST_DATABASE") dataset("$TEST_SCHEMA.$TEST_TABLE") frame(t22)
	assert "`r(server)'" == "$TEST_SERVER"
	assert r(N) == $TEST_N
}
t_result server_default `=_rc'

* 23. No server() and no $SQLDTA_SERVERS: error 198
t_reset
capture noisily {
	display as text "(error 198 is expected here)"
	capture noisily sqldta, database("$TEST_DATABASE") ///
		dataset("$TEST_SCHEMA.$TEST_TABLE") frame(t23)
	assert _rc == 198
}
t_result server_required `=_rc'

* 24. Connection template: with %server%, without it, and with a bad driver
t_reset
capture noisily {
	sqldta, `src' frame(t24a)
	assert r(N) == $TEST_N
	global SQLDTA_CONNECTION : subinstr global TEST_CONNECTION "%server%" "$TEST_SERVER", all
	sqldta, `src' frame(t24b)
	assert r(N) == $TEST_N
	global SQLDTA_CONNECTION "Driver={sqldta no such driver};Server=%server%;"
	display as text "(a connection failure is expected here)"
	capture noisily sqldta, `src' frame(t24c)
	assert _rc != 0
	capture frame create t24c
	assert _rc == 0
}
t_result connect_template `=_rc'

* 25. Empty $SQLDTA_CONNECTION: dsn(server), with labels(all)
t_reset
capture noisily {
	global SQLDTA_CONNECTION
	sqldta, `src' `lbl' frame(t25) `alllab'
	assert r(N) == $TEST_N & r(k) == $TEST_K
	assert "`r(labelstatus)'" == "applied"
	assert r(n_vallabels) >= 1 & r(n_varlabels) >= 1
	assert r(n_varnotes) >= 1 & r(n_dtanotes) >= 1
}
t_result connect_dsn `=_rc'

* 26. Minimum abbreviations: datas() for dataset(), labelt() for
*     labeltable(), nodec for nodecformat, and the label types in upper case
t_reset
capture noisily {
	sqldta, ser("$TEST_SERVER") datab("$TEST_DATABASE") datas("$TEST_SCHEMA.$TEST_TABLE") ///
		labelt("$TEST_LABELSCHEMA.$TEST_LABELTABLE") labels(VALUES Variables) ///
		fra(t26) low nodec sqls(*) sqlw(1 = 1) sqlr($TEST_N) clear
	assert r(N) == $TEST_N
	assert "`r(labelstatus)'" == "applied"
	assert "`r(labels)'" == "values variables"
	assert r(n_vallabels) >= 1
}
t_result abbrev `=_rc'

* 27. SQL date columns are numeric dates through the connection template
t_reset
capture noisily {
	sqldta, `src' frame(t27)
	display as text "converted from strings: `r(converted)'"
	t_datecheck t27
}
t_result dates_template `=_rc'

* 28. SQL date columns are numeric dates through dsn(), which exercises the
*     conversion when the DSN uses the legacy "SQL Server" driver; each
*     converted column has the same count, minimum and maximum as through the
*     connection template
t_reset
capture noisily {
	global SQLDTA_CONNECTION
	sqldta, `src' frame(t28)
	local converted `r(converted)'
	display as text "converted from strings: `converted'"
	t_datecheck t28
	global SQLDTA_CONNECTION `"$TEST_CONNECTION"'
	sqldta, `src' frame(t28b)
	foreach v of local converted {
		frame t28: quietly summarize `v'
		local a `r(N)' `r(min)' `r(max)'
		frame t28b: quietly summarize `v'
		local b `r(N)' `r(min)' `r(max)'
		display as text "  `v': dsn() `a', template `b'"
		assert "`a'" == "`b'"
	}
}
t_result dates_dsn `=_rc'

* 29. Working frames are dropped: only the target frame is added
t_reset
capture noisily {
	quietly frames dir
	local before `r(frames)'
	sqldta, `src' `lbl' frame(t29) `alllab'
	quietly frames dir
	local after `r(frames)'
	local expect `before' t29
	display as text "frames after the call: `after'"
	assert `: list after === expect'
}
t_result no_frame_leak `=_rc'

* 30. Returned results and the data label for a load with labels(none). The
*     column list is * unless a column has a type that sqldta sends as an
*     expression, so only the start and the FROM clause of r(sql) are checked.
t_reset
capture noisily {
	sqldta, `src' frame(t30) `nolab'
	assert "`r(frame)'" == "t30"
	assert "`r(server)'" == "$TEST_SERVER"
	assert "`r(database)'" == "$TEST_DATABASE"
	assert "`r(table)'" == "`table'"
	local from " FROM [$TEST_DATABASE].[$TEST_SCHEMA].[$TEST_TABLE]"
	assert substr(`"`r(sql)'"', 1, 7) == "SELECT "
	assert substr(`"`r(sql)'"', -strlen("`from'"), .) == "`from'"
	assert "`r(labelstatus)'" == "none"
	frame t30 {
		local dl : data label
		assert `"`dl'"' == usubstr("`table'", 1, 80)
	}
}
t_result returns `=_rc'

* 31. Fixture label table, on the known table: exact text of every applied
*     row, and the counts
t_reset
capture noisily {
	sqldta, `fknown' `fix' frame(t31) `alllab'
	local got `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "status and counts: `got' (expected: applied 1 1 4 3 4)"
	t_fixcheck t31 "valuelabel variablelabel variablenote datasetnote"
	assert "`got'" == "applied 1 1 4 3 4"
}
t_result fixture_text `=_rc'

* 32. As test 31 with lowercase
t_reset
capture noisily {
	sqldta, `fknown' `fix' lowercase frame(t32) `alllab'
	local got `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "status and counts: `got' (expected: applied 1 1 4 3 4)"
	t_fixcheck t32 "valuelabel variablelabel variablenote datasetnote"
	assert "`got'" == "applied 1 1 4 3 4"
}
t_result fixture_lowercase `=_rc'

* 33. Fixture with sqlselect() of the noted variable only: no value-label set
*     is left in the frame, and only the two rows that name no column of the
*     table count as skipped; rows for columns not selected do not
t_reset
capture noisily {
	sqldta, `fknown' `fix' sqlselect($TEST_NOTEVAR) frame(t33) labels(values varnotes)
	local got `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "status and counts: `got' (expected: applied 0 0 4 0 2)"
	frame t33 {
		quietly label dir
		assert "`r(names)'" == ""
	}
	t_fixcheck t33 "valuelabel variablenote"
	assert "`got'" == "applied 0 0 4 0 2"
}
t_result fixture_sqlselect `=_rc'

* 34. As test 31 through dsn()
t_reset
capture noisily {
	global SQLDTA_CONNECTION
	sqldta, `fknown' `fix' frame(t34) `alllab'
	local got `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "status and counts: `got' (expected: applied 1 1 4 3 4)"
	t_fixcheck t34 "valuelabel variablelabel variablenote datasetnote"
	assert "`got'" == "applied 1 1 4 3 4"
}
t_result fixture_dsn `=_rc'

* 35. %database% in the template: substituted, and an unqualified object in
*     sqlwhere() resolves in database()
t_reset
capture noisily {
	local cs `"$TEST_CONNECTION"'
	if substr(`"`cs'"', -1, 1) != ";" local cs `"`cs';"'
	global SQLDTA_CONNECTION `"`cs'Database=%database%;"'
	display as text `"template: $SQLDTA_CONNECTION"'
	sqldta, `src' frame(t35) ///
		sqlwhere(EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = N'$TEST_SCHEMA' AND TABLE_NAME = N'$TEST_TABLE'))
	assert r(N) == $TEST_N
}
t_result connect_database `=_rc'

* ---------------------------------------------------------------------------
* Tests on the fixture data tables (tests/create_fixtures.sql)
* ---------------------------------------------------------------------------

* 36. Links: two linked tables joined by id; [bad name] and the linked copy of
*     shared are left out; values come from the right tables. The datetime
*     column stamp of the second linked table is sent as text and converted.
t_reset
capture noisily {
	sqldta, `fmain' frame(t36)
	assert r(N) == 8 & r(k) == 11
	assert "`r(links)'" == "ref.sqldta_test_part `fs'.sqldta_test_part2"
	assert "`r(linkkeys)'" == "id id"
	assert strpos(`"`r(dropped)'"', "bad name") > 0
	assert strpos(`"`r(dropped)'"', "sqldta_test_part.shared") > 0
	assert "`r(converted)'" == "stamp"
	frame t36 {
		confirm variable id num amount grp dob Order shared extra1 extra2 extra3 stamp, exact
		assert shared == id * 100
		assert extra1 == id * 10 if id != 7
		assert missing(extra1) & extra2 == "" if id == 7
		assert extra3 == id + 1000
		assert stamp == tc(01jan2020 12:00:00.500) + (id - 1) * 86400000
		assert "`: format stamp'" == "%tc"
	}
}
t_result link_join `=_rc'

* 37. Links with sqlselect(): columns of the linked tables can be selected
t_reset
capture noisily {
	sqldta, `fmain' sqlselect(id extra*) frame(t37)
	assert r(N) == 8 & r(k) == 4
	frame t37: confirm variable id extra1 extra2 extra3, exact
}
t_result link_select `=_rc'

* 38. Links with sqlrand(): a sample of the joined table
t_reset
capture noisily {
	sqldta, `fmain' sqlrand(3) frame(t38)
	assert r(N) == 3 & r(k) == 11
}
t_result link_rand `=_rc'

* 39. Links: label rows filed under a linked table's own name are applied
t_reset
capture noisily {
	sqldta, `fmain' labels(variables) frame(t39)
	frame t39 {
		local vl : variable label extra1
		assert `"`vl'"' == "Extra one, labelled under the linked table"
	}
}
t_result link_labels `=_rc'

* 40. Links: a key that repeats in a linked table stops before any data load
t_reset
capture noisily {
	display as text "(error 459 is expected here)"
	capture noisily sqldta, `fsrc' dataset(`fs'.sqldta_test_bad) frame(t40)
	assert _rc == 459
	capture frame create t40
	assert _rc == 0
}
t_result link_nonunique `=_rc'

* 41. sqlselect() wildcards: * and ?, in table order
t_reset
capture noisily {
	sqldta, `fmain' sqlselect(e*) frame(t41a)
	assert r(k) == 3
	frame t41a: confirm variable extra1 extra2 extra3, exact
	sqldta, `fmain' sqlselect(?rp) frame(t41b)
	assert r(k) == 1
	frame t41b: confirm variable grp, exact
}
t_result select_wildcards `=_rc'

* 42. sqlselect() with commas, with and without spaces, as legacy scripts pass it
t_reset
capture noisily {
	sqldta, `fmain' sqlselect(id, num,grp) frame(t42)
	assert r(k) == 3
	frame t42: confirm variable id num grp, exact
}
t_result select_commas `=_rc'

* 43. sqlselect() with a name that matches no column: error 111, no frame
t_reset
capture noisily {
	display as text "(error 111 is expected here)"
	capture noisily sqldta, `fmain' sqlselect(id nosuch) frame(t43)
	assert _rc == 111
	capture frame create t43
	assert _rc == 0
}
t_result select_unknown `=_rc'

* 44. sqlselect() keeps the case as typed, through an alias in the SQL
t_reset
capture noisily {
	sqldta, `fmain' sqlselect(NUM) frame(t44)
	assert strpos(`"`r(sql)'"', "[num] AS [NUM]") > 0
	frame t44: confirm variable NUM, exact
}
t_result select_case `=_rc'

* 45. sqlselect() of a column whose name is a T-SQL reserved word
t_reset
capture noisily {
	sqldta, `fmain' sqlselect(id Order) frame(t45)
	assert r(N) == 8 & r(k) == 2
	frame t45: assert Order == id
}
t_result select_reserved `=_rc'

* 46. Label rows for columns that exist but were not selected are not skipped
t_reset
capture noisily {
	sqldta, `fmain' sqlselect(id) labels(variables formats varnotes) frame(t46)
	assert r(n_skipped) == 0 & r(n_varnotes) == 0 & r(n_formats) == 0
}
t_result skipped_unselected `=_rc'

* 47. DatasetLabel and VariableFormat rows: the data label and two display
*     formats; the row with a format that is not valid counts as skipped
t_reset
capture noisily {
	sqldta, `fmain' labels(variables formats dtanotes datalabel) frame(t47)
	assert r(n_formats) == 2 & r(n_skipped) == 1 & r(n_varlabels) == 1
	frame t47 {
		local dl : data label
		assert `"`dl'"' == "Fixture main table"
		local f : format amount
		assert "`f'" == "%9.2fc"
		local f : format dob
		assert "`f'" == "%tdDD/NN/CCYY"
	}
}
t_result properties `=_rc'

* 48. Notes are applied in PropertyCode order: numeric for num (1, 2, 10, then
*     the note without a code), text for grp (a, b, c), and numeric for _dta
t_reset
capture noisily {
	sqldta, `fmain' labels(varnotes dtanotes) frame(t48)
	assert r(n_varnotes) == 7 & r(n_dtanotes) == 2
	frame t48 {
		local expect `" "First note on num" "Second note on num" "Third note on num" "Note on num without an order" "'
		local i 0
		foreach e of local expect {
			local ++i
			local got : char num[note`i']
			display as text `"  num[note`i']: `got'"'
			assert `"`got'"' == `"`e'"'
		}
		local expect `" "First note on grp" "Second note on grp" "Third note on grp" "'
		local i 0
		foreach e of local expect {
			local ++i
			local got : char grp[note`i']
			assert `"`got'"' == `"`e'"'
		}
		local got : char _dta[note1]
		assert `"`got'"' == "First dataset note"
		local got : char _dta[note2]
		assert `"`got'"' == "Second dataset note"
	}
}
t_result note_order `=_rc'

* 49 to 78. The if qualifier: each expression must load the rows that keep if
* leaves after a full load
local i 48
foreach e in ///
	`"num == 1"' `"num != 1"' `"num > 2"' `"num >= 2"' `"num < 2"' `"num <= 2"' ///
	`"num == ."' `"num != ."' `"missing(num, amount)"' `"!missing(amount)"' ///
	`"grp == "abc""' `"grp != "abc""' `"grp == """' `"grp > "abc""' `"grp == "O'Brien""' ///
	`"inlist(num, 1, 3, -9)"' `"inlist(grp, "abc", "Abc")"' `"inrange(amount, 0, 10)"' ///
	`"dob >= td(01jan2020)"' `"dob > td(01jan2020)"' `"dob < 21915"' `"year(dob) == 2020"' ///
	`"strlower(grp) == "abc""' `"substr(grp, 1, 2) == "ab""' ///
	`"(num > 2 & num < 6) | missing(amount)"' `"!(num == 1)"' `"num"' ///
	`"Order == 3"' `"extra1 > 30"' `"num == -9"' {
	local ++i
	t_reset
	display as text _n `"if `e'"'
	capture noisily t_ifcheck `"`e'"'
	t_result if_`i' `=_rc'
}

* 79. The if qualifier with an expression it does not support: error 198
t_reset
capture noisily {
	display as text "(error 198 is expected here)"
	capture noisily sqldta if num + 1 > 2, `fmain' frame(t79)
	assert _rc == 198
	display as text "(error 198 is expected here)"
	capture noisily sqldta if nosuch == 1, `fmain' frame(t79)
	assert _rc == 198
	capture frame create t79
	assert _rc == 0
}
t_result if_unsupported `=_rc'

* 80. The if qualifier together with sqlwhere(): both apply. num > 2 keeps
*     ids 3, 4, 5 and 8 (missing num counts as large), and id <> 5 drops 5
t_reset
capture noisily {
	sqldta if num > 2, `fmain' sqlwhere(id <> 5) frame(t80)
	assert r(N) == 3
	frame t80 {
		quietly levelsof id, local(ids)
		assert "`ids'" == "3 4 8"
	}
}
t_result if_sqlwhere `=_rc'

* ---------------------------------------------------------------------------
* SQL Server data types, in the fixture tables sqldta_test_types and
* sqldta_test_rare. Tests that check the display formats that sqldta sets use
* labels(none), because VariableFormat rows in the label table replace those
* formats.
* ---------------------------------------------------------------------------

local ftypes `fsrc' dataset(`fs'.sqldta_test_types)
local frare  `fsrc' dataset(`fs'.sqldta_test_rare)
local fdt    `fsrc' dataset(`fs'.sqldta_test_dt)

* 81 to 97. The if qualifier on columns of the types it supports. Each test
*     loads id and the one column that the expression uses. bigint and
*     numeric(18,0) are tested in 98 and 109 instead, because their columns
*     hold values too large for a double and so stay strings in a full load,
*     which keep if cannot compare with a number.
local i 80
foreach e in ///
	`"xbit == 1"' `"xtinyint > 2"' `"xsmallint < 0"' `"xint >= 3"' ///
	`"xdecimal > 1"' `"xdecimal38 < 0"' `"xnumeric5 < 0"' `"xmoney > 1"' `"xsmallmoney < 0"' ///
	`"xfloat >= 1.5"' `"xreal < 1"' `"xdate < td(01jan1960)"' `"year(xdate) == 2020"' ///
	`"xvarchar == "abc""' `"missing(xvarchar)"' `"xnvarchar > "a""' `"strupper(xnvarchar) == "ABD""' {
	local ++i
	t_reset
	local c
	if ustrregexm(`"`e'"', "x[a-z0-9]+") local c = ustrregexs(0)
	display as text _n `"if `e'"'
	capture noisily t_ifcheck `"`e'"' `"dataset(`fs'.sqldta_test_types) sqlselect(id `c')"'
	t_result types_if_`i' `=_rc'
}

* 98. bigint, which odbc load returns as a string: the column stays a string
*     when a value loaded is too large for a double to hold exactly, and
*     becomes numeric when every value loaded fits
t_reset
capture noisily {
	sqldta, `ftypes' sqlselect(id xbigint) frame(t98a)
	assert "`r(converted)'" == ""
	frame t98a: confirm string variable xbigint
	sqldta if xbigint < 1000, `ftypes' sqlselect(id xbigint) frame(t98b)
	assert "`r(converted)'" == "xbigint"
	assert r(N) == 3
	frame t98b {
		confirm numeric variable xbigint
		sort id
		assert id[1] == 1 & xbigint[1] == 1
		assert id[2] == 4 & xbigint[2] == -9
		assert id[3] == 5 & xbigint[3] == 3
	}
}
t_result types_bigint `=_rc'

* 99. The if qualifier refuses columns of the types it does not support, with
*     error 198, before any frame is created
t_reset
capture noisily {
	foreach c in xtext xntext xuniqueidentifier xbinary xxml xgeography {
		local f `ftypes'
		if inlist("`c'", "xbinary", "xxml", "xgeography") local f `frare'
		display as text "(error 198 is expected here)"
		capture noisily sqldta if !missing(`c'), `f' frame(t99)
		assert _rc == 198
		capture frame create t99
		assert _rc == 0
		frame drop t99
	}
}
t_result types_if_refused `=_rc'

* 100. Labels on columns of several types: value labels on bit and tinyint,
*      one of them from a ValueLabel row without a DataType, a variable label on
*      each column, a date format, the dataset note and the data label. Rows
*      for columns not selected, and the ValueLabel row for the string column
*      xvarchar, are passed over and not counted as skipped. The date format
*      and the data label are in rows of the types Format and DataLabel, the
*      names that sqldta 1.0.0 used, which are read as VariableFormat and
*      DatasetLabel.
t_reset
capture noisily {
	sqldta, `ftypes' sqlselect(id xbit xtinyint xint xvarchar xdate) frame(t100) `alllab'
	assert r(N) == 6
	assert r(n_vallabels) == 2
	assert r(n_varlabels) == 5
	assert r(n_formats) == 1
	assert r(n_varnotes) == 0
	assert r(n_dtanotes) == 1
	assert r(n_skipped) == 0
	frame t100 {
		assert "`: value label xbit'" == "xbit"
		assert "`: label xbit 1'" == "Yes"
		assert "`: label xtinyint 255'" == "largest"
		assert "`: label xtinyint 2'" == "two, with no DataType"
		assert "`: value label xvarchar'" == ""
		assert "`: variable label xvarchar'" == "varchar(50)"
		assert "`: format xdate'" == "%tdCCYY-NN-DD"
		assert `"`: data label'"' == "Fixture table of SQL Server data types"
	}
}
t_result types_labels `=_rc'

* 101. datetime, datetime2 and smalldatetime: %tc with milliseconds; digits
*      below the millisecond are dropped, not rounded; a datetime2 value
*      before 01jan0100 is missing
t_reset
capture noisily {
	sqldta, `ftypes' sqlselect(id xdatetime xdatetime2 xsmalldatetime) frame(t101) `nolab'
	assert "`r(converted)'" == "xdatetime xdatetime2 xsmalldatetime"
	frame t101 {
		sort id
		foreach v in xdatetime xdatetime2 xsmalldatetime {
			confirm double variable `v'
			assert "`: format `v''" == "%tc"
		}
		assert xdatetime[1] == tc(01jan2020 13:45:30.123)
		assert xdatetime2[1] == tc(01jan2020 13:45:30.123)
		assert xsmalldatetime[1] == tc(01jan2020 13:45:00)
		assert xdatetime[2] == tc(01jan1753 00:00:00)
		assert missing(xdatetime2[2])
		assert xsmalldatetime[2] == tc(01jan1900 00:00:00)
		assert missing(xdatetime[3]) & missing(xdatetime2[3]) & missing(xsmalldatetime[3])
		assert xdatetime[4] == tc(31dec9999 23:59:59.997)
		assert xdatetime2[4] == tc(31dec9999 23:59:59.999)
		assert xsmalldatetime[4] == tc(06jun2079 23:59:00)
		assert xdatetime[5] == tc(30jun2019 06:00:00)
	}
}
t_result types_datetime `=_rc'

* 102. time: milliseconds since midnight, with %tcHH:MM:SS.sss
t_reset
capture noisily {
	sqldta, `ftypes' sqlselect(id xtime) frame(t102) `nolab'
	frame t102 {
		sort id
		confirm numeric variable xtime
		assert "`: format xtime'" == "%tcHH:MM:SS.sss"
		assert xtime[1] == 49530123
		assert xtime[2] == 0
		assert missing(xtime[3])
		assert xtime[4] == 86399999
		assert xtime[5] == 21600000
	}
}
t_result types_time `=_rc'

* 103. datetimeoffset: the clock time as stored, without the offset
t_reset
capture noisily {
	sqldta, `ftypes' sqlselect(id xdatetimeoffset) frame(t103) `nolab'
	assert "`r(converted)'" == "xdatetimeoffset"
	frame t103 {
		sort id
		assert "`: format xdatetimeoffset'" == "%tc"
		assert xdatetimeoffset[1] == tc(01jan2020 13:45:30.123)
		assert xdatetimeoffset[2] == tc(30jun2020 23:59:59.999)
		assert missing(xdatetimeoffset[3])
		assert xdatetimeoffset[4] == tc(31dec1959 23:00:00)
		assert xdatetimeoffset[5] == tc(30jun2019 06:00:00)
	}
}
t_result types_datetimeoffset `=_rc'

* 104. uniqueidentifier: the GUID as text of 36 characters
t_reset
capture noisily {
	sqldta, `ftypes' sqlselect(id xuniqueidentifier) frame(t104)
	frame t104 {
		sort id
		assert "`: type xuniqueidentifier'" == "str36"
		assert xuniqueidentifier[1] == "6F9619FF-8B86-D011-B42D-00C04FC964FF"
		assert xuniqueidentifier[2] == "00000000-0000-0000-0000-000000000000"
		assert xuniqueidentifier[3] == ""
		assert xuniqueidentifier[4] == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"
	}
}
t_result types_guid `=_rc'

* 105. char and nchar lose their trailing padding; varchar and nvarchar keep
*      the trailing spaces they were stored with
t_reset
capture noisily {
	sqldta, `ftypes' sqlselect(id xchar xnchar xvarchar xnvarchar) frame(t105)
	frame t105 {
		sort id
		assert xchar[1] == "ab"
		assert xchar[2] == "abcde"
		assert xchar[4] == ""
		assert xchar[5] == "abc"
		assert xnchar[1] == "ab"
		assert xnchar[2] == uchar(256) + uchar(274) + uchar(298) + uchar(332) + uchar(362)
		assert xnchar[5] == "abd"
		assert xvarchar[6] == "ab  "
		assert xnvarchar[6] == "ab  "
	}
}
t_result types_char `=_rc'

* 106. Text outside ASCII arrives as valid UTF-8 from every character type,
*      with unicode(*) for char, varchar and text, which are sent as they are
*      without it (test 180)
t_reset
capture noisily {
	sqldta, `ftypes' sqlselect(id xchar xvarchar xvarcharmax xtext xnchar xnvarchar xnvarcharmax xntext) unicode(*) frame(t106)
	frame t106 {
		sort id
		local e = "caf" + uchar(233)
		assert xvarchar[2] == "`e'"
		assert xchar[6] == "`e'"
		assert xvarcharmax[6] == "`e'"
		assert xtext[6] == "`e'"
		assert xnvarchar[2] == "Z" + uchar(252) + "rich " + uchar(26481) + uchar(20140)
		assert ustrlen(xnvarcharmax[2]) == 3000 & usubstr(xnvarcharmax[2], 1, 1) == uchar(233)
		assert ustrlen(xvarcharmax[5]) == 10000
		assert xntext[2] == "M" + uchar(257) + "ori"
		foreach v of varlist _all {
			if "`v'" == "id" continue
			quietly count if ustrinvalidcnt(`v') > 0
			display as text "  `v': " r(N) " values that are not valid UTF-8"
			assert r(N) == 0
		}
	}
}
t_result types_unicode `=_rc'

* 107. The rarer types arrive as text: hexadecimal for the binary types, and
*      text for xml, sql_variant, hierarchyid, geography and geometry
t_reset
capture noisily {
	sqldta, `frare' frame(t107)
	assert r(k) == 10
	frame t107 {
		sort id
		assert xbinary[1] == "0x01020304"
		assert xvarbinary[1] == "0xDEADBEEF"
		assert ximage[1] == "0x89504E47"
		assert xxml[1] == `"<a b="1">text</a>"'
		assert xsqlvariant[1] == "42"
		assert xhierarchyid[1] == "/1/2/"
		assert xgeography[1] == "POINT (20 10)"
		assert xgeometry[1] == "POINT (1 2)"
		foreach v in xbinary xvarbinary ximage xxml xsqlvariant xhierarchyid xgeography xgeometry {
			assert `v'[2] == ""
		}
		assert ustrregexm(xrowversion[1], "^0x[0-9A-F]{16}$")
		assert ustrregexm(xrowversion[2], "^0x[0-9A-F]{16}$")
		display as text "  xbinary is `: type xbinary', xrowversion is `: type xrowversion'"
		assert "`: type xbinary'" != "strL" & "`: type xrowversion'" != "strL"
	}
}
t_result types_rare `=_rc'

* 108. decimal and numeric of precision 15 or less get %(p+2).(s)f; wider ones
*      and money keep %10.0g; nodecformat, or its abbreviation nodec, turns the
*      formats off. Those wider than 15 digits are sent as text and converted
*      by sqldta, because the legacy driver rounds them to about 15 digits.
t_reset
capture noisily {
	sqldta, `ftypes' sqlselect(id xdecimal xnumeric5 xdecimal15 xdecimal16 xdecimal38 xmoney) frame(t108a) `nolab'
	assert "`r(converted)'" == "xdecimal16 xdecimal38"
	frame t108a {
		sort id
		assert "`: format xdecimal'" == "%11.2f"
		assert "`: format xnumeric5'" == "%7.0f"
		assert "`: format xdecimal15'" == "%17.3f"
		assert "`: format xdecimal16'" == "%10.0g"
		assert "`: format xdecimal38'" == "%10.0g"
		assert "`: format xmoney'" == "%10.0g"
		assert strtrim(string(xdecimal15[1], "%17.3f")) == "123456789012.345"
		assert xnumeric5[2] == 99999
		assert xdecimal16[2] == real("99999999999999.99")
	}
	sqldta, `ftypes' sqlselect(id xdecimal xnumeric5 xdecimal15) nodecformat frame(t108b) `nolab'
	frame t108b {
		foreach v in xdecimal xnumeric5 xdecimal15 {
			assert "`: format `v''" == "%10.0g"
		}
	}
	sqldta, `ftypes' sqlselect(id xdecimal) nodec frame(t108c) `nolab'
	frame t108c {
		assert "`: format xdecimal'" == "%10.0g"
	}
}
t_result types_decformat `=_rc'

* 109. numeric(18,0) is treated as bigint: it stays a string when a value
*      loaded is too large for a double to hold exactly, and becomes numeric
*      when every value loaded fits
t_reset
capture noisily {
	sqldta, `ftypes' sqlselect(id xnumeric) frame(t109a)
	assert "`r(converted)'" == ""
	frame t109a {
		confirm string variable xnumeric
		sort id
		assert xnumeric[2] == "123456789012345678"
	}
	sqldta if xnumeric < 1000, `ftypes' sqlselect(id xnumeric) frame(t109b)
	assert "`r(converted)'" == "xnumeric"
	assert r(N) == 3
	frame t109b {
		confirm numeric variable xnumeric
		sort id
		assert id[1] == 1 & xnumeric[1] == 1
		assert id[2] == 4 & xnumeric[2] == 0
		assert id[3] == 5 & xnumeric[3] == 3
	}
}
t_result types_widenumeric `=_rc'

* 110. A column sent as an expression keeps the name typed in sqlselect(),
*      and lowercase still applies. A date-time column is sent as a number of
*      milliseconds, computed without converting the value to text (a datetime
*      from its stored ticks, the other types with DATEDIFF), a varchar column
*      as it is, under the name typed, and as Unicode when unicode() names it.
t_reset
capture noisily {
	sqldta, `ftypes' sqlselect(id XDATETIME XTIME XVARCHAR) frame(t110a) `nolab'
	display as text `"  SQL: `r(sql)'"'
	assert strpos(`"`r(sql)'"', "(CAST(SUBSTRING(CAST([xdatetime] AS binary(8)), 5, 4) AS int) * 10 + 1) / 3 AS [XDATETIME]") > 0
	assert !strpos(`"`r(sql)'"', "varchar(23)")
	assert strpos(`"`r(sql)'"', "[xvarchar] AS [XVARCHAR]") > 0
	assert !strpos(`"`r(sql)'"', "CONVERT(nvarchar")
	assert "`r(converted)'" == "XDATETIME"
	sqldta, `ftypes' sqlselect(id XVARCHAR) unicode(xvarchar) frame(t110u) `nolab'
	assert strpos(`"`r(sql)'"', "CONVERT(nvarchar(50), [xvarchar]) AS [XVARCHAR]") > 0
	assert "`r(unicode)'" == "XVARCHAR"
	sqldta, `ftypes' sqlselect(id xdatetime2 xsmalldatetime xdatetimeoffset) frame(t110d) `nolab'
	display as text `"  SQL: `r(sql)'"'
	assert strpos(`"`r(sql)'"', "DATEDIFF(millisecond, CAST(CAST([xdatetime2] AS date) AS datetime2(7)), [xdatetime2])") > 0
	assert strpos(`"`r(sql)'"', "DATEDIFF(millisecond, CAST(CAST(CAST([xsmalldatetime] AS datetime2(7)) AS date) AS datetime2(7)), CAST([xsmalldatetime] AS datetime2(7)))") > 0
	assert strpos(`"`r(sql)'"', "CASE WHEN CAST([xdatetimeoffset] AS datetime2(7)) >= CAST(N'0100-01-01' AS datetime2) THEN") > 0
	assert !strpos(`"`r(sql)'"', "varchar(23)")
	assert "`r(converted)'" == "xdatetime2 xsmalldatetime xdatetimeoffset"
	frame t110a {
		confirm variable XDATETIME XTIME XVARCHAR, exact
		assert "`: format XDATETIME'" == "%tc"
		assert "`: format XTIME'" == "%tcHH:MM:SS.sss"
	}
	sqldta, `ftypes' sqlselect(id XDATETIME XTIME) lowercase frame(t110b) `nolab'
	frame t110b {
		confirm variable xdatetime xtime, exact
		assert "`: format xdatetime'" == "%tc"
		assert "`: format xtime'" == "%tcHH:MM:SS.sss"
	}
}
t_result types_select_alias `=_rc'

* 111. Whole tables: every column arrives, and the label rows of the types
*      table are all applied; its VariableFormat row for xdatetime replaces %tc
t_reset
capture noisily {
	sqldta, `ftypes' frame(t111a) `alllab'
	local got `=r(N)' `=r(k)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "types: `got' (expected: 6 31 2 30 2 1 1 0)"
	assert "`got'" == "6 31 2 30 2 1 1 0"
	frame t111a {
		foreach v in xdatetime2 xsmalldatetime xdatetimeoffset xtime {
			assert substr("`: format `v''", 1, 3) == "%tc"
		}
		assert "`: format xdatetime'" == "%tcCCYY-NN-DD_HH:MM:SS.sss"
	}
	sqldta, `frare' frame(t111b) labels(variables)
	assert r(N) == 2 & r(k) == 10 & r(n_varlabels) == 9 & r(n_skipped) == 0
	sqldta, `fdt' frame(t111c) labels(variables)
	assert r(N) == 12 & r(k) == 10 & r(n_varlabels) == 9 & r(n_skipped) == 0
}
t_result types_whole `=_rc'

* 112. The fixture tables of data types give the same values through the
*      connection template and through the DSN, whose driver may be another
*      (the legacy "SQL Server" driver in the maintainer's runs)
t_reset
capture noisily {
	local bad
	foreach d in types rare dt {
		global SQLDTA_CONNECTION `"$TEST_CONNECTION"'
		sqldta, `fsrc' dataset(`fs'.sqldta_test_`d') frame(t112a)
		global SQLDTA_CONNECTION
		sqldta, `fsrc' dataset(`fs'.sqldta_test_`d') frame(t112b)
		display as text "sqldta_test_`d', template and DSN:"
		t_samedata t112a t112b
		if "`r(bad)'" != "" local bad `bad' `d':`r(bad)'
		frame drop t112a
		frame drop t112b
	}
	display as text "values that differ: `bad'"
	assert "`bad'" == ""
}
t_result types_drivers `=_rc'

* 113 to 151. The if qualifier on date-time and time columns, in the fixture
*      table sqldta_test_dt: each expression must load the rows that keep if
*      leaves after a full load, whose values are whole milliseconds. The
*      expressions are kept in the local dtexprs for test 189.
local dtexprs
foreach e in ///
	`"xdatetime2 == tc(01jan2020 13:45:30.123)"' `"xdatetime2 != tc(01jan2020 13:45:30.123)"' ///
	`"xdatetime2 < tc(01jan2020 13:45:30.123)"' `"xdatetime2 <= tc(01jan2020 13:45:30.123)"' ///
	`"xdatetime2 > tc(01jan2020 13:45:30.123)"' `"xdatetime2 >= tc(01jan2020 13:45:30.123)"' ///
	`"xdatetime == tc(01jan2020 13:45:30.007)"' `"xdatetime == tc(01jan2020 13:45:30.005)"' ///
	`"xdatetime > tc(01jan2020 13:45:30.005)"' `"xdatetime <= tc(01jan2020 13:45:30.123)"' ///
	`"xdatetime != tc(01jan2020 13:45:30.127)"' `"xdatetime < tc(01jan1700 00:00)"' ///
	`"xdatetime2_3 > tc(01jan2020 13:45:30.122)"' `"xdatetime2_0 <= tc(01jan2020 13:45:30.500)"' ///
	`"xsmalldatetime >= tc(01jan2020 13:45:30)"' `"xsmalldatetime < tc(01jan1800 00:00)"' ///
	`"xdatetimeoffset < tc(01jan2020 10:00)"' `"xdatetimeoffset == tc(01jan2020 13:45:30.123)"' ///
	`"xdatetime2 > 0"' `"xdatetime2"' `"!xdatetime"' ///
	`"missing(xdatetime2)"' `"!missing(xdatetime2_3)"' `"xdatetime2 == ."' ///
	`"inrange(xdatetime, tc(01jan2020 00:00), tc(01jan2020 23:59:59.999))"' ///
	`"inlist(xdatetime2_3, tc(01jan2020 13:45:30.123), tc(01jan2020 13:45:30.124))"' ///
	`"dofc(xdatetime2) == td(01jan2020)"' `"year(dofc(xdatetime)) == 2019"' ///
	`"dofc(xdatetimeoffset) < td(01jan2020)"' `"xdatetime < xdatetime2"' ///
	`"xtime >= 49530123"' `"xtime == 0"' `"xtime0 < xtime"' `"xtime > 86399998"' ///
	`"xtime >= tc(13:45:30.123)"' ///
	`"(xdatetime2 > tc(01jan2020 00:00) & xdatetime2 < tc(02jan2020 00:00)) | missing(xtime)"' ///
	`"xdatetime2 <= tc(31dec9999 23:59:59.999)"' `"xdatetime2 < tc(31dec9999 23:59:59.999)"' ///
	`"xdatetimeoffset > xdatetime2_0"' {
	local dtexprs `"`dtexprs' `"`e'"'"'
}
local i 112
foreach e of local dtexprs {
	local ++i
	t_reset
	display as text _n `"if `e'"'
	capture noisily t_ifcheck `"`e'"' "dataset(`fs'.sqldta_test_dt)"
	t_result dt_if_`i' `=_rc'
}

* 152. The if qualifier refuses, with error 198, a date compared with a
*      date-time, year() and dofc() where they do not apply, tC(), and a time
*      compared with a date-time
t_reset
capture noisily {
	foreach e in `"xdatetime > td(01jan2020)"' `"year(xdatetime) == 2020"' ///
		`"xdate > tc(01jan2020 00:00)"' `"xdate < xdatetime"' `"xdatetime > tC(01jan2020 00:00)"' ///
		`"xtime < xdatetime"' `"dofc(xtime) == td(01jan1960)"' ///
		`"inrange(xdatetime, td(01jan2020), td(31dec2020))"' {
		display as text `"(error 198 is expected here) if `e'"'
		capture noisily sqldta if `e', `fdt' frame(t152)
		assert _rc == 198
		capture frame create t152
		assert _rc == 0
		frame drop t152
	}
}
t_result dt_if_refused `=_rc'

* ---------------------------------------------------------------------------
* labels(), names given as schema.table, and the removed options
* ---------------------------------------------------------------------------

* 153. Without labels(), every label type is applied, as with labels(all)
t_reset
capture noisily {
	sqldta, `fmain' frame(t153a)
	local a `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	assert "`r(labels)'" == "values variables formats varnotes dtanotes datalabel"
	sqldta, `fmain' frame(t153b) labels(all)
	local b `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	assert "`r(labels)'" == "values variables formats varnotes dtanotes datalabel"
	display as text "default: `a'; labels(all): `b' (expected: applied 0 1 2 7 2 1)"
	assert "`a'" == "`b'"
	assert "`a'" == "applied 0 1 2 7 2 1"
	frame t153a {
		assert `"`: data label'"' == "Fixture main table"
	}
}
t_result labels_default `=_rc'

* 154. Each label type on its own applies only its own rows: formats (the row
*      with a format that is not valid is skipped), variables, varnotes,
*      dtanotes and datalabel. Without datalabel the data label is the source.
t_reset
capture noisily {
	local source $TEST_FIXDATABASE.`fs'.sqldta_test_main
	sqldta, `fmain' frame(t154a) labels(formats)
	local got `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "formats: `got' (expected: 0 0 2 0 0 1)"
	assert "`got'" == "0 0 2 0 0 1"
	frame t154a {
		assert "`: format amount'" == "%9.2fc"
		assert `"`: variable label extra1'"' == ""
		assert `"`: data label'"' == "`source'"
	}
	sqldta, `fmain' frame(t154b) labels(variables)
	local got `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "variables: `got' (expected: 0 1 0 0 0 0)"
	assert "`got'" == "0 1 0 0 0 0"
	frame t154b {
		assert "`: format amount'" == "%11.2f"
		assert `"`: variable label extra1'"' == "Extra one, labelled under the linked table"
	}
	sqldta, `fmain' frame(t154c) labels(varnotes)
	local got `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "varnotes: `got' (expected: 0 0 0 7 0 0)"
	assert "`got'" == "0 0 0 7 0 0"
	sqldta, `fmain' frame(t154d) labels(dtanotes)
	local got `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "dtanotes: `got' (expected: 0 0 0 0 2 0)"
	assert "`got'" == "0 0 0 0 2 0"
	frame t154d {
		assert `"`: data label'"' == "`source'"
	}
	sqldta, `fmain' frame(t154e) labels(datalabel)
	local got `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "datalabel: `got' (expected: 0 0 0 0 0 0)"
	assert "`got'" == "0 0 0 0 0 0"
	frame t154e {
		assert `"`: data label'"' == "Fixture main table"
		t_nnotes _dta
		assert r(n) == 0
	}
}
t_result labels_each `=_rc'

* 155. labels() accepts the keywords in any case and order, and repeated;
*      r(labels) lists them once, in a fixed order
t_reset
capture noisily {
	sqldta, `fmain' frame(t155) labels(Formats VALUES formats)
	assert "`r(labels)'" == "values formats"
	assert r(n_formats) == 2 & r(n_varnotes) == 0
}
t_result labels_case `=_rc'

* 156. labels() with a word that is not a label type, or with all or none
*      combined with others: error 198, and no frame created
t_reset
capture noisily {
	foreach l in "foo" "all values" "none formats" "values labels" {
		display as text "(error 198 is expected here) labels(`l')"
		capture noisily sqldta, `fmain' frame(t156) labels(`l')
		assert _rc == 198
		capture frame create t156
		assert _rc == 0
		frame drop t156
	}
}
t_result labels_invalid `=_rc'

* 157. The options of the earlier syntax, and names that are not table or
*      schema.table, stop with error 198 before any frame is created
t_reset
capture noisily {
	foreach o in "dataschema(dbo)" "labelschema(ref)" "multischema(multi)" ///
		"vallabels" "varlabels" "varnotes" "dtanotes" {
		display as text "(error 198 is expected here) `o'"
		capture noisily sqldta, `src' frame(t157) `o'
		assert _rc == 198
	}
	display as text "(error 198 is expected here) a three-part name"
	capture noisily sqldta, server("$TEST_SERVER") database("$TEST_DATABASE") ///
		dataset("$TEST_DATABASE.$TEST_SCHEMA.$TEST_TABLE") frame(t157)
	assert _rc == 198
	display as text "(error 198 is expected here) an empty schema"
	capture noisily sqldta, server("$TEST_SERVER") database("$TEST_DATABASE") ///
		dataset(".$TEST_TABLE") frame(t157)
	assert _rc == 198
	display as text "(error 198 is expected here) a three-part label table"
	capture noisily sqldta, `src' labeltable(a.b.c) frame(t157)
	assert _rc == 198
	global SQLDTA_LABELTABLE "a.b.c"
	display as text "(error 198 is expected here) a three-part SQLDTA_LABELTABLE"
	capture noisily sqldta, `src' frame(t157)
	assert _rc == 198
	capture frame create t157
	assert _rc == 0
}
t_result names_invalid `=_rc'

* 158. Names without a schema: a table is in dbo when $SQLDTA_DATASCHEMA is
*      not set (dbo.sqldta_test_dflt), and a label table named without a
*      schema is in ref when $SQLDTA_LABELTABLE is not set
*      (ref.DataProperties, the view of the fixture label table)
t_reset
capture noisily {
	sqldta, `fmain' frame(t158a) labels(none)
	assert "`r(table)'" == "$TEST_FIXDATABASE.`fs'.sqldta_test_main"
	sqldta, `fdb' dataset(sqldta_test_dflt) frame(t158b) labels(none)
	assert "`r(table)'" == "$TEST_FIXDATABASE.dbo.sqldta_test_dflt"
	assert r(N) == 2
	sqldta, `fknown' labeltable("$TEST_LABELTABLE") frame(t158c) labels(values)
	assert "`r(labelstatus)'" == "applied" & r(n_vallabels) == 1
}
t_result names_default_schema `=_rc'

* 159. A view loads like a table, with its own DatasetLabel and DatasetNote rows
t_reset
capture noisily {
	sqldta, `fsrc' dataset(`fs'.sqldta_test_view) frame(t159)
	assert r(N) == 8 & r(k) == 3 & r(n_dtanotes) == 2
	frame t159 {
		confirm variable id num grp, exact
		assert `"`: data label'"' == `"View of the "main" fixture table"'
	}
}
t_result view_load `=_rc'

* ---------------------------------------------------------------------------
* The dialog helper, sqldta_dlg. Its query subcommands return the lists and
* the description that the dialog shows, without a dialog.
* ---------------------------------------------------------------------------

* 160. Databases from the server: the test database is listed, and master,
*      tempdb, model and msdb are not. The list is checked, not shown, since
*      it names the server's other databases.
t_reset
capture noisily {
	sqldta_dlg query databases, server("$TEST_SERVER")
	local list `"`r(list)'"'
	display as text "  databases listed: " `: word count `list''
	assert r(rc) == 0
	assert `: list posof "$TEST_FIXDATABASE" in list' > 0
	foreach d in master tempdb model msdb {
		assert !`: list d in list'
	}
}
t_result dlg_databases `=_rc'

* 161. Databases from $SQLDTA_DATABASES, without contacting the server
t_reset
capture noisily {
	global SQLDTA_DATABASES "DbOne DbTwo"
	sqldta_dlg query databases, server(sqldta_no_such_server)
	assert r(rc) == 0
	assert `"`r(list)'"' == "DbOne DbTwo"
}
t_result dlg_databases_global `=_rc'

* 162. Schemas that hold tables or views, in the test database
t_reset
capture noisily {
	sqldta_dlg query schemas, server("$TEST_SERVER") database("$TEST_FIXDATABASE")
	local list `"`r(list)'"'
	display as text `"  schemas of $TEST_FIXDATABASE: `list'"'
	assert r(rc) == 0
	foreach s in `fs' sqldta_alt ref dbo {
		assert `: list posof "`s'" in list' > 0
	}
	assert !`: list posof "INFORMATION_SCHEMA" in list'
}
t_result dlg_schemas `=_rc'

* 163. Tables and views of a schema
t_reset
capture noisily {
	sqldta_dlg query tables, server("$TEST_SERVER") database("$TEST_FIXDATABASE") schema(`fs')
	local list `"`r(list)'"'
	display as text `"  tables in `fs': `list'"'
	assert r(rc) == 0
	foreach t in sqldta_test_main sqldta_test_view sqldta_test_known sqldta_test_types $TEST_FIXTABLE {
		assert `: list posof "`t'" in list' > 0
	}
	sqldta_dlg query tables, server("$TEST_SERVER") database("$TEST_FIXDATABASE") schema(ref)
	local list `"`r(list)'"'
	display as text `"  tables in ref: `list'"'
	assert r(rc) == 0
	foreach t in DataProperties sqldta_test_part sqldta_test_samex {
		assert `: list posof "`t'" in list' > 0
	}
}
t_result dlg_tables `=_rc'

* 164. The description of a split table: the columns a load gives, the links,
*      the data label, the dataset notes in order, the DatasetDescription
*      paragraph of PropertyCode 1, the number of rows, and the text the
*      dialog shows, with the data label and that paragraph but not the
*      notes; no frame is left behind
t_reset
capture noisily {
	quietly frames dir
	local before `r(frames)'
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_main) `fix'
	assert r(rc) == 0
	display as text "  columns: `r(columns)'"
	assert "`r(columns)'" == "id num amount grp dob Order shared extra1 extra2 extra3 stamp"
	assert "`r(links)'" == "ref.sqldta_test_part `fs'.sqldta_test_part2"
	assert strpos(`"`r(dropped)'"', "bad name") > 0
	assert "`r(labelstatus)'" == "applied"
	assert `"`r(datalabel)'"' == "Fixture main table"
	assert r(n_notes) == 2
	assert `"`r(note1)'"' == "First dataset note"
	assert `"`r(note2)'"' == "Second dataset note"
	assert r(rows) == 8
	mata: t_D = "First paragraph of the description, with " + char(34) + "double quotes" + char(34) + ", a " + char(96) + "backquote" + char(39) + " and " + char(36) + "HOME"
	mata: st_numscalar("t_ok", st_global("r(description)") == t_D)
	assert scalar(t_ok) == 1
	mata: printf("{txt}  text: %s\n", st_global("r(text)"))
	mata: st_numscalar("t_ok", st_global("r(text)") == "About 8 rows; 11 columns can be loaded. Linked tables: ref.sqldta_test_part, `fs'.sqldta_test_part2. Fixture main table. " + t_D + ". Columns left out: bad name, ref.sqldta_test_part.shared.")
	assert scalar(t_ok) == 1
	quietly frames dir
	local after `r(frames)'
	assert `: list after === before'
}
t_result dlg_describe `=_rc'

* 165. The description of a view: no number of rows, and the text of its
*      DatasetLabel and DatasetNote rows exactly, with double quotes, a
*      backquote and a dollar sign; the text the dialog shows has the data
*      label, and says that no dataset description is available, since the
*      view has no DatasetDescription row
t_reset
capture noisily {
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_view) `fix'
	assert r(rc) == 0
	assert "`r(columns)'" == "id num grp"
	assert missing(r(rows))
	assert r(n_notes) == 2
	mata: st_numscalar("t_ok", st_global("r(datalabel)") == "View of the " + char(34) + "main" + char(34) + " fixture table")
	assert scalar(t_ok) == 1
	mata: st_numscalar("t_ok", st_global("r(note1)") == "First note on the view, with " + char(34) + "double quotes" + char(34) + ", a " + char(96) + "backquote" + char(39) + " and " + char(36) + "HOME")
	assert scalar(t_ok) == 1
	assert `"`r(note2)'"' == "Second note on the view"
	mata: st_numscalar("t_ok", st_global("r(text)") == "A view, so the number of rows is not known; 3 columns can be loaded. View of the " + char(34) + "main" + char(34) + " fixture table. No dataset description available.")
	assert scalar(t_ok) == 1
}
t_result dlg_describe_view `=_rc'

* 166. The description with a label table that does not exist: no data label
*      or notes, and the columns are still listed
t_reset
capture noisily {
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_view) labeltable("`fs'.sqldta_no_such_table")
	assert r(rc) == 0
	assert "`r(labelstatus)'" == "notfound"
	assert `"`r(datalabel)'"' == "" & r(n_notes) == 0
	assert "`r(columns)'" == "id num grp"
	assert `"`r(text)'"' == "A view, so the number of rows is not known; 3 columns can be loaded. The label table was not found, so there is no description."
}
t_result dlg_describe_nolabels `=_rc'

* 167. Queries that fail return r(rc) other than 0 and nothing else, without
*      stopping: a database and a table that do not exist
t_reset
capture noisily {
	display as text "(a query failure is expected here)"
	sqldta_dlg query schemas, server("$TEST_SERVER") database(sqldta_no_such_database)
	assert r(rc) != 0 & `"`r(list)'"' == ""
	display as text "(a failure is expected here)"
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_no_such_table) `fix'
	assert r(rc) != 0 & "`r(columns)'" == ""
}
t_result dlg_failures `=_rc'

* 168. clear replaces the data in a frame that holds data, given as frame()
*      and as the current frame, for the wide fixture table, whose query is
*      long with unicode(*), and for the types table, which has strL columns.
*      odbc load's own clear did not empty such a frame for some tables
*      (r(18), 19 Oct 2026).
t_reset
capture noisily {
	frame create t168
	frame t168 {
		quietly set obs 3
		generate x = 1
	}
	sqldta, `fsrc' dataset(`fs'.sqldta_test_wide) unicode(*) frame(t168) clear labels(none)
	display as text "  query of " strlen(`"`r(sql)'"') " characters"
	assert strlen(`"`r(sql)'"') > 40000
	assert r(N) == 2 & r(k) == 1001
	sqldta, `fsrc' dataset(`fs'.sqldta_test_wide) unicode(*) frame(t168) clear labels(none)
	assert r(N) == 2 & r(k) == 1001
	frame t168 {
		sort id
		assert c0001[1] == "a" & c1000[1] == "z"
		assert c0001[2] == "b" & c1000[2] == ""
	}
	sqldta, `ftypes' frame(t168) clear labels(none)
	assert r(N) == 6 & r(k) == 31
	frame change t168
	sqldta, `fsrc' dataset(`fs'.sqldta_test_wide) unicode(*) clear labels(none)
	assert "`r(frame)'" == "t168" & r(N) == 2 & r(k) == 1001
	sqldta, `ftypes' clear labels(none)
	assert "`r(frame)'" == "t168" & r(N) == 6 & r(k) == 31
	frame change default
}
t_result clear_replaces_wide `=_rc'

* 169. bit, for which Stata has no Boolean or logical type, arrives as a
*      numeric variable holding 0 and 1, with NULL as missing, through the
*      connection template and through the DSN. sqldta sends the column as it
*      is, not as an expression, and does not convert it. The type report
*      shows the storage type, byte in the logs of 18 and 19 Oct 2026.
t_reset
capture noisily {
	foreach how in template dsn {
		if "`how'" == "dsn" global SQLDTA_CONNECTION
		sqldta, `ftypes' sqlselect(id xbit) frame(t169`how') `nolab'
		assert strpos(`"`r(sql)'"', "SELECT [id], [xbit] FROM ") == 1
		local converted `r(converted)'
		assert !`: list posof "xbit" in converted'
		frame t169`how' {
			sort id
			confirm numeric variable xbit, exact
			display as text "  `how': xbit is `: type xbit' `: format xbit'"
			assert _N == 6
			assert xbit[1] == 1 & xbit[2] == 0 & missing(xbit[3])
			assert xbit[4] == 0 & xbit[5] == 1 & missing(xbit[6])
		}
	}
}
t_result bit_values `=_rc'

* 170 to 179. The if qualifier on a bit column, each expression compared with
*     a full load followed by keep if. A missing bit, from NULL, is greater
*     than 1 and is not equal to 0 or 1, as in Stata; a number that is not 0
*     or 1 matches no row.
local i 169
foreach e in ///
	`"xbit == 0"' `"xbit != 1"' `"!(xbit == 1)"' `"xbit > 0"' `"xbit < 0.5"' ///
	`"missing(xbit)"' `"!missing(xbit)"' `"inlist(xbit, 0)"' `"inrange(xbit, 0, 1)"' ///
	`"xbit == 2"' {
	local ++i
	t_reset
	display as text _n `"if `e'"'
	capture noisily t_ifcheck `"`e'"' `"dataset(`fs'.sqldta_test_types) sqlselect(id xbit)"'
	t_result bit_if_`i' `=_rc'
}

* ---------------------------------------------------------------------------
* Text columns, date-times and the label step (archive HANDOVER.md, 4.12)
* ---------------------------------------------------------------------------

local fumain `fsrc' dataset(`fs'.sqldta_test_umain)
local flbl   `fsrc' dataset(`fs'.sqldta_test_lbl)

* 180. By default char, varchar and text are sent as they are, as odbc load
*      reads them: text outside ASCII arrives as the bytes of the column's code page,
*      which are not valid UTF-8, through the template and through the DSN.
*      ASCII text is unchanged, char loses its padding, varchar keeps its
*      trailing spaces, and nvarchar is unaffected. The help file's one-line
*      fix with ustrfrom() gives the text that unicode() loads.
t_reset
capture noisily {
	local e = "caf" + uchar(233)
	foreach how in template dsn {
		if "`how'" == "dsn" global SQLDTA_CONNECTION
		sqldta, `ftypes' sqlselect(id xchar xvarchar xvarcharmax xtext xnvarchar) frame(t180`how') `nolab'
		display as text `"  SQL: `r(sql)'"'
		assert "`r(unicode)'" == ""
		assert !strpos(`"`r(sql)'"', "CONVERT(nvarchar")
		assert strpos(`"`r(sql)'"', "RTRIM([xchar]) AS [xchar]") > 0
		frame t180`how' {
			sort id
			assert xchar[1] == "ab" & xchar[2] == "abcde"
			assert xvarchar[6] == "ab  "
			assert xnvarchar[2] == "Z" + uchar(252) + "rich " + uchar(26481) + uchar(20140)
			foreach v in xchar xvarchar xvarcharmax xtext {
				quietly count if ustrinvalidcnt(`v') > 0
				display as text "  `how', `v': " r(N) " values not valid UTF-8 as loaded"
				assert r(N) == 1
				quietly replace `v' = ustrfrom(`v', "windows-1252", 1) if ustrinvalidcnt(`v') > 0
			}
			assert xvarchar[2] == "`e'" & xchar[6] == "`e'"
			assert xvarcharmax[6] == "`e'" & xtext[6] == "`e'"
		}
	}
}
t_result unicode_default `=_rc'

* 181. unicode() with one column: that column is sent as Unicode and arrives
*      as valid UTF-8, and the others are sent as they are
t_reset
capture noisily {
	local e = "caf" + uchar(233)
	sqldta, `ftypes' sqlselect(id xchar xvarchar xvarcharmax xtext) unicode(xvarchar) frame(t181) `nolab'
	assert "`r(unicode)'" == "xvarchar"
	assert strpos(`"`r(sql)'"', "CONVERT(nvarchar(50), [xvarchar]) AS [xvarchar]") > 0
	frame t181 {
		sort id
		assert xvarchar[2] == "`e'"
		quietly count if ustrinvalidcnt(xvarchar) > 0
		assert r(N) == 0
		foreach v in xchar xvarcharmax xtext {
			quietly count if ustrinvalidcnt(`v') > 0
			assert r(N) == 1
		}
	}
}
t_result unicode_named `=_rc'

* 182. unicode() with wildcards, matched without regard to case
t_reset
capture noisily {
	sqldta, `ftypes' sqlselect(id xchar xvarchar xvarcharmax xtext) unicode(XVAR*) frame(t182a) `nolab'
	assert "`r(unicode)'" == "xvarchar xvarcharmax"
	frame t182a {
		foreach v in xvarchar xvarcharmax {
			quietly count if ustrinvalidcnt(`v') > 0
			assert r(N) == 0
		}
		foreach v in xchar xtext {
			quietly count if ustrinvalidcnt(`v') > 0
			assert r(N) == 1
		}
	}
	sqldta, `ftypes' sqlselect(id xchar xvarchar xvarcharmax xtext) unicode(x?ext) frame(t182b) `nolab'
	assert "`r(unicode)'" == "xtext"
}
t_result unicode_wildcards `=_rc'

* 183. unicode(*) converts every char, varchar and text column loaded, and
*      lists no other column
t_reset
capture noisily {
	local e = "caf" + uchar(233)
	sqldta, `ftypes' sqlselect(id xint xchar xvarchar xvarcharmax xtext xnvarchar) unicode(*) frame(t183) `nolab'
	assert "`r(unicode)'" == "xchar xvarchar xvarcharmax xtext"
	frame t183 {
		sort id
		assert xchar[1] == "ab" & xchar[6] == "`e'" & xvarchar[2] == "`e'"
		foreach v in xchar xvarchar xvarcharmax xtext xnvarchar {
			quietly count if ustrinvalidcnt(`v') > 0
			assert r(N) == 0
		}
	}
}
t_result unicode_all `=_rc'

* 184. unicode(): a name or a wildcard that matches no column stops with
*      error 111 and leaves no frame; columns that are not char, varchar or
*      text may be named and are sent as before; commas separate names, as in
*      sqlselect(); uni is the shortest abbreviation
t_reset
capture noisily {
	capture sqldta, `ftypes' unicode(nosuch) frame(t184a) `nolab'
	assert _rc == 111
	capture sqldta, `ftypes' unicode(zz*) frame(t184a) `nolab'
	assert _rc == 111
	capture frame create t184a
	assert _rc == 0
	frame drop t184a
	sqldta, `ftypes' sqlselect(id xint xnvarchar xvarchar) unicode(xint, XNVARCHAR, xvarchar) frame(t184b) `nolab'
	assert "`r(unicode)'" == "xvarchar"
	local sql `"`r(sql)'"'
	local nconv = (strlen(`"`sql'"') - strlen(subinstr(`"`sql'"', "CONVERT(nvarchar", "", .))) / strlen("CONVERT(nvarchar")
	assert `nconv' == 1
	sqldta, `ftypes' sqlselect(id xvarchar) uni(xvarchar) frame(t184c) `nolab'
	assert "`r(unicode)'" == "xvarchar"
}
t_result unicode_names `=_rc'

* 185. unicode() on the columns of a main table and of a table linked to it
*      by a Link row: without it, text outside ASCII arrives as bytes in both;
*      with the columns named, or with unicode(*), it arrives as valid UTF-8,
*      and a char column of the linked table is still trimmed
t_reset
capture noisily {
	local e = "caf" + uchar(233)
	sqldta, `fumain' frame(t185a) `nolab'
	assert "`r(links)'" == "`fs'.sqldta_test_upart"
	assert r(k) == 5
	assert "`r(unicode)'" == ""
	frame t185a {
		sort id
		assert uchar[1] == "x" & uplain[2] == "two"
		foreach v in utext ulinked uchar {
			quietly count if ustrinvalidcnt(`v') > 0
			assert r(N) == 1
		}
	}
	foreach u in "utext ulinked uchar" "*" {
		* unicode(*) also takes uplain, a varchar column of the main table
		local want = cond("`u'" == "*", "utext uplain ulinked uchar", "`u'")
		capture frame drop t185b
		sqldta, `fumain' unicode(`u') frame(t185b) `nolab'
		display as text "  unicode(`u'): r(unicode) `r(unicode)'"
		assert "`r(unicode)'" == "`want'"
		frame t185b {
			sort id
			assert utext[2] == "`e'"
			assert ulinked[1] == "na" + uchar(239) + "ve"
			assert uchar[2] == uchar(233) + "t" + uchar(233) & uchar[1] == "x"
			foreach v in utext uplain ulinked uchar {
				quietly count if ustrinvalidcnt(`v') > 0
				assert r(N) == 0
			}
		}
	}
}
t_result unicode_links `=_rc'

* 186. The if qualifier and sqlwhere() select the same rows with and without
*      unicode(), on columns of the main and of the linked table. With the
*      column in unicode(), an if on text outside ASCII loads the rows that
*      keep if leaves; without it, the if qualifier still selects the rows
*      whose stored text matches, which keep if on the bytes loaded would not
*      (documented in the help file).
t_reset
capture noisily {
	local e = "caf" + uchar(233)
	local k 0
	foreach u in "" "unicode(*)" {
		local ++k
		sqldta if uplain == "two", `fumain' `u' frame(t186a`k') `nolab'
		assert r(N) == 1
		frame t186a`k': assert id[1] == 2
		sqldta if utext == "abc", `fumain' `u' frame(t186b`k') `nolab'
		assert r(N) == 1
		frame t186b`k': assert id[1] == 1
		sqldta, `fumain' `u' sqlwhere(utext = 'abc') frame(t186c`k') `nolab'
		assert r(N) == 1
		frame t186c`k': assert id[1] == 1
		sqldta if ulinked == "plain", `fumain' `u' frame(t186d`k') `nolab'
		assert r(N) == 1
		frame t186d`k': assert id[1] == 2
	}
	t_ifcheck `"utext == "`e'""' `"dataset(`fs'.sqldta_test_umain) unicode(*)"'
	sqldta if utext == "`e'", `fumain' frame(t186z) `nolab'
	assert r(N) == 1
	frame t186z: assert id[1] == 2
}
t_result unicode_if `=_rc'

* 187. Date-times sent as numbers give exactly the values of the earlier
*      method, text converted with clock(), which the site global
*      SQLDTA_DTTEXT selects: every row and column of the date-time fixture
*      table, of the types table and of the main table (whose linked table has
*      a datetime column), through the template and through the DSN.
*      r(converted) is the same under both.
t_reset
capture noisily {
	local bad
	foreach how in template dsn {
		foreach d in dt types main {
			t_reset
			if "`how'" == "dsn" global SQLDTA_CONNECTION
			sqldta, `fsrc' dataset(`fs'.sqldta_test_`d') frame(t187n) `nolab'
			assert "`r(datetimes)'" == "number"
			local cn `r(converted)'
			global SQLDTA_DTTEXT 1
			sqldta, `fsrc' dataset(`fs'.sqldta_test_`d') frame(t187t) `nolab'
			assert "`r(datetimes)'" == "text"
			assert "`r(converted)'" == "`cn'"
			global SQLDTA_DTTEXT
			display as text "  `how', sqldta_test_`d': converted `cn'"
			t_samedata t187n t187t
			if "`r(bad)'" != "" local bad `bad' `how':`d':`r(bad)'
		}
	}
	display as text "  differences: `bad'"
	assert "`bad'" == ""
}
t_result dt_number_equals_text `=_rc'

* 188. r(datetimes) and the query under each method: SQLDTA_DTTEXT empty or 0
*      sends numbers, anything else sends text
t_reset
capture noisily {
	foreach x in "" "0" "1" "yes" {
		global SQLDTA_DTTEXT `x'
		capture frame drop t188
		sqldta, `ftypes' sqlselect(id xdatetime) frame(t188) `nolab'
		local want = cond(inlist("`x'", "", "0"), "number", "text")
		display as text `"  SQLDTA_DTTEXT "`x'": `r(datetimes)'"'
		assert "`r(datetimes)'" == "`want'"
		if "`want'" == "number" {
			assert strpos(`"`r(sql)'"', "AS float) * 86400000") > 0
		}
		else {
			assert strpos(`"`r(sql)'"', "CONVERT(varchar(23), [xdatetime], 121) AS [xdatetime]") > 0
			assert !strpos(`"`r(sql)'"', "86400000")
		}
		* In a frame block, because the frame prefix expands the macro
		* function in the current frame before it changes frame
		frame t188 {
			assert "`: format xdatetime'" == "%tc"
		}
	}
}
t_result dt_switch `=_rc'

* 189. The if qualifier on date-time and time columns gives the rows that keep
*      if leaves under the earlier method too: the expressions of tests 113 to
*      151 again, with SQLDTA_DTTEXT set
t_reset
local nfail 0
foreach e of local dtexprs {
	t_reset
	global SQLDTA_DTTEXT 1
	display as text _n `"if `e' (date-times as text)"'
	capture noisily t_ifcheck `"`e'"' "dataset(`fs'.sqldta_test_dt)"
	if _rc local ++nfail
}
display as text "dt if with SQLDTA_DTTEXT: `nfail' failed"
capture noisily assert `nfail' == 0
t_result dt_if_text `=_rc'

* 190. The label step on a table with 1,000 ValueLabel rows over 20 variables and a
*      VariableLabel row for each: every set has its codes and texts; the ends of the
*      range of a long, -2147483647 and 2147483620, are applied; code
*      2147483647, above that range, has the result that label define itself
*      gives it, which the log shows; a code that label define refuses
*      (99999999999), a code that is not a whole number and a column that does
*      not exist count as skipped; a ValueLabel row for a string column is passed
*      over; text with quotes, a backquote and $ is exact. The time of the
*      label step is shown.
t_reset
capture noisily {
	* The value label that label define gives the ValueLabel rows of v04, in frame
	* t190d, and whether it refuses code 2147483647
	capture frame drop t190d
	frame create t190d
	frame t190d {
		forvalues c = 1/50 {
			label define ref `c' "v04 code `c'", modify
		}
		label define ref -2147483647 "smallest" 2147483620 "largest", modify
		capture label define ref 2147483647 "above the largest", modify
		local rcmax = _rc
		local lmax : label ref 2147483647
	}
	display as text `"  label define on code 2147483647: r(`rcmax'); the label of 2147483647 is "`lmax'""'
	local nskip = 3 + (`rcmax' != 0)

	timer clear 90
	timer clear 91
	timer on 90
	sqldta, `flbl' frame(t190a) `nolab'
	timer off 90
	timer on 91
	sqldta, `flbl' frame(t190b) `alllab'
	timer off 91
	assert r(n_vallabels) == 20
	assert r(n_varlabels) == 20
	assert r(n_skipped) == `nskip'
	assert r(n_formats) == 0 & r(n_varnotes) == 0 & r(n_dtanotes) == 0
	quietly timer list
	display as text "  seconds: labels(none) " %6.2f r(t90) ", every label type " %6.2f r(t91)
	frame t190b {
		forvalues j = 1/20 {
			local v = "v" + string(`j', "%02.0f")
			assert "`: value label `v''" == "`v'"
			assert `"`: variable label `v''"' == "Variable `v'"
		}
		assert "`: value label vs'" == ""
		assert "`: label v07 37'" == "v07 code 37"
		assert "`: label v20 50'" == "v20 code 50"
		assert "`: label v04 -2147483647'" == "smallest"
		assert "`: label v04 2147483620'" == "largest"
		assert "`: label v04 2147483647'" == "`lmax'"
		t_vlcheck v01 50 1 50
		t_vlcheck v03 51 1 51
		t_vlcheck v05 50 1 50
		t_vlcheck v06 50 1 50
		mata: st_numscalar("t_ok", st_vlmap("v03", 51) == "He said " + char(34) + "it" + char(39) + "s" + char(34) + " " + char(96) + "x" + char(39) + " and " + char(36) + "y")
		assert scalar(t_ok) == 1
		mata: t_V1 = .; t_T1 = ""; st_vlload("v04", t_V1, t_T1)
	}
	* v04 holds the same codes and texts as the value label of frame t190d
	frame t190d: mata: t_V2 = .; t_T2 = ""; st_vlload("ref", t_V2, t_T2)
	mata: t_o1 = order(t_V1, 1); t_o2 = order(t_V2, 1); st_numscalar("t_ok", rows(t_V1) == rows(t_V2) && t_V1[t_o1] == t_V2[t_o2] && t_T1[t_o1] == t_T2[t_o2]); st_numscalar("t_k", rows(t_V1))
	display as text "  v04: " scalar(t_k) " values; the same as label define gives: " scalar(t_ok)
	assert scalar(t_ok) == 1
	sqldta, `flbl' frame(t190c) labels(values)
	assert r(n_vallabels) == 20 & r(n_varlabels) == 0 & r(n_skipped) == `nskip'
}
t_result labels_many `=_rc'

* 191. The default database of a server, r(default) of query databases, from
*      $SQLDTA_DEFAULTDB: a name for every server, server=database for one
*      server, matched without regard to case and with a named instance, a
*      name with a space, the first word of each kind, a word for the server
*      before a word for every server, none, and a default that is not
*      listed. Then on the test server, where the default is listed.
t_reset
capture noisily {
	global SQLDTA_DATABASES "DbOne DbTwo"
	sqldta_dlg query databases, server(sqldta_no_such_server)
	assert r(rc) == 0 & `"`r(list)'"' == "DbOne DbTwo" & `"`r(default)'"' == ""
	global SQLDTA_DEFAULTDB "DbTwo"
	sqldta_dlg query databases, server(sqldta_no_such_server)
	assert `"`r(default)'"' == "DbTwo"
	global SQLDTA_DEFAULTDB `"SrvA=DbOne DbTwo "srvb=My Db" SrvA=DbThree DbFour SrvC\Inst=DbFive"'
	foreach t in "SrvA|DbOne" "srva|DbOne" "SRVB|My Db" "SrvD|DbTwo" "SrvC\INST|DbFive" "SrvC|DbTwo" {
		local bar = strpos(`"`t'"', "|")
		local srv = substr(`"`t'"', 1, `bar' - 1)
		local db = substr(`"`t'"', `bar' + 1, .)
		sqldta_dlg query databases, server(`"`srv'"')
		display as text `"  `srv': `r(default)'"'
		assert `"`r(default)'"' == `"`db'"'
	}
	global SQLDTA_DEFAULTDB "SrvA=DbOne"
	sqldta_dlg query databases, server(SrvD)
	assert `"`r(default)'"' == ""
	global SQLDTA_DEFAULTDB "DbNine"
	sqldta_dlg query databases, server(SrvD)
	assert `"`r(default)'"' == "DbNine" & `"`r(list)'"' == "DbOne DbTwo"

	global SQLDTA_DATABASES
	global SQLDTA_DEFAULTDB `"$TEST_SERVER=$TEST_FIXDATABASE"'
	sqldta_dlg query databases, server("$TEST_SERVER")
	local list `"`r(list)'"'
	assert r(rc) == 0 & `"`r(default)'"' == "$TEST_FIXDATABASE"
	assert `: list posof "$TEST_FIXDATABASE" in list' > 0
}
t_result dlg_defaultdb `=_rc'

* 192. The labels of each column, kept by query describe and returned by
*      query column, on the types table: variable labels, value labels in
*      order of code with their number, a note, a char, varchar or text
*      column (r(textcols)), a string column whose ValueLabel row is passed over, a
*      column with no labels, and names that are not listed (matched exactly)
t_reset
capture noisily {
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_types) `fix'
	assert r(rc) == 0
	display as text "  textcols: `r(textcols)'"
	assert "`r(textcols)'" == "xchar xvarchar xvarcharmax xtext"
	local uni A char, varchar or text column, loaded as it is unless it is named under Unicode columns.
	foreach t in "xtinyint|tinyint. Value labels (5): 0 zero; 1 one; 2 two, with no DataType; 3 three; 255 largest." ///
		"xbit|bit. Value labels (2): 0 No; 1 Yes." ///
		"xdatetime|datetime. Note: Note on a datetime column." ///
		"xvarchar|varchar(50). `uni'" ///
		"xtext|text. `uni'" ///
		"xnvarchar|nvarchar(50)." ///
		"id|No variable label, value labels or notes in the label table." {
		local bar = strpos(`"`t'"', "|")
		local c = substr(`"`t'"', 1, `bar' - 1)
		local want = substr(`"`t'"', `bar' + 1, .)
		sqldta_dlg query column, name(`c')
		display as text `"  `c': `r(text)'"'
		assert r(rc) == 0
		assert `"`r(text)'"' == `"`want'"'
	}
	foreach c in XTINYINT sqldta_no_such_column {
		sqldta_dlg query column, name(`c')
		assert r(rc) == 111 & `"`r(text)'"' == ""
	}
}
t_result dlg_column_types `=_rc'

* 193. The labels of the columns of a split table: notes in PropertyCode order,
*      text and numeric, a variable label filed under the linked table, and
*      columns with no labels; no column is a char, varchar or text column
t_reset
capture noisily {
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_main) `fix'
	assert r(rc) == 0 & "`r(textcols)'" == ""
	local none No variable label, value labels or notes in the label table.
	foreach t in "grp|Notes: First note on grp. Second note on grp. Third note on grp." ///
		"num|Notes: First note on num. Second note on num. Third note on num. Note on num without an order." ///
		"extra1|Extra one, labelled under the linked table." ///
		"extra2|`none'" "amount|`none'" "Order|`none'" {
		local bar = strpos(`"`t'"', "|")
		local c = substr(`"`t'"', 1, `bar' - 1)
		local want = substr(`"`t'"', `bar' + 1, .)
		sqldta_dlg query column, name(`c')
		display as text `"  `c': `r(text)'"'
		assert r(rc) == 0
		assert `"`r(text)'"' == `"`want'"'
	}
}
t_result dlg_column_main `=_rc'

* 194. The labels of a column of the known table, exactly, with
*      double and single quotes, backquotes and dollar signs: the variable
*      label and every value label of $TEST_VALVAR, and the notes of
*      $TEST_NOTEVAR, including the long note
t_reset
capture noisily {
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_known) `fix'
	assert r(rc) == 0
	local vv
	local nv
	foreach c in `r(columns)' {
		if ustrlower("`c'") == ustrlower("$TEST_VALVAR") local vv `c'
		if ustrlower("`c'") == ustrlower("$TEST_NOTEVAR") local nv `c'
	}
	sqldta_dlg query column, name(`vv')
	assert r(rc) == 0
	mata: t_q = char(34); t_b = char(96); t_d = char(36); t_s = char(39)
	mata: t_want = "Variable label with " + t_q + "double quotes" + t_q + ", a " + t_b + "backquote" + t_s + " and " + t_d + "HOME. Value labels (11): -9 Negative code; 1 Plain label; 2 Double " + t_q + "quotes" + t_q + " inside; 3 Single " + t_s + "quotes" + t_s + ", a comma, a colon: and a semicolon;; 4 A lone backquote " + t_b + " and a macro-like " + t_b + "name" + t_s + " reference; 5 Dollar signs: " + t_d + "100, " + t_d + "HOME and " + t_d + "{HOME}; 6 Compound " + t_b + t_q + "quoted" + t_q + t_s + " text; 7 ColumnName written in lower case; 8 DataType written in lower case; 10 DataType VARCHAR, which sqldta does not use; 11 No DataType."
	mata: st_numscalar("t_ok", st_global("r(text)") == t_want)
	if scalar(t_ok) != 1 {
		mata: printf("  got:  %s\n  want: %s\n", st_global("r(text)"), t_want)
	}
	assert scalar(t_ok) == 1
	sqldta_dlg query column, name(`nv')
	assert r(rc) == 0
	mata: t_got = st_global("r(text)")
	mata: st_numscalar("t_ok", strpos(t_got, "Notes: ") > 0 & strpos(t_got, "Note with " + t_q + "double quotes" + t_q + " and " + t_s + "single quotes" + t_s + ".") > 0 & strpos(t_got, "Note with a lone backquote " + t_b + ", a macro-like " + t_b + "name" + t_s + " and " + t_d + "HOME.") > 0 & strpos(t_got, "Note with TS as a separate word.") > 0 & strpos(t_got, "Long note: " + 300 * "0123456789" + ".") > 0)
	assert scalar(t_ok) == 1
}
t_result dlg_column_known `=_rc'

* 195. The texts kept are those of the last description: a view replaces
*      those of the split table, a label table that does not exist gives that
*      for every column, and a description that fails leaves none
t_reset
capture noisily {
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_main) `fix'
	sqldta_dlg query column, name(extra1)
	assert r(rc) == 0
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_view) `fix'
	sqldta_dlg query column, name(extra1)
	assert r(rc) == 111
	sqldta_dlg query column, name(num)
	assert r(rc) == 0 & `"`r(text)'"' == "No variable label, value labels or notes in the label table."
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_view) labeltable("`fs'.sqldta_no_such_table")
	sqldta_dlg query column, name(num)
	assert r(rc) == 0 & `"`r(text)'"' == "The label table was not found, so there are no labels."
	display as text "(a failure is expected here)"
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_no_such_table) `fix'
	assert r(rc) != 0
	sqldta_dlg query column, name(num)
	assert r(rc) == 111 & `"`r(text)'"' == ""
}
t_result dlg_column_store `=_rc'

* 196. The time of a description, which applies every label type since the
*      dialog shows the labels of each column, against sqldta if 0 with
*      labels(dtanotes datalabel), which the description ran before: the
*      table with 1,000 ValueLabel rows, the wide table, the types table and the view
*      of the known table. Shown in the log; only success is checked.
t_reset
capture noisily {
	foreach d in lbl wide types known {
		timer clear 92
		timer clear 93
		timer on 92
		quietly sqldta if 0, `fsrc' dataset(`fs'.sqldta_test_`d') frame(t196) clear labels(dtanotes datalabel)
		timer off 92
		timer on 93
		sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
			dataset(`fs'.sqldta_test_`d') `fix'
		timer off 93
		assert r(rc) == 0
		local k : word count `r(columns)'
		quietly timer list
		display as text "  sqldta_test_`d' (`k' columns): seconds before " %6.2f r(t92) ", description now " %6.2f r(t93)
	}
}
t_result dlg_describe_time `=_rc'

* 197. Two servers in $SQLDTA_SERVERS, when $TEST_SERVER2 is set: the first is
*      the default in either order, and loads of the row of master.sys.servers
*      that names the server itself (server_id 0), through the template from
*      each server, give different names, so that %server% reached each one;
*      the databases of the second server are listed; the default database
*      of each server. The names and lists are checked, not shown.
t_reset
capture noisily {
	if `"$TEST_SERVER2"' == "" {
		display as text "  skipped: TEST_SERVER2 is not set in tests/test_config_local.do"
	}
	else {
		local s1 "$TEST_SERVER"
		local s2 "$TEST_SERVER2"
		local sys database(master) dataset(sys.servers) sqlselect(name) sqlwhere(server_id = 0) labels(none)
		global SQLDTA_SERVERS "`s1' `s2'"
		sqldta, `sys' frame(t197a)
		assert `"`r(server)'"' == "`s1'" & r(N) == 1
		frame t197a: local n1 = name[1]
		sqldta, server("`s2'") `sys' frame(t197b)
		assert `"`r(server)'"' == "`s2'" & r(N) == 1
		frame t197b: local n2 = name[1]
		display as text "  the servers' own names differ: " (`"`n1'"' != `"`n2'"')
		assert `"`n1'"' != `"`n2'"'
		global SQLDTA_SERVERS "`s2' `s1'"
		sqldta, `sys' frame(t197c)
		assert `"`r(server)'"' == "`s2'"
		frame t197c: assert name[1] == `"`n2'"'
		sqldta_dlg query databases, server("`s2'")
		display as text "  databases listed on the second server: " `: word count `r(list)''
		assert r(rc) == 0 & `"`r(list)'"' != ""
		local db2 : word 1 of `r(list)'
		global SQLDTA_DEFAULTDB `"`s1'=$TEST_FIXDATABASE `s2'=`db2'"'
		sqldta_dlg query databases, server("`s1'")
		assert `"`r(default)'"' == "$TEST_FIXDATABASE"
		sqldta_dlg query databases, server("`s2'")
		assert `"`r(default)'"' == `"`db2'"'
	}
}
t_result servers_two `=_rc'

* 198. Find: the columns kept by the last description whose name, variable
*      label or value labels contain every word of a text, in any case and in
*      the order of the table; every column for no text; none for a text that
*      no column holds; query column still answers after a search
t_reset
capture noisily {
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_types) `fix'
	assert r(rc) == 0
	local all `r(columns)'
	sqldta_dlg query find
	assert r(n) == 31 & r(k) == 31 & "`r(list)'" == "`all'"
	foreach t in "tinyint|xtinyint" "LARGEST|xtinyint" "yes|xbit" ///
		"varchar|xvarchar xvarcharmax xnvarchar xnvarcharmax" ///
		"two datatype|xtinyint" ///
		"datetime|xdatetime xdatetime2 xsmalldatetime xdatetimeoffset" {
		local bar = strpos(`"`t'"', "|")
		local q = substr(`"`t'"', 1, `bar' - 1)
		local want = substr(`"`t'"', `bar' + 1, .)
		sqldta_dlg query find, text(`"`q'"')
		display as text `"  find `q': `r(list)'"'
		assert "`r(list)'" == "`want'"
		assert r(n) == `: word count `want'' & r(k) == 31
	}
	sqldta_dlg query find, text(zzzz)
	assert r(n) == 0 & "`r(list)'" == ""
	sqldta_dlg query column, name(xbit)
	assert r(rc) == 0 & `"`r(text)'"' == "bit. Value labels (2): 0 No; 1 Yes."
}
t_result dlg_find `=_rc'

* 199. A table none of whose columns has a valid Stata name stops with error
*      111 and a message that says so, before it creates a frame; the
*      dialog's description stops with the same error
t_reset
capture noisily {
	quietly frames dir
	local before `r(frames)'
	display as text "(an error is expected here)"
	capture noisily sqldta, `fsrc' dataset(`fs'.sqldta_test_badnames) frame(t199)
	assert _rc == 111
	quietly frames dir
	local after `r(frames)'
	assert `: list after === before'
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_badnames) `fix'
	assert r(rc) == 111
}
t_result names_none `=_rc'

* 200. No text of an option or of a member call in src/sqldta.dlg begins with
*      the word literal, char, global or class, or with c(, r(, e( or s(,
*      which the dialog language reads as the source of a value instead of
*      text to show: the tooltip of the Unicode field began with the word
*      char and a comma, and every opening and Reset printed ", invalid name"
*      (found by the maintainer on 20 Oct 2026)
mata:
// The texts in the dialog file fn that begin with such a word, separated by
// " | ", or "" if there are none: the strings of label(), tooltip(),
// default(), error() and tabtitle(), and those given to stopbox and to the
// member programs whose names begin with set. The empty group in the second
// expression makes the text its third group, as the text is the second group
// of the first.
string scalar t_dlgbad(string scalar fn)
{
	string colvector L, re
	string scalar s, t, bad, key
	real scalar i, j

	L = cat(fn)
	re = ("(label|tooltip|default|error|tabtitle)\(" + char(34) + "([^" + char(34) + "]*)" + char(34) + "\)") \
		("(stopbox\s+[a-z]+|\.set[a-z]+)\s+()" + char(34) + "([^" + char(34) + "]*)" + char(34))
	key = "^\s*((literal|char|global|class)\b|[cers]\()"
	bad = ""
	for (i = 1; i <= rows(L); i++) {
		for (j = 1; j <= rows(re); j++) {
			s = L[i]
			while (ustrregexm(s, re[j])) {
				t = ustrregexs(j + 1)
				if (ustrregexm(t, key, 1)) bad = bad + (bad == "" ? "" : " | ") + t
				s = ustrregexrf(s, re[j], "")
			}
		}
	}
	return(bad)
}
end
t_reset
capture noisily {
	mata: t_bad = t_dlgbad("src/sqldta.dlg")
	mata: st_numscalar("t_ok", t_bad == "")
	if scalar(t_ok) == 0 {
		mata: printf("  texts that begin with such a word: %s\n", t_bad)
	}
	assert scalar(t_ok) == 1
}
t_result dlg_strings `=_rc'

* 201. Tables of the same name in two schemas (archive HANDOVER.md, 4.14):
*      each gets the rows filed under its own schema and name, joins the
*      linked table of its own schema, named in its Link row without one, and
*      a linked table in another schema gets the rows filed under that
*      schema; a row filed under dbo, where there is no such table, is not
*      fetched
t_reset
capture noisily {
	sqldta, `fsrc' dataset(`fs'.sqldta_test_same) frame(t201a)
	local got `=r(N)' `=r(k)' `r(links)' | `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "`fs'.sqldta_test_same: `got'"
	assert "`got'" == "3 4 `fs'.sqldta_test_samepart | applied 1 2 0 0 1 0"
	frame t201a {
		unab vl : _all
		assert "`vl'" == "id a b pr"
		assert pr == id + 10
		assert `"`: data label'"' == "Same name, in `fs'"
		assert `"`: variable label a'"' == "a, filed under `fs'"
		assert `"`: label (a) 1'"' == "one, filed under `fs'"
		assert `"`: variable label pr'"' == "pr, filed under `fs'.sqldta_test_samepart"
		assert `"`_dta[note0]'"' == "1"
		assert `"`_dta[note1]'"' == "Note filed under `fs'"
	}
	sqldta, `fsrc' dataset(sqldta_alt.sqldta_test_same) frame(t201b)
	local got `=r(N)' `=r(k)' `r(links)' | `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "sqldta_alt.sqldta_test_same: `got'"
	assert "`got'" == "2 5 ref.sqldta_test_samex sqldta_alt.sqldta_test_samepart | applied 1 4 0 0 1 0"
	frame t201b {
		unab vl : _all
		assert "`vl'" == "id a c x pa"
		assert x == id + 30
		assert pa == id + 20
		assert `"`: data label'"' == "Same name, in sqldta_alt"
		assert `"`: variable label a'"' == "a, filed under sqldta_alt"
		assert `"`: label (a) 1'"' == "one, filed under sqldta_alt"
		assert `"`: variable label c'"' == "c, filed under sqldta_alt"
		assert `"`: variable label x'"' == "x, filed under ref.sqldta_test_samex"
		assert `"`: variable label pa'"' == "pa, filed under sqldta_alt.sqldta_test_samepart"
		assert `"`_dta[note0]'"' == "1"
		assert `"`_dta[note1]'"' == "Note filed under sqldta_alt"
	}
}
t_result schemas_same_name `=_rc'

* 202. A label table without the columns of the layout, the fixture table
*      sqldta_test_otherlayout: the data are loaded, after a note, without
*      labels and without following Link rows, so the split table loads
*      without its linked tables, and r(labelstatus) is failed; with
*      labels(none) it is none, and Link rows are still not followed. (The
*      number 203 is not used.)
t_reset
capture noisily {
	sqldta, `fdb' dataset(`fs'.sqldta_test_main) labeltable(`fs'.sqldta_test_otherlayout) frame(t202a)
	assert "`r(labelstatus)'" == "failed"
	assert r(N) == 8 & r(k) == 7
	assert "`r(links)'" == ""
	assert r(n_vallabels) + r(n_varlabels) + r(n_formats) + r(n_varnotes) + r(n_dtanotes) + r(n_skipped) == 0
	frame t202a {
		unab vl : _all
		assert "`vl'" == "id num amount grp dob Order shared"
		assert `"`: data label'"' == "$TEST_FIXDATABASE.`fs'.sqldta_test_main"
		quietly label dir
		assert "`r(names)'" == ""
		assert `"`_dta[note0]'"' == ""
	}
	sqldta, `fdb' dataset(`fs'.sqldta_test_main) labeltable(`fs'.sqldta_test_otherlayout) frame(t202b) labels(none)
	assert "`r(labelstatus)'" == "none"
	assert r(k) == 7 & "`r(links)'" == ""
}
t_result layout_other `=_rc'

* Type report. Not a test: it shows the server's version, compatibility level
* and collation, and how each column of the three fixture tables of data types arrives in Stata
* through sqldta, through the connection template and through the DSN. Then
* it loads each whole table with labels(all) and shows the query and
* describe.
local tcols xbit xtinyint xsmallint xint xbigint xdecimal xdecimal38 xnumeric xmoney ///
	xsmallmoney xfloat xreal xdate xtime xdatetime xdatetime2 xsmalldatetime xdatetimeoffset ///
	xchar xvarchar xvarcharmax xnchar xnvarchar xnvarcharmax xtext xntext xuniqueidentifier ///
	xnumeric5 xdecimal15 xdecimal16
local rcols xbinary xvarbinary ximage xxml xsqlvariant xhierarchyid xgeography xgeometry xrowversion
local dcols xdatetime xdatetime2 xdatetime2_3 xdatetime2_0 xsmalldatetime xdatetimeoffset ///
	xtime xtime0 xdate

t_reset
display as text _n "TYPE REPORT server"
capture noisily t_serverinfo

foreach path in template dsn {
	t_reset
	if "`path'" == "dsn" global SQLDTA_CONNECTION
	t_typereport `path' `"`fsrc'"' sqldta_test_types "`tcols'"
	t_typereport `path' `"`fsrc'"' sqldta_test_rare "`rcols'"
	t_typereport `path' `"`fsrc'"' sqldta_test_dt "`dcols'"
	foreach d in types rare dt {
		display as text _n "TYPE REPORT sqldta_test_`d', whole table, `path'"
		capture noisily sqldta, `fsrc' dataset(`fs'.sqldta_test_`d') frame(t_tw) `alllab'
		local rc = _rc
		display as text "with labels(all): r(`rc')"
		if `rc' == 0 {
			display as text `"r(sql): `r(sql)'"'
			frame t_tw: describe, fullnames
		}
		capture frame drop t_tw
	}
}

* Clear report. Not a test: it shows whether odbc load, called directly with
* clear and the query that sqldta builds with unicode(*), loads the wide table
* and the types table into a frame that holds data, and into an empty frame,
* so that the cause of r(18) with clear can be read from the log.
t_reset
display as text _n "CLEAR REPORT"
local cs `"$TEST_CONNECTION"'
local cs : subinstr local cs "%server%" "$TEST_SERVER", all
local cs : subinstr local cs "%database%" "$TEST_FIXDATABASE", all
foreach d in wide types {
	capture frame drop t_cr
	capture noisily sqldta, `fsrc' dataset(`fs'.sqldta_test_`d') unicode(*) frame(t_cr) labels(none)
	if _rc {
		display as text "sqldta_test_`d': sqldta failed, r(" _rc ")"
		continue
	}
	local sql `"`r(sql)'"'
	local k = r(k)
	frame t_cr: quietly ds, has(type strL)
	local nstrl : word count `r(varlist)'
	display as text "sqldta_test_`d': " strlen(`"`sql'"') " characters of SQL, `k' variables, `nstrl' strL"
	frame t_cr: local before = c(k)
	capture noisily frame t_cr: odbc load, exec(`"`sql'"') connectionstring(`"`cs'"') clear
	display as text "  odbc load with clear, into a frame of `before' variables: r(" _rc ")"
	frame t_cr: clear
	capture noisily frame t_cr: odbc load, exec(`"`sql'"') connectionstring(`"`cs'"') clear
	display as text "  odbc load with clear, into an empty frame: r(" _rc ")"
	frame t_cr: local before = c(k)
	capture noisily frame t_cr: odbc load, clear connectionstring(`"`cs'"') exec(`"`sql'"')
	display as text "  odbc load with clear first, into a frame of `before' variables: r(" _rc ")"
}
capture frame drop t_cr

* 204. The settings file sqldta_site.cfg, the first along the ado-path, here
*      the tests' own: with the SQLDTA globals cleared, each setting comes
*      from its line, with the name in any case, after a tab or spaces, with
*      a byte-order mark, carriage returns, comments and blank lines; a line
*      with another name is passed over and given in r(ignored); sqldta
*      without server(), a schema or labeltable() loads the known table by
*      the file's server, schema, label table and template, and returns the
*      file in r(settings); the dialog's databases and default database come
*      from the file, without contacting the server
t_reset
capture noisily {
	foreach g of local sqldta_globals {
		global SQLDTA_`g'
	}
	mata: t_writecfg("$T_CFGFILE", ( ///
		"* sqldta test settings" \ ///
		"" \ ///
		"SQLDTA_SERVERS $TEST_SERVER OTHERSERVER" \ ///
		"sqldta_dataschema" + char(9) + "$TEST_SCHEMA" \ ///
		"   SQLDTA_LABELTABLE    $TEST_LABELSCHEMA.$TEST_LABELTABLE" \ ///
		"// a comment" \ ///
		"SQLDTA_CONNECTION $TEST_CONNECTION" \ ///
		"SQLDTA_DATABASES DbOne DbTwo" \ ///
		"SQLDTA_DEFAULTDB DbTwo OTHERSERVER=DbOne" \ ///
		"SQLDTA_DTTEXT 0" \ ///
		"SQLDTA_DLGREMEMBER 1" \ ///
		"SQLDTA_NOSUCHSETTING 1"), 1, 1)
	display as text "(a note on line 12 of the settings file is expected here)"
	_sqldta_settings
	local fn = subinstr(ustrlower(`"`r(file)'"'), "\", "/", .)
	display as text `"  settings file: `r(file)'"'
	assert strpos(`"`fn'"', "sqldta_test_settings/sqldta_site.cfg") > 0
	assert `"`r(servers)'"' == "$TEST_SERVER OTHERSERVER" & `"`r(server)'"' == "$TEST_SERVER"
	assert `"`r(dataschema)'"' == "$TEST_SCHEMA"
	assert `"`r(labeltable)'"' == "$TEST_LABELSCHEMA.$TEST_LABELTABLE"
	assert r(nconnections) == 1 & `"`r(connection1)'"' == `"$TEST_CONNECTION"'
	assert `"`r(databases)'"' == "DbOne DbTwo" & `"`r(defaultdb)'"' == "DbTwo OTHERSERVER=DbOne"
	assert "`r(dttext)'" == "0" & "`r(dlgremember)'" == "1"
	assert "`r(ignored)'" == "12"
	sqldta, database("$TEST_DATABASE") dataset("$TEST_TABLE") frame(t204a)
	assert `"`r(server)'"' == "$TEST_SERVER"
	assert `"`r(table)'"' == "$TEST_DATABASE.$TEST_SCHEMA.$TEST_TABLE"
	assert r(N) == $TEST_N & r(k) == $TEST_K
	assert "`r(labelstatus)'" == "applied" & "`r(datetimes)'" == "number"
	assert subinstr(ustrlower(`"`r(settings)'"'), "\", "/", .) == `"`fn'"'
	sqldta_dlg query databases, server("$TEST_SERVER")
	assert r(rc) == 0 & `"`r(list)'"' == "DbOne DbTwo" & `"`r(default)'"' == "DbTwo"
	sqldta_dlg query databases, server(OTHERSERVER)
	assert `"`r(default)'"' == "DbOne"
}
t_result settings_file `=_rc'

* 205. Globals come before the settings file, and the file before the
*      built-in defaults: each global replaces its line, and an empty global
*      leaves the line in force; a later line replaces an earlier one; the
*      global SQLDTA_CONNECTION replaces the file's templates, and dsn names
*      the ODBC data source; with neither, the built-in defaults; a $, a
*      backquote, a single quote and double quotes in a value are kept
*      exactly. None of this contacts a server.
t_reset
capture noisily {
	global SQLDTA_CONNECTION
	mata: t_writecfg("$T_CFGFILE", ("SQLDTA_SERVERS FILESERVER" \ "SQLDTA_DATASCHEMA one" \ ///
		"SQLDTA_DATASCHEMA two" \ "SQLDTA_CONNECTION Driver={x};Server=%server%;" \ ///
		"sqldta_connection DSN"), 0, 0)
	_sqldta_settings
	assert "`r(servers)'" == "FILESERVER" & "`r(dataschema)'" == "two"
	assert r(nconnections) == 2 & "`r(connection1)'" == "Driver={x};Server=%server%;"
	assert "`r(connection2)'" == "DSN"
	global SQLDTA_SERVERS GLOBALSERVER
	global SQLDTA_DATASCHEMA three
	global SQLDTA_CONNECTION dsn
	_sqldta_settings, connect
	assert "`r(servers)'" == "GLOBALSERVER" & "`r(server)'" == "GLOBALSERVER"
	assert "`r(dataschema)'" == "three"
	assert r(nconnections) == 1 & "`r(connection)'" == "dsn" & r(template) == 1 & r(probed) == 0
	global SQLDTA_SERVERS
	global SQLDTA_DATASCHEMA
	_sqldta_settings
	assert "`r(servers)'" == "FILESERVER" & "`r(dataschema)'" == "two"
	t_cfgempty
	global SQLDTA_CONNECTION
	_sqldta_settings, server(ANYSERVER) connect
	assert `"`r(file)'"' != "" & "`r(servers)'" == "" & "`r(dataschema)'" == ""
	assert r(nconnections) == 0 & "`r(connection)'" == "dsn" & r(template) == 0
	mata: t_writecfg("$T_CFGFILE", ("SQLDTA_DEFAULTDB a" + char(36) + "b c" + char(96) + "d'e" \ ///
		"SQLDTA_DATABASES " + char(34) + "My Db" + char(34) + " Other"), 0, 0)
	_sqldta_settings
	mata: assert(st_global("r(defaultdb)") == "a" + char(36) + "b c" + char(96) + "d'e")
	mata: assert(st_global("r(databases)") == char(34) + "My Db" + char(34) + " Other")
	sqldta_dlg query databases, server(ANYSERVER)
	assert r(rc) == 0
	local n : word count `r(list)'
	assert `n' == 2
}
t_result settings_precedence `=_rc'

* 206. macro drop _all, which a user's script may run, removes the SQLDTA
*      globals but not the settings file: after it, with the file's server,
*      schema, label table and template, sqldta without server() loads the
*      known table with its labels, the dialog lists the file's databases,
*      and the connection is the file's template; with an empty settings
*      file, sqldta without server() stops with error 198, and with server()
*      connects through the ODBC data source named after the server. Each
*      command runs in t_afterdrop, after macro drop _all; the test file's
*      globals are saved before and restored after.
t_reset
local tserver "$TEST_SERVER"
local tdb "$TEST_DATABASE"
local tschema "$TEST_SCHEMA"
local ttab "$TEST_TABLE"
local tlbl "$TEST_LABELSCHEMA.$TEST_LABELTABLE"
local tconn `"$TEST_CONNECTION"'
local tn $TEST_N
local tk $TEST_K
local tcfg `"$T_CFGFILE"'
mata: t_writecfg("$T_CFGFILE", ("SQLDTA_SERVERS $TEST_SERVER" \ "SQLDTA_DATASCHEMA $TEST_SCHEMA" \ ///
	"SQLDTA_LABELTABLE $TEST_LABELSCHEMA.$TEST_LABELTABLE" \ "SQLDTA_CONNECTION $TEST_CONNECTION" \ ///
	"SQLDTA_DATABASES DbOne DbTwo"), 0, 0)
mata: t_globals_save()
capture noisily {
	t_afterdrop sqldta, database("`tdb'") dataset("`ttab'") frame(t206a)
	assert `"`r(server)'"' == "`tserver'" & r(N) == `tn' & r(k) == `tk'
	assert `"`r(table)'"' == "`tdb'.`tschema'.`ttab'" & "`r(labelstatus)'" == "applied"
	t_afterdrop sqldta_dlg query databases, server("`tserver'")
	assert `"`r(list)'"' == "DbOne DbTwo"
	t_afterdrop _sqldta_settings, connect
	assert `"`r(server)'"' == "`tserver'" & `"`r(connection)'"' == `"`tconn'"' & r(template) == 1
	t_cfgempty `"`tcfg'"'
	display as text "(error 198 is expected here)"
	capture noisily t_afterdrop sqldta, database("`tdb'") dataset("`ttab'") frame(t206b)
	assert _rc == 198
	t_afterdrop sqldta, server("`tserver'") database("`tdb'") dataset("`tschema'.`ttab'") ///
		labeltable("`tlbl'") frame(t206c)
	assert r(N) == `tn' & "`r(labelstatus)'" == "applied"
	t_afterdrop _sqldta_settings, server("`tserver'") connect
	assert "`r(connection)'" == "dsn" & r(template) == 0
}
local rc = _rc
mata: t_globals_restore()
t_result settings_macro_drop `rc'

* 207. Connection templates in the settings file, tried in order: one that
*      names a driver that does not exist, the test template with an
*      application name, and dsn. The second is chosen, with a note, and
*      kept, so that the next call does not try them again; sqldta's queries
*      go through it, as a condition on APP_NAME() shows; probe tries them
*      again; sqldta settings tries each and returns its result and time; a
*      change of the templates tries them again; a single template, here
*      the global, is used whether or not it connects, and sqldta settings
*      says so; when several are given and none connects, the ODBC data
*      source is used, with a note, and the templates are tried again on the
*      next call
t_reset
capture noisily {
	global SQLDTA_CONNECTION
	local tc `"$TEST_CONNECTION"'
	if substr(`"`tc'"', -1, 1) != ";" local tc `"`tc';"'
	local app `"`tc'APP=sqldta test 207;"'
	local bad "Driver={sqldta test no such driver};Server=%server%;Trusted_Connection=yes;"
	local bad2 "Driver={sqldta test another driver};Server=%server%;Trusted_Connection=yes;"
	mata: t_writecfg("$T_CFGFILE", ("SQLDTA_CONNECTION `bad'" \ "SQLDTA_CONNECTION `app'" \ ///
		"SQLDTA_CONNECTION dsn"), 0, 0)
	display as text "(a note that template 2 of 3 is used is expected here)"
	_sqldta_settings, server("$TEST_SERVER") connect
	assert r(template) == 2 & r(probed) == 1 & `"`r(connection)'"' == `"`app'"'
	_sqldta_settings, server("$TEST_SERVER") connect
	assert r(template) == 2 & r(probed) == 0
	local sys server("$TEST_SERVER") database(master) dataset(sys.servers) sqlselect(name) labels(none)
	sqldta, `sys' sqlwhere(server_id = 0 AND APP_NAME() = N'sqldta test 207') frame(t207a)
	assert r(N) == 1
	_sqldta_settings, server("$TEST_SERVER") connect probe
	assert r(template) == 2 & r(probed) == 1
	sqldta settings, server("$TEST_SERVER")
	assert r(nconnections) == 3 & r(template) == 2
	assert r(rc1) != 0 & r(rc2) == 0
	display as text "  attempts: template 1 r(" r(rc1) ") " %5.2f r(sec1) " s, template 2 " ///
		%5.2f r(sec2) " s, dsn r(" r(rc3) ") " %5.2f r(sec3) " s"
	mata: t_writecfg("$T_CFGFILE", ("SQLDTA_CONNECTION `bad'" \ "SQLDTA_CONNECTION dsn"), 0, 0)
	_sqldta_settings, server("$TEST_SERVER") connect
	assert r(template) == 2 & r(probed) == 1 & "`r(connection)'" == "dsn"
	global SQLDTA_CONNECTION `"`bad'"'
	sqldta settings, server("$TEST_SERVER")
	assert r(nconnections) == 1 & r(rc1) != 0
	assert r(template) == 1 & `"`r(connection)'"' == `"`bad'"'
	global SQLDTA_CONNECTION
	mata: t_writecfg("$T_CFGFILE", ("SQLDTA_CONNECTION `bad'" \ "SQLDTA_CONNECTION `bad2'"), 0, 0)
	display as text "(a note that no template connected is expected here, three times)"
	_sqldta_settings, server("$TEST_SERVER") connect
	assert r(template) == 0 & r(probed) == 1 & "`r(connection)'" == "dsn"
	_sqldta_settings, server("$TEST_SERVER") connect
	assert r(probed) == 1
	sqldta, `sys' sqlwhere(server_id = 0) frame(t207b)
	assert r(N) == 1
}
t_result settings_connections `=_rc'

* 208. A query of the dialog's helper, with no global template and no
*      connection kept: _sqldta_odbc has _sqldta_settings choose the file's
*      template and keep it, so the query goes through it
t_reset
capture noisily {
	global SQLDTA_CONNECTION
	local tc `"$TEST_CONNECTION"'
	if substr(`"`tc'"', -1, 1) != ";" local tc `"`tc';"'
	mata: t_writecfg("$T_CFGFILE", ("SQLDTA_CONNECTION `tc'APP=sqldta test 208;"), 0, 0)
	sqldta_dlg query schemas, server("$TEST_SERVER") database("$TEST_FIXDATABASE")
	assert r(rc) == 0 & `"`r(list)'"' != ""
	mata: st_local("kept", (*findexternal("_sqldta_conn"))[1, 3])
	assert `"`kept'"' == `"`tc'APP=sqldta test 208;"'
}
t_result settings_helper `=_rc'

* 209. src/sqldta_site_example.cfg, the example that net install installs,
*      copied as the tests' settings file, reads without a line passed over:
*      its server, schema and label table, its five connection templates in
*      order, and its dialog and date-time settings. Nothing connects.
t_reset
capture noisily {
	copy "$TEST_SRC/sqldta_site_example.cfg" "$T_CFGFILE", replace
	global SQLDTA_CONNECTION
	_sqldta_settings
	assert "`r(ignored)'" == ""
	assert "`r(servers)'" == "MYSERVER" & "`r(dataschema)'" == "dbo"
	assert "`r(labeltable)'" == "ref.DataProperties" & "`r(labelfallback)'" == ""
	assert "`r(dlgremember)'" == "0" & "`r(dttext)'" == "0"
	assert `"`r(databases)'"' == "" & `"`r(defaultdb)'"' == ""
	assert r(nconnections) == 5
	assert strpos(`"`r(connection1)'"', "ODBC Driver 18 for SQL Server") > 0
	assert strpos(`"`r(connection5)'"', "Driver={SQL Server};") == 1
}
t_result settings_example `=_rc'

* 211. The example settings file where net install puts it, in the letter
*      folder s of a folder on the ado-path, here a folder inst of the tests'
*      folder, put first on the ado-path. No program in src/ names the
*      example. Under its own name, findfile finds it in the letter folder,
*      findfile sqldta_site.cfg does not find it, and _sqldta_settings reads
*      the tests' own settings file. Copied in the letter folder as
*      sqldta_site.cfg, and the example erased, as a rename would leave it,
*      findfile finds the copy, and _sqldta_settings reads it, before the
*      tests' own file in the next folder of the ado-path. Nothing connects.
t_reset
local d "$T_CFGDIR/inst"
capture noisily {
	global SQLDTA_CONNECTION
	foreach f in sqldta.ado _sqldta_odbc.ado _sqldta_settings.ado sqldta_dlg.ado sqldta.dlg {
		mata: st_local("hit", strofreal(sum(strpos(cat("$TEST_SRC/`f'"), "sqldta_site_example") :> 0)))
		assert `hit' == 0
	}
	capture mkdir "`d'"
	capture mkdir "`d'/s"
	copy "$TEST_SRC/sqldta_site_example.cfg" "`d'/s/sqldta_site_example.cfg", replace
	adopath ++ "`d'"
	findfile sqldta_site_example.cfg, path("`d'")
	capture findfile sqldta_site.cfg, path("`d'")
	assert _rc == 601
	_sqldta_settings
	local fn = ustrregexra(subinstr(ustrlower(`"`r(file)'"'), "\", "/", .), "/+", "/")
	display as text `"  settings file read beside the example: `r(file)'"'
	assert strpos(`"`fn'"', "sqldta_test_settings/sqldta_site.cfg") > 0
	assert `"`r(servers)'"' == ""
	copy "`d'/s/sqldta_site_example.cfg" "`d'/s/sqldta_site.cfg", replace
	erase "`d'/s/sqldta_site_example.cfg"
	findfile sqldta_site.cfg, path("`d'")
	_sqldta_settings
	local fn = ustrregexra(subinstr(ustrlower(`"`r(file)'"'), "\", "/", .), "/+", "/")
	display as text `"  settings file read after the rename: `r(file)'"'
	assert strpos(`"`fn'"', "/inst/s/sqldta_site.cfg") > 0
	assert `"`r(servers)'"' == "MYSERVER" & r(nconnections) == 5 & "`r(ignored)'" == ""
}
local rc = _rc
capture adopath - "`d'"
capture erase "`d'/s/sqldta_site.cfg"
capture erase "`d'/s/sqldta_site_example.cfg"
capture rmdir "`d'/s"
capture rmdir "`d'"
t_result settings_installed_example `rc'

* ---------------------------------------------------------------------------
* Tests 212 to 221: the README's examples of sqlwhere() and the if qualifier,
* on the generated table of admissions sqldta_test_adm, for January 2023. The
* rows that each example loads must be exactly the rows that its Stata
* equivalent keeps after a full load of the month, compared by id, and each
* example must select some rows.
* ---------------------------------------------------------------------------

t_reset
local adm `fdb' dataset(`fs'.sqldta_test_adm) labels(none)
local period if admdate >= td(01jan2023) & admdate < td(01feb2023)
capture noisily {
	sqldta `period', `adm' frame(t_adm)
	frame t_adm {
		* LIKE compares by the database's case-insensitive collation and =
		* ignores trailing spaces, so the equivalents compare in upper case,
		* trimmed
		generate byte f_like = ustrregexm(ustrupper(diag1), "^I21")
		generate byte f_ifsub = substr(diag1, 1, 3) == "I21"
		generate byte f_equal = ustrupper(strtrim(diag1)) == "I21.4"
		generate byte f_range = ustrupper(diag1) >= "C00" & ustrupper(diag1) < "C98"
		generate byte f_any = 0
		forvalues i = 1/20 {
			quietly replace f_any = 1 if ustrregexm(ustrupper(diag`i'), "^E1[0-4]")
		}
		* In T-SQL a comparison with NULL is never true, so rows with a
		* missing date are not selected, although Stata's missing is greater
		* than 30
		generate byte f_los = sepdate - admdate > 30 & !missing(admdate, sepdate)
		generate byte f_day = admitted >= tc(15jan2023 00:00) & admitted < tc(16jan2023 00:00)
		generate byte f_both = age >= 65 & !missing(age) & ustrregexm(ustrupper(diag1), "^J1[0-8]")
		display as text "  rows in January 2023: " _N
	}
}
local adm_rc = _rc

* 212. A code and its subcodes, with LIKE
capture noisily {
	assert `adm_rc' == 0
	sqldta `period', `adm' sqlselect(id) sqlwhere(diag1 LIKE 'I21%') frame(t_ex1)
	t_exsame t_ex1 f_like
}
t_result readme_like `=_rc'

* 213. The same with the if qualifier, which compares with regard to case
capture noisily {
	assert `adm_rc' == 0
	sqldta `period' & substr(diag1, 1, 3) == "I21", `adm' sqlselect(id) frame(t_ex1b)
	t_exsame t_ex1b f_ifsub
}
t_result readme_if_substr `=_rc'

* 214. One code exactly
capture noisily {
	assert `adm_rc' == 0
	sqldta `period', `adm' sqlselect(id) sqlwhere(diag1 = 'I21.4') frame(t_ex2)
	t_exsame t_ex2 f_equal
}
t_result readme_equal `=_rc'

* 215. A range of codes, C00 to C97
capture noisily {
	assert `adm_rc' == 0
	sqldta `period', `adm' sqlselect(id) sqlwhere(diag1 >= 'C00' AND diag1 < 'C98') frame(t_ex3)
	t_exsame t_ex3 f_range
}
t_result readme_range `=_rc'

* 216. A code in any of the diagnosis columns
capture noisily {
	assert `adm_rc' == 0
	local list (diag1)
	forvalues i = 2/20 {
		local list `list', (diag`i')
	}
	sqldta `period', `adm' sqlselect(id) ///
		sqlwhere(EXISTS (SELECT 1 FROM (VALUES `list') AS d(code) WHERE d.code LIKE 'E1[0-4]%')) frame(t_ex4)
	t_exsame t_ex4 f_any
}
t_result readme_any_column `=_rc'

* 217. Arithmetic: a length of stay over 30 days
capture noisily {
	assert `adm_rc' == 0
	sqldta `period', `adm' sqlselect(id) sqlwhere(DATEDIFF(day, admdate, sepdate) > 30) frame(t_ex5)
	t_exsame t_ex5 f_los
}
t_result readme_stay `=_rc'

* 218. A date in T-SQL, written YYYYMMDD, against a date-time column
capture noisily {
	assert `adm_rc' == 0
	sqldta `period', `adm' sqlselect(id) sqlwhere(admitted >= '20230115' AND admitted < '20230116') frame(t_ex6)
	t_exsame t_ex6 f_day
}
t_result readme_date_literal `=_rc'

* 219. The if qualifier and sqlwhere() together
capture noisily {
	assert `adm_rc' == 0
	sqldta `period' & age >= 65 & !missing(age), `adm' sqlselect(id) ///
		sqlwhere(diag1 LIKE 'J1[0-8]%') frame(t_ex7)
	t_exsame t_ex7 f_both
}
t_result readme_both `=_rc'

* 220. A subquery: every admission in the month of a person who has had an
*      admission with the principal diagnosis I21 at any time, which includes
*      the admissions of test 212
capture noisily {
	assert `adm_rc' == 0
	sqldta `period', `adm' sqlselect(id) ///
		sqlwhere(personid IN (SELECT personid FROM [$TEST_FIXDATABASE].[`fs'].[sqldta_test_adm] WHERE diag1 LIKE 'I21%')) ///
		frame(t_ex8)
	t_exsubset t_ex8 t_ex1
}
t_result readme_subquery `=_rc'

* 221. A random sample of 10 of the rows of test 212, which has more than 10
capture noisily {
	assert `adm_rc' == 0
	sqldta `period', `adm' sqlselect(id) sqlwhere(diag1 LIKE 'I21%') sqlrand(10) frame(t_ex9)
	frame t_ex1: local n1 = _N
	frame t_ex9: local n9 = _N
	display as text "  `n9' of `n1' rows"
	assert `n1' > 10 & `n9' == 10
	t_exsubset t_ex1 t_ex9
}
t_result readme_sample `=_rc'

* ---------------------------------------------------------------------------
* Tests 222 to 225: SQLDTA_LABELFALLBACK, a label table of the predecessor's
* layout, here the fixture table sqldta_test_oldlabels, which sqldta reads in
* place of the label table when that is not found
* ---------------------------------------------------------------------------

local fbnone labeltable("`fs'.sqldta_no_such_table")

* 222. Through the fallback, the known table, the split table and the types
*      table get the same labels, display formats, notes, data label, linked
*      tables and counts as through the fixture label table, from rows of the
*      predecessor's types and of the current ones, with DataType not read;
*      with labels(none), the same linked tables. The notes of the known
*      table have no PropertyCode, so they are compared in sorted order.
t_reset
capture noisily {
	global SQLDTA_LABELFALLBACK "`fs'.sqldta_test_oldlabels"
	foreach d in known main types {
		local srt = cond("`d'" == "known", "sorted", "")
		sqldta, `fdb' dataset(`fs'.sqldta_test_`d') `fix' frame(t222a)
		local want `=r(N)' `=r(k)' `r(links)' | `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
		sqldta, `fdb' dataset(`fs'.sqldta_test_`d') `fbnone' frame(t222b)
		local got `=r(N)' `=r(k)' `r(links)' | `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
		display as text "sqldta_test_`d': `want' || `got'"
		assert "`got'" == "`want'" & "`r(labelstatus)'" == "applied"
		t_samelabels t222a t222b `srt'
		frame drop t222a
		frame drop t222b
	}
	sqldta, `fdb' dataset(`fs'.sqldta_test_main) `fbnone' frame(t222c) labels(none)
	assert "`r(labelstatus)'" == "none"
	assert "`r(links)'" == "ref.sqldta_test_part `fs'.sqldta_test_part2"
}
t_result fallback_same `=_rc'

* 223. The fallback is read only when the label table is not found: through
*      the fixture label table, sqldta_test_same gets its own rows and linked
*      table, as in test 201. Through a label table that does not exist, the
*      tables sqldta_test_same in sqldta_test and in sqldta_alt both get the
*      fallback's rows filed under that name, whatever the schema, among them
*      a type in lower case and a value label whose DataType is not INT, and
*      no linked table, since the fallback has no Link row for them. Without
*      the setting, the label table is not found, as in test 11.
t_reset
capture noisily {
	global SQLDTA_LABELFALLBACK "`fs'.sqldta_test_oldlabels"
	sqldta, `fsrc' dataset(`fs'.sqldta_test_same) frame(t223a)
	assert r(k) == 4 & "`r(links)'" == "`fs'.sqldta_test_samepart"
	frame t223a {
		assert `"`: variable label a'"' == "a, filed under `fs'"
	}
	foreach s in `fs' sqldta_alt {
		sqldta, `fdb' dataset(`s'.sqldta_test_same) `fbnone' frame(t223_`s')
		local got `=r(N)' `=r(k)' | `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
		display as text "`s'.sqldta_test_same: `got'"
		assert "`r(links)'" == ""
		if "`s'" == "`fs'" assert "`got'" == "3 3 | applied 1 1 0 0 1 0"
		else assert "`got'" == "2 3 | applied 1 1 0 0 1 0"
		frame t223_`s' {
			assert `"`: data label'"' == "Same name, from the earlier layout"
			assert `"`: variable label a'"' == "a, from the earlier layout"
			assert `"`: label (a) 1'"' == "one, from the earlier layout"
			assert `"`_dta[note0]'"' == "1"
			assert `"`_dta[note1]'"' == "Note from the earlier layout"
		}
	}
	global SQLDTA_LABELFALLBACK
	sqldta, `fdb' dataset(`fs'.sqldta_test_same) `fbnone' frame(t223c)
	assert "`r(labelstatus)'" == "notfound"
}
t_result fallback_when `=_rc'

* 224. SQLDTA_LABELFALLBACK in the settings file, named without a schema, so
*      in the schema of the default label table, which the file names as a
*      table that does not exist: sqldta without labeltable() reads the
*      fallback, with the counts that the fixture label table gives;
*      _sqldta_settings and sqldta settings return it; a global replaces the
*      line. A fallback that does not exist is not found either. A fallback
*      without the columns of the predecessor's layout, the fixture table
*      sqldta_test_otherlayout, gives a note, r(labelstatus) failed and no
*      linked tables; with labels(none), none.
t_reset
capture noisily {
	mata: t_writecfg("$T_CFGFILE", ("SQLDTA_LABELTABLE `fs'.sqldta_no_such_table" \ ///
		"SQLDTA_LABELFALLBACK sqldta_test_oldlabels"), 0, 0)
	_sqldta_settings
	assert "`r(labelfallback)'" == "sqldta_test_oldlabels"
	sqldta settings
	assert "`r(labelfallback)'" == "sqldta_test_oldlabels"
	sqldta, `fdb' dataset(`fs'.sqldta_test_main) frame(t224a)
	local got `=r(N)' `=r(k)' `r(links)' | `r(labelstatus)' `=r(n_vallabels)' `=r(n_varlabels)' `=r(n_formats)' `=r(n_varnotes)' `=r(n_dtanotes)' `=r(n_skipped)'
	display as text "through the settings file: `got'"
	assert "`got'" == "8 11 ref.sqldta_test_part `fs'.sqldta_test_part2 | applied 0 1 2 7 2 1"
	frame t224a {
		assert `"`: data label'"' == "Fixture main table"
	}
	global SQLDTA_LABELFALLBACK "`fs'.sqldta_no_such_table2"
	sqldta, `fdb' dataset(`fs'.sqldta_test_main) frame(t224b)
	assert "`r(labelstatus)'" == "notfound" & "`r(links)'" == ""
	global SQLDTA_LABELFALLBACK "`fs'.sqldta_test_otherlayout"
	display as text "(a note that the label table lacks columns is expected here)"
	sqldta, `fdb' dataset(`fs'.sqldta_test_main) frame(t224c)
	assert "`r(labelstatus)'" == "failed" & "`r(links)'" == "" & r(k) == 7
	sqldta, `fdb' dataset(`fs'.sqldta_test_main) frame(t224d) labels(none)
	assert "`r(labelstatus)'" == "none" & "`r(links)'" == ""
}
t_result fallback_settings `=_rc'

* 225. The dialog's description of the split table through the fallback is
*      the same as through the fixture label table: the text, the linked
*      tables and the text of a column with notes
t_reset
capture noisily {
	global SQLDTA_LABELFALLBACK "`fs'.sqldta_test_oldlabels"
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_main) `fix'
	assert r(rc) == 0
	mata: t_T = st_global("r(text)")
	local links `r(links)'
	sqldta_dlg query column, name(num)
	mata: t_N = st_global("r(text)")
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_main) `fbnone'
	assert r(rc) == 0 & "`r(labelstatus)'" == "applied"
	mata: printf("{txt}  text: %s\n", st_global("r(text)"))
	mata: st_numscalar("t_ok", st_global("r(text)") == t_T)
	assert scalar(t_ok) == 1 & "`r(links)'" == "`links'"
	sqldta_dlg query column, name(num)
	mata: printf("{txt}  num: %s\n", st_global("r(text)"))
	mata: st_numscalar("t_ok", st_global("r(text)") == t_N)
	assert scalar(t_ok) == 1
}
t_result fallback_dialog `=_rc'

* 226. r(description), the text of the DatasetDescription row of PropertyCode
*      1 of the table loaded, exactly, and not that of its linked table,
*      through the fixture label table and through the fallback; the rows are
*      not applied and not counted as skipped; empty with labels(none), and
*      for a table that has no such row of PropertyCode 1, whose description
*      in the dialog says that none is available
t_reset
capture noisily {
	mata: t_D = "First paragraph of the description, with " + char(34) + "double quotes" + char(34) + ", a " + char(96) + "backquote" + char(39) + " and " + char(36) + "HOME"
	sqldta, `fmain' frame(t226a)
	mata: st_numscalar("t_ok", st_global("r(description)") == t_D)
	assert scalar(t_ok) == 1
	assert r(n_dtanotes) == 2 & r(n_skipped) == 1
	frame t226a {
		assert `"`_dta[note0]'"' == "2"
	}
	global SQLDTA_LABELFALLBACK "`fs'.sqldta_test_oldlabels"
	sqldta, `fdb' dataset(`fs'.sqldta_test_main) `fbnone' frame(t226b)
	mata: st_numscalar("t_ok", st_global("r(description)") == t_D)
	assert scalar(t_ok) == 1 & r(n_dtanotes) == 2 & r(n_skipped) == 1
	global SQLDTA_LABELFALLBACK
	sqldta, `fmain' frame(t226c) labels(none)
	assert `"`r(description)'"' == ""
	sqldta, `fsrc' dataset(`fs'.sqldta_test_types) frame(t226d)
	assert `"`r(description)'"' == "" & r(n_skipped) == 0
	sqldta_dlg query describe, server("$TEST_SERVER") database("$TEST_FIXDATABASE") ///
		dataset(`fs'.sqldta_test_types) `fix'
	display as text `"  text: `r(text)'"'
	assert r(rc) == 0 & `"`r(description)'"' == ""
	local tail Fixture table of SQL Server data types. No dataset description available.
	assert substr(`"`r(text)'"', -strlen("`tail'"), .) == "`tail'"
}
t_result description `=_rc'

* 227. After clear mata, sqldta either still works or asks for discard; after
*      discard it works. This test clears the Mata functions of this file, so
*      it must stay last.
t_reset
capture noisily {
	clear mata
	capture noisily sqldta if num == 1, `fmain' frame(t227a)
	display as text "after clear mata: r(" _rc ")"
	discard
	sqldta if num == 1, `fmain' frame(t227b)
	assert r(N) == 1
}
t_result if_clear_mata `=_rc'

* ---------------------------------------------------------------------------
* Leave the fixture tables of data types and the known table loaded, with
* labels(all) and in order of id, for inspection in the Data Editor and
* comparison with SSMS. Not tests: a failure here is displayed only.
* ---------------------------------------------------------------------------

t_reset
display as text _n "FRAMES LEFT FOR INSPECTION"
foreach d in types rare dt {
	capture noisily sqldta, `fsrc' dataset(`fs'.sqldta_test_`d') frame(sqldta_test_`d') `alllab'
	capture frame sqldta_test_`d': sort id
}
capture noisily sqldta, `src' `lbl' frame(known) `alllab'
capture frame change sqldta_test_types
frames dir

* ---------------------------------------------------------------------------
* Restore the site globals and the ado-path, then report
* ---------------------------------------------------------------------------

foreach g of local sqldta_globals {
	global SQLDTA_`g' `"${T_SAVED_`g'}"'
	global T_SAVED_`g'
}
capture mata: mata drop _sqldta_conn
capture adopath - "$T_CFGDIR"
capture erase "$T_CFGFILE"
capture rmdir "$T_CFGDIR"
capture adopath - "`srcdir'"

display as text _n "The frames above are left loaded; the current frame is `c(frame)'."
display as text "Type browse to inspect it, or frame change name to work in another."
display as text _n "SQLDTA TESTS: $T_PASS passed, $T_FAIL failed"
if $T_FAIL > 0 display as text "Failed: $T_FAILED"
log close sqldtatest
