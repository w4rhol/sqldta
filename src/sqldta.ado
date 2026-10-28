*! version 1.3.0 28oct2026
program define sqldta, rclass
	version 16

	* sqldta settings [, server(name)] shows the settings and where each comes
	* from, and tries each connection template on the server
	gettoken first : 0, parse(" ,")
	if `"`first'"' == "settings" {
		gettoken first 0 : 0, parse(" ,")
		syntax [, SERver(string)]
		_sqldta_settings, server(`"`server'"') connect display
		return add
		exit
	}

	* The if qualifier is split off by Mata rather than by syntax [if],
	* because syntax checks the variables of an if expression against the
	* data in memory, and here they are columns on the server
	local ifexp
	gettoken first : 0
	if `"`first'"' == "if" {
		* Mata functions defined in an ado-file are private to it, so mata
		* which cannot see them; calling one is the test that they exist
		capture mata: _sqldta_present()
		if _rc {
			display as error "sqldta: its Mata functions are not in memory, which happens after clear mata;"
			display as error "type discard and run the command again"
			exit 3499
		}
		mata: _sqldta_splitif()
	}

	syntax , DATABase(string) DATASet(string) [ SERver(string) FRAme(string) ///
		CLEAR LOWercase noDECformat LABELS(string) ///
		SQLRand(numlist >0 max=1 integer) SQLSelect(string) SQLWhere(string) ///
		LABELTable(string) UNIcode(string) ]

	* Settings: the option if given, else the global of the setting, else the
	* line of the settings file sqldta_site.cfg, else the built-in default.
	* _sqldta_settings also chooses the connection to the server, which
	* _sqldta_odbc then uses for each query.
	_sqldta_settings, server(`"`server'"') database(`"`database'"') connect
	local settings `"`r(file)'"'
	local server `"`r(server)'"'
	local defschema `"`r(dataschema)'"'
	local deflabel `"`r(labeltable)'"'
	local fallback `"`r(labelfallback)'"'
	local dttextset `"`r(dttext)'"'
	if `"`server'"' == "" {
		display as error "server() is required because no server is set in SQLDTA_SERVERS, as a global"
		display as error "  or in a settings file sqldta_site.cfg"
		exit 198
	}

	* dataset() and labeltable() take table or schema.table. A table named
	* without a schema is in SQLDTA_DATASCHEMA, or dbo; a label table named
	* without one is in the schema of the default label table.
	if `"`defschema'"' == "" local defschema dbo
	_sqldta_split `"`dataset'"' `"`defschema'"' "dataset()"
	local dataschema `"`r(schema)'"'
	local dataset `"`r(table)'"'

	if `"`deflabel'"' == "" local deflabel ref.DataProperties
	_sqldta_split `"`deflabel'"' ref "SQLDTA_LABELTABLE"
	local deflschema `"`r(schema)'"'
	if `"`labeltable'"' == "" local labeltable `"`deflabel'"'
	_sqldta_split `"`labeltable'"' `"`deflschema'"' "labeltable()"
	local labelschema `"`r(schema)'"'
	local labeltable `"`r(table)'"'

	* SQLDTA_LABELFALLBACK: a label table of the predecessor's layout, read in
	* place of the label table when that is not found, for backward
	* compatibility. A table named without a schema is in the schema of the
	* default label table.
	if `"`fallback'"' != "" {
		_sqldta_split `"`fallback'"' `"`deflschema'"' "SQLDTA_LABELFALLBACK"
		local fbschema `"`r(schema)'"'
		local fbtable `"`r(table)'"'
	}

	* Date-times are sent as numbers of milliseconds, unless SQLDTA_DTTEXT,
	* set to anything other than 0, asks for the earlier method: text
	* converted with clock()
	local dttext = !inlist(`"`dttextset'"', "", "0")

	* labels(): the label types to apply; all of them by default
	_sqldta_labeltypes `"`labels'"'
	local labels `r(labels)'
	local types `r(types)'

	local source `database'.`dataschema'.`dataset'

	* Target frame; refuses with error 4 if it holds data and clear was not
	* given. A frame that does not exist is created just before the data load.
	_sqldta_target `"`frame'"' "`clear'"
	local target `r(frame)'
	local create = r(create)

	* Link rows in the label table, if the label table exists and has the
	* columns of its layout. A linked table named without a schema is in the
	* schema of the main table. When the label table is not found and
	* SQLDTA_LABELFALLBACK is set, the label table it names is read instead;
	* one query checks both.
	_sqldta_meta `"`server'"' `"`database'"' `"`labelschema'"' `"`labeltable'"' ///
		`"`dataset'"' `"`dataschema'"' `"`fbschema'"' `"`fbtable'"'
	local lblfound = r(found)
	local oldlayout = r(old)
	local nfmsg label table `database'.`labelschema'.`labeltable'
	if `oldlayout' {
		local labelschema `"`fbschema'"'
		local labeltable `"`fbtable'"'
	}
	else if !`lblfound' & `"`fallback'"' != "" {
		local nfmsg label tables `database'.`labelschema'.`labeltable' and `database'.`fbschema'.`fbtable'
	}
	local lblmissing `r(missing)'
	local nlinks = r(nlinks)
	local lkeys `r(keys)'
	local lschemas `r(schemas)'
	local ltables `r(tables)'
	if "`lblmissing'" != "" {
		display as text `"note: label table `database'.`labelschema'.`labeltable' lacks `lblmissing',"'
		display as text "  so no labels are applied and no Link rows are followed; a label table needs the"
		if `oldlayout' display as text "  columns Dataset, VarName, LabelType, DataCode and LabelName"
		else display as text "  columns TableSchema, TableName, ColumnName, PropertyType, PropertyCode and PropertyText"
	}

	* Columns of the main table and of each linked table
	_sqldta_qname `"`database'"' `"`dataschema'"' `"`dataset'"'
	local qmain `"`r(qname)'"'
	local lit : subinstr local qmain "'" "''", all
	local values (0, OBJECT_ID(N'`lit''))
	local links
	forvalues i = 1/`nlinks' {
		local s : word `i' of `lschemas'
		local t : word `i' of `ltables'
		local link`i' `s'.`t'
		local links `links' `s'.`t'
		_sqldta_qname `"`database'"' `"`s'"' `"`t'"'
		local qlink`i' `"`r(qname)'"'
		local lit : subinstr local qlink`i' "'" "''", all
		local values `values', (`i', OBJECT_ID(N'`lit''))
	}
	_sqldta_columns `"`server'"' `"`database'"' `"`values'"' "`lkeys'"
	if r(rc) {
		local rc = r(rc)
		exit `rc'
	}
	local cols `r(cols)'
	local kinds `r(kinds)'
	local sqltypes `r(sqltypes)'
	local maxlens `r(maxlens)'
	local precs `r(precs)'
	local scales `r(scales)'
	local owners `r(owners)'
	local lall `r(lall)'
	local invalid `"`r(invalid)'"'
	local dupcols `r(dupcols)'
	local dupowners `r(dupowners)'
	local mainall = r(mainall)
	local counts `r(counts)'
	local nokey `r(nokey)'
	local nokeymain `r(nokeymain)'

	if `: word 1 of `counts'' == 0 {
		display as error `"sqldta: table `source' not found or not readable"'
		exit 601
	}
	forvalues i = 1/`nlinks' {
		if `: word `=`i' + 1' of `counts'' == 0 {
			display as error `"sqldta: linked table `database'.`link`i'' not found or not readable"'
			exit 601
		}
	}
	foreach i of local nokeymain {
		display as error `"sqldta: key `: word `i' of `lkeys'' of linked table `link`i'' is not a column of `source'"'
		exit 459
	}
	foreach i of local nokey {
		display as error `"sqldta: key `: word `i' of `lkeys'' is not a column of linked table `link`i''"'
		exit 459
	}

	local dropped
	if `"`invalid'"' != "" {
		display as text `"note: columns left out because their names are not valid Stata names: `invalid'"'
		local dropped `"`invalid'"'
	}
	if "`dupcols'" != "" {
		local dups
		local sep
		local j 0
		foreach c of local dupcols {
			local ++j
			local o : word `j' of `dupowners'
			local dups `"`dups'`sep'`link`o''.`c'"'
			local sep ", "
		}
		display as text `"note: columns left out because an earlier table has a column of the same name: `dups'"'
		if `"`dropped'"' != "" local dropped `"`dropped', `dups'"'
		else local dropped `"`dups'"'
	}

	* A table none of whose columns has a valid Stata name cannot be loaded.
	* Said here, because otherwise sqlselect() would report that no column
	* matches *, although none was asked for (seen on 20 Oct 2026 on a table
	* whose column names all start with a digit and hold spaces)
	if `"`cols'"' == "" {
		display as error `"sqldta: no column of `source' has a valid Stata name, so none can be loaded."'
		display as error "  A valid name has letters, digits and underscores, does not start with a digit and"
		display as error "  has at most 32 characters. A view that renames the columns can be loaded instead."
		exit 111
	}

	* Column list. A column whose type odbc load mishandles is sent as an
	* expression, so the list then names every column instead of *. The char,
	* varchar and text columns named in unicode() are sent as Unicode.
	local spec `"`sqlselect'"'
	if `"`spec'"' == "" local spec *
	_sqldta_select `"`spec'"' "`cols'" `"`source'"' "sqlselect()"
	local positions `r(positions)'
	local names `r(names)'
	local upos
	if `"`unicode'"' != "" {
		_sqldta_select `"`unicode'"' "`cols'" `"`source'"' "unicode()"
		local upos `r(positions)'
	}
	_sqldta_selectlist "`positions'" "`names'" "`cols'" "`sqltypes'" ///
		"`maxlens'" "`precs'" "`scales'" "`upos'" `dttext'
	local select `"`r(select)'"'
	local expr = r(expr)
	local unicols `r(unicode)'
	if `"`sqlselect'"' == "" & !`expr' & (`nlinks' > 0 | `mainall') local select *

	* Linked tables are joined in SQL, inside a derived table, so that the
	* column list, the filter and sqlrand() apply to the joined table
	local from `"`qmain'"'
	if `nlinks' > 0 {
		local inner
		local sep
		if `mainall' {
			local inner m.*
			local sep ", "
		}
		local j 0
		foreach c of local cols {
			local ++j
			local o : word `j' of `owners'
			if `o' == 0 & `mainall' continue
			if `o' == 0 local alias m
			else local alias l`o'
			local inner `inner'`sep'`alias'.[`c']
			local sep ", "
		}
		local joins
		forvalues i = 1/`nlinks' {
			local k : word `i' of `lkeys'
			local joins `joins' LEFT JOIN `qlink`i'' AS l`i' ON l`i'.[`k'] = m.[`k']
		}
		* A local loses leading spaces, so the space before the joins is
		* written here
		local from (SELECT `inner' FROM `qmain' AS m `joins') AS t
	}

	* Filter: the if qualifier translated to T-SQL, then sqlwhere() as given
	local ifsql
	if `"`ifexp'"' != "" {
		mata: _sqldta_if(st_local("ifexp"), st_local("cols"), st_local("kinds"), st_local("sqltypes"), "ifsql")
	}
	local where
	if `"`ifsql'"' != "" local where `"(`ifsql')"'
	if `"`sqlwhere'"' != "" {
		if `"`where'"' != "" local where `"`where' AND (`sqlwhere')"'
		else local where `"(`sqlwhere')"'
	}

	_sqldta_sql `"`from'"' `"`select'"' `"`where'"' "`sqlrand'"
	local sql `"`r(sql)'"'

	* Only 1:1 links are supported, so a key that repeats in a linked table
	* stops the command before any data are loaded
	forvalues i = 1/`nlinks' {
		_sqldta_keycheck `"`server'"' `"`database'"' `"`qlink`i''"' "`link`i''" ///
			"`: word `i' of `lkeys''"
	}

	* Data. A frame that exists is cleared here, which clear allows if it holds
	* data, because odbc load ignores a clear written after a very long exec()
	* and stops with r(18), "you must start with an empty dataset" (clear
	* report of the log of archive 46d4e17, with a query of 43,055 characters). If the
	* query then fails, the frame is left empty.
	if `create' frame create `target'
	else frame `target': clear
	_sqldta_odbc `target' `"`server'"' `"`database'"' `"`dataschema'.`dataset'"' `"`sql'"'
	if r(rc) {
		local rc = r(rc)
		if `create' frame drop `target'
		exit `rc'
	}

	frame `target': local k = c(k)
	if "`lowercase'" != "" & `k' > 0 {
		* Quietly, because rename prints (all newnames==oldnames) when every
		* name is already in lower case (log of archive 2880551); an error is still
		* shown
		frame `target': quietly rename *, lower
		local unicols = ustrlower("`unicols'")
	}

	_sqldta_convert `target' "`cols'" "`sqltypes'" "`precs'" "`scales'" "`decformat'"
	local converted `r(converted)'

	* The default data label; a DatasetLabel row replaces it
	local dlabel = usubstr(`"`source'"', 1, 80)
	frame `target': label data `"`dlabel'"'

	* Labels
	local status none
	local description
	foreach s in vallabels varlabels formats varnotes dtanotes skipped {
		local n_`s' 0
	}
	if "`types'" != "" {
		* A missing label table is reported in the summary line below, and one
		* without the columns of the layout in the note above as well
		if !`lblfound' local status notfound
		else if "`lblmissing'" != "" local status failed
		else {
			_sqldta_labels `target' `"`server'"' `"`database'"' `"`labelschema'"' ///
				`"`labeltable'"' `"`dataschema'"' `"`dataset'"' "`lschemas'" "`ltables'" ///
				"`types'" "`lall'" `oldlayout'
			local status `r(status)'
			mata: st_local("description", st_global("r(description)"))
			if "`status'" == "applied" {
				foreach s in vallabels varlabels formats varnotes dtanotes skipped {
					local n_`s' = r(n_`s')
				}
			}
		}
	}

	* Summary
	frame `target': local N = c(N)
	frame `target': local k = c(k)
	local Nfmt = strtrim(string(`N', "%20.0fc"))
	local sN = cond(`N' == 1, "", "s")
	local sk = cond(`k' == 1, "", "s")
	local msg `Nfmt' observation`sN', `k' variable`sk' from `source'
	if `nlinks' == 1 local msg `msg' and 1 linked table
	if `nlinks' > 1 local msg `msg' and `nlinks' linked tables
	local msg `msg' into frame `target'
	if "`status'" == "notfound" {
		local msg `msg'; `nfmsg' not found or not readable, so no labels applied
	}
	else if "`status'" == "failed" & "`lblmissing'" != "" {
		local msg `msg'; label table `database'.`labelschema'.`labeltable' lacks columns of its layout, so no labels applied
	}
	else if "`status'" == "failed" {
		local msg `msg'; label query failed, so no labels applied
	}
	else if "`types'" != "" {
		local msg `msg'; value-label sets `n_vallabels', variable labels `n_varlabels', display formats `n_formats', variable notes `n_varnotes', dataset notes `n_dtanotes', label rows skipped `n_skipped'
		if `oldlayout' local msg `msg'; labels from `database'.`labelschema'.`labeltable'
	}
	display as text `"(`msg')"'

	return local settings `"`settings'"'
	return local description `"`macval(description)'"'
	return local datetimes = cond(`dttext', "text", "number")
	return local unicode `unicols'
	return local labels `labels'
	return local dropped `"`dropped'"'
	return local linkkeys `lkeys'
	return local links `links'
	return local converted `converted'
	return local labelstatus `status'
	return local sql `"`sql'"'
	return local table `"`source'"'
	return local database `"`database'"'
	return local server `"`server'"'
	return local frame `target'
	return scalar n_skipped = `n_skipped'
	return scalar n_dtanotes = `n_dtanotes'
	return scalar n_varnotes = `n_varnotes'
	return scalar n_formats = `n_formats'
	return scalar n_varlabels = `n_varlabels'
	return scalar n_vallabels = `n_vallabels'
	return scalar k = `k'
	return scalar N = `N'
end


* Resolves the target frame without creating it. Returns r(frame) and
* r(create), which is 1 if the frame does not exist yet.
program define _sqldta_target, rclass
	version 16
	args frame clear

	if `"`frame'"' == "" local frame `c(frame)'
	else confirm name `frame'

	local create 0
	capture frame `frame': local hasdata = c(N) > 0 | c(k) > 0
	if _rc {
		local create 1
		local hasdata 0
	}
	if `hasdata' & "`clear'" == "" {
		display as error "frame `frame' already holds data; specify clear to replace it"
		error 4
	}

	return local frame `frame'
	return scalar create = `create'
end


* Splits name, given as table or schema.table, into r(schema) and r(table).
* A name without a schema gets defschema. Stops with error 198, naming what
* in the message, if a part is empty or the name has more than one dot.
program define _sqldta_split, rclass
	version 16
	args name defschema what

	local dot = strpos(`"`name'"', ".")
	if `dot' {
		local schema = substr(`"`name'"', 1, `dot' - 1)
		local table = substr(`"`name'"', `dot' + 1, .)
	}
	else {
		local schema `"`defschema'"'
		local table `"`name'"'
	}
	if `"`schema'"' == "" | `"`table'"' == "" | strpos(`"`table'"', ".") {
		display as error `"`what' must be table or schema.table, without the database: `name'"'
		exit 198
	}
	return local schema `"`schema'"'
	return local table `"`table'"'
end


* Reads the argument of labels(): all (the default), none, or any of the
* keywords values, variables, formats, varnotes, dtanotes and datalabel, in
* any case. Returns r(labels), the keywords in a fixed order, and r(types),
* the PropertyType of each: ValueLabel, VariableLabel, VariableFormat,
* VariableNote, DatasetNote and DatasetLabel.
program define _sqldta_labeltypes, rclass
	version 16
	args spec

	local keys values variables formats varnotes dtanotes datalabel
	local ltypes ValueLabel VariableLabel VariableFormat VariableNote DatasetNote DatasetLabel
	local spec = ustrlower(`"`spec'"')
	local nw : word count `spec'
	if `nw' == 0 | `"`spec'"' == "all" local spec `keys'
	else if `"`spec'"' == "none" local spec
	else {
		foreach w of local spec {
			if inlist(`"`w'"', "all", "none") {
				display as error "labels(): `w' cannot be combined with other label types"
				exit 198
			}
			if !`: list w in keys' {
				display as error `"labels(): `w' is not a label type; use all, none, or any of `keys'"'
				exit 198
			}
		}
	}

	local labels
	local types
	forvalues i = 1/6 {
		local k : word `i' of `keys'
		if `: list k in spec' {
			local labels `labels' `k'
			local types `types' `: word `i' of `ltypes''
		}
	}
	return local labels `labels'
	return local types `types'
end


* Returns r(qname), the bracketed name [database].[schema].[table].
program define _sqldta_qname, rclass
	version 16
	args database schema table

	foreach x in database schema table {
		local `x' : subinstr local `x' "]" "]]", all
	}
	return local qname `"[`database'].[`schema'].[`table']"'
end


* Checks for the label table and its columns, and reads its Link rows for the
* table dataset in the schema defschema. Stops on a failed query, because a
* missed link would load the data only in part. A linked table named without a
* schema is in defschema too. fbschema and fbtable, when given, name a label
* table of the predecessor's layout, whose rows are filed by the table's name
* alone, which is read when the label table is not found; the same query
* checks both, so that the fallback costs no query of its own. Returns
* r(found), r(old) (1 when the fallback is read), r(missing) (the columns of
* the layout that the label table read lacks, separated by commas; no Link
* rows are read then), r(nlinks) and the lists r(keys), r(schemas) and
* r(tables).
program define _sqldta_meta, rclass
	version 16
	args server database schema table dataset defschema fbschema fbtable

	local dslit : subinstr local dataset "'" "''", all
	local sclit : subinstr local defschema "'" "''", all
	local qdb : subinstr local database "]" "]]", all

	* Whether each label table exists, and whether it has each column of its
	* layout, from sys.all_columns, which also covers views. The DataType
	* column of the predecessor's layout is not read.
	local layout1 TableSchema TableName ColumnName PropertyType PropertyCode PropertyText
	local layout2 Dataset VarName LabelType DataCode LabelName
	_sqldta_qname `"`database'"' `"`schema'"' `"`table'"'
	local qtable1 `"`r(qname)'"'
	local object1 `schema'.`table'
	local fb = `"`fbtable'"' != ""
	if `fb' {
		_sqldta_qname `"`database'"' `"`fbschema'"' `"`fbtable'"'
		local qtable2 `"`r(qname)'"'
		local object2 `fbschema'.`fbtable'
	}
	local sql SELECT
	local sep
	forvalues i = 1/`=1 + `fb'' {
		local qlit : subinstr local qtable`i' "'" "''", all
		local sql `sql'`sep' CASE WHEN OBJECT_ID(N'`qlit'') IS NULL THEN 0 ELSE 1 END AS found`i'
		local sep ,
		foreach c of local layout`i' {
			local sql `sql', (SELECT COUNT(*) FROM [`qdb'].sys.all_columns ///
				WHERE object_id = OBJECT_ID(N'`qlit'') AND name = N'`c'') AS has`i'`c'
		}
	}
	tempname f
	frame create `f'
	_sqldta_odbc `f' `"`server'"' `"`database'"' `"`object1'"' `"`sql'"'
	if r(rc) {
		local rc = r(rc)
		exit `rc'
	}
	local i 1
	frame `f': local found = found1[1]
	if !`found' & `fb' {
		frame `f': local found = found2[1]
		if `found' local i 2
	}
	local old = `i' == 2
	local qtable `"`qtable`i''"'
	local object `object`i''
	local missing
	local sep
	if `found' {
		foreach c of local layout`i' {
			frame `f': local has = has`i'`c'[1]
			if `has' == 0 {
				local missing `missing'`sep'`c'
				local sep ", "
			}
		}
	}
	return scalar found = `found'
	return scalar old = `old'
	return local missing `missing'
	return scalar nlinks = 0
	if `found' == 0 | "`missing'" != "" exit

	* Rows of the predecessor's layout are selected with plain literals, as
	* the predecessor did: its columns are varchar, and under a SQL collation
	* an index on a varchar column cannot serve a comparison with N'...'
	if `old' {
		local sql SELECT DISTINCT LTRIM(RTRIM(CAST(VarName AS nvarchar(128)))) AS ColumnName, ///
			LTRIM(RTRIM(CAST(LabelName AS nvarchar(300)))) AS PropertyText ///
			FROM `qtable' WHERE Dataset = '`dslit'' AND LabelType = 'Link' ORDER BY PropertyText
	}
	else {
		local sql SELECT DISTINCT LTRIM(RTRIM(CAST(ColumnName AS nvarchar(128)))) AS ColumnName, ///
			LTRIM(RTRIM(CAST(PropertyText AS nvarchar(300)))) AS PropertyText ///
			FROM `qtable' WHERE TableSchema = N'`sclit'' AND TableName = N'`dslit'' ///
			AND PropertyType = N'Link' ORDER BY PropertyText
	}
	_sqldta_odbc `f' `"`server'"' `"`database'"' `"`object'"' `"`sql'"'
	if r(rc) {
		local rc = r(rc)
		exit `rc'
	}

	frame `f': local n = _N
	local keys
	local schemas
	local tables
	forvalues i = 1/`n' {
		frame `f' {
			local k = ColumnName[`i']
			local name = PropertyText[`i']
		}
		if !ustrregexm(`"`k'"', "^[\p{L}_][\p{L}\p{N}_]{0,31}$") {
			display as error `"sqldta: the Link row for `name' names the key "`k'", which is not a valid Stata name"'
			exit 459
		}
		local dot = strpos(`"`name'"', ".")
		if `dot' {
			local s = substr(`"`name'"', 1, `dot' - 1)
			local t = substr(`"`name'"', `dot' + 1, .)
		}
		else {
			local s `defschema'
			local t `name'
		}
		if `"`s'"' == "" | `"`t'"' == "" | strpos(`"`t'"', ".") | strpos(`"`s'`t'"', " ") {
			display as error `"sqldta: the Link row "`name'" must name the linked table as table or schema.table, without spaces"'
			exit 459
		}
		local keys `keys' `k'
		local schemas `schemas' `s'
		local tables `tables' `t'
	}
	return scalar nlinks = `n'
	return local keys `keys'
	return local schemas `schemas'
	return local tables `tables'
end


* Lists the columns of the main table (order 0) and each linked table (order
* 1, 2 and so on) from sys.all_columns, which also covers views and system
* views. The argument values holds the (order, OBJECT_ID(...)) pairs and keys the key of
* each linked table. Columns whose names are not valid Stata names are left
* out, as is a linked table's key and any column that an earlier table already
* has. Returns r(rc), r(cols), r(kinds) (str, num, date, dt for date-times,
* time or other), r(sqltypes) (the SQL type of each column, in lower case),
* r(maxlens), r(precs) and r(scales) (its max_length in bytes, -1 for max,
* precision and scale), r(owners), r(lall) (every valid column name in lower
* case), r(invalid), r(dupcols), r(dupowners), r(mainall), r(counts), r(nokey)
* and r(nokeymain).
program define _sqldta_columns, rclass
	version 16
	args server database values keys

	* hierarchyid, geometry and geography share system_type_id 240, which has
	* no type name, so their name is taken from user_type_id. Other columns
	* use system_type_id, which gives the base type of an alias type and
	* names the same type in every database.
	local qdb : subinstr local database "]" "]]", all
	local sql SELECT x.ord AS tableorder, CAST(c.name AS nvarchar(128)) AS COLUMN_NAME, ///
		CAST(CASE WHEN c.system_type_id = 240 AND c.user_type_id IN (128, 129, 130) ///
		THEN TYPE_NAME(c.user_type_id) ELSE TYPE_NAME(c.system_type_id) END AS nvarchar(128)) AS DATA_TYPE, ///
		CAST(c.max_length AS int) AS MAX_LENGTH, CAST(c.[precision] AS int) AS PREC, ///
		CAST(c.scale AS int) AS SCALE ///
		FROM [`qdb'].sys.all_columns AS c ///
		JOIN (VALUES `values') AS x(ord, id) ON c.object_id = x.id ///
		ORDER BY x.ord, c.column_id

	tempname f
	frame create `f'
	_sqldta_odbc `f' `"`server'"' `"`database'"' "sys.all_columns" `"`sql'"'
	local rc = r(rc)
	return scalar rc = `rc'
	if `rc' exit

	local nlinks : word count `keys'
	forvalues o = 0/`nlinks' {
		local cnt`o' 0
		local keyin`o' 0
	}
	local reserved _all _b byte _coef _cons double float if in int long _n _N _pi _pred _rc _skip strL using with

	local cols
	local lcols
	local kinds
	local sqltypes
	local maxlens
	local precs
	local scales
	local owners
	local lall
	local lmain
	local invalid
	local isep
	local dupcols
	local dupowners
	local mainall 1

	frame `f': local n = _N
	forvalues i = 1/`n' {
		frame `f' {
			local o = tableorder[`i']
			local c = COLUMN_NAME[`i']
			local t = ustrlower(DATA_TYPE[`i'])
			local ml = MAX_LENGTH[`i']
			local pr = PREC[`i']
			local sc = SCALE[`i']
		}
		if "`t'" == "" local t unknown
		local ++cnt`o'
		local lc = ustrlower(`"`c'"')

		if `o' > 0 {
			local k : word `o' of `keys'
			if `"`lc'"' == ustrlower("`k'") {
				local keyin`o' 1
				continue
			}
		}

		local ok = ustrregexm(`"`c'"', "^[\p{L}_][\p{L}\p{N}_]{0,31}$")
		if `ok' {
			if `: list posof `"`c'"' in reserved' | ustrregexm(`"`c'"', "^str[0-9]+$") local ok 0
		}
		if !`ok' {
			local invalid `"`invalid'`isep'`c'"'
			local isep ", "
			if `o' == 0 local mainall 0
			continue
		}

		local lall `lall' `lc'
		if `o' == 0 local lmain `lmain' `lc'
		if `: list lc in lcols' {
			if `o' > 0 {
				local dupcols `dupcols' `c'
				local dupowners `dupowners' `o'
			}
			continue
		}

		* text and ntext are other, because SQL Server cannot compare them
		* with = or pass them to LOWER(), which the if qualifier needs
		if inlist("`t'", "char", "varchar", "nchar", "nvarchar", "sysname") local kind str
		else if "`t'" == "date" local kind date
		else if inlist("`t'", "datetime", "datetime2", "smalldatetime", "datetimeoffset") local kind dt
		else if "`t'" == "time" local kind time
		else if inlist("`t'", "tinyint", "smallint", "int", "bigint", "bit", "decimal", "numeric", "float", "real") ///
			| inlist("`t'", "money", "smallmoney") local kind num
		else local kind other

		local cols `cols' `c'
		local lcols `lcols' `lc'
		local kinds `kinds' `kind'
		local sqltypes `sqltypes' `t'
		local maxlens `maxlens' `ml'
		local precs `precs' `pr'
		local scales `scales' `sc'
		local owners `owners' `o'
	}

	local counts
	local nokey
	local nokeymain
	forvalues o = 0/`nlinks' {
		local counts `counts' `cnt`o''
		if `o' > 0 {
			local lk = ustrlower("`: word `o' of `keys''")
			if !`: list lk in lmain' local nokeymain `nokeymain' `o'
			if !`keyin`o'' local nokey `nokey' `o'
		}
	}

	return local cols `cols'
	return local kinds `kinds'
	return local sqltypes `sqltypes'
	return local maxlens `maxlens'
	return local precs `precs'
	return local scales `scales'
	return local owners `owners'
	return local lall `lall'
	return local invalid `"`invalid'"'
	return local dupcols `dupcols'
	return local dupowners `dupowners'
	return scalar mainall = `mainall'
	return local counts `counts'
	return local nokey `nokey'
	return local nokeymain `nokeymain'
end


* Resolves sqlselect(), and unicode() in the same way: names separated by
* spaces or commas, with the wildcards * and ?, matched without regard to
* case against the columns. A column matched by name is loaded under the name
* as typed; one matched by a wildcard keeps its own name. opt names the option
* in the messages. Returns r(names), the names loaded, and r(positions), the
* position of each in cols.
program define _sqldta_select, rclass
	version 16
	args spec cols object opt

	local spec : subinstr local spec "," " ", all
	local lcols
	foreach c of local cols {
		local lcols `lcols' `=ustrlower("`c'")'
	}

	local names
	local lnames
	local positions
	foreach tok of local spec {
		local ltok = ustrlower(`"`tok'"')
		if strpos(`"`tok'"', "*") | strpos(`"`tok'"', "?") {
			local found 0
			local j 0
			foreach c of local cols {
				local ++j
				local lc : word `j' of `lcols'
				if strmatch("`lc'", `"`ltok'"') {
					local found 1
					if !`: list lc in lnames' {
						local names `names' `c'
						local lnames `lnames' `lc'
						local positions `positions' `j'
					}
				}
			}
			if !`found' {
				display as error `"`opt': no column of `object' matches `tok'"'
				exit 111
			}
		}
		else {
			local pos : list posof `"`ltok'"' in lcols
			if `pos' == 0 {
				display as error `"`opt': column `tok' not found in `object'"'
				exit 111
			}
			if !`: list ltok in lnames' {
				local names `names' `tok'
				local lnames `lnames' `ltok'
				local positions `positions' `pos'
			}
		}
	}

	return local names `names'
	return local positions `positions'
end


* Builds the SQL column list for the columns at positions in cols, loaded
* under names. Each column is bracketed, and aliased when its name is loaded
* in another case; a column whose type odbc load mishandles is sent as the
* expression from _sqldta_colexpr, aliased to its name. The char, varchar and
* text columns at positions upos are sent as Unicode, and dttext is 1 when
* date-times are sent as text. Returns r(select), r(expr), which is 1 if any
* column is sent as an expression, and r(unicode), the names of the columns
* sent as Unicode.
program define _sqldta_selectlist, rclass
	version 16
	args positions names cols sqltypes maxlens precs scales upos dttext

	local select
	local sep
	local expr 0
	local unicode
	local j 0
	foreach pos of local positions {
		local ++j
		local n : word `j' of `names'
		local c : word `pos' of `cols'
		local t : word `pos' of `sqltypes'
		local uni : list pos in upos
		_sqldta_colexpr "`t'" "`: word `pos' of `maxlens''" ///
			"`: word `pos' of `precs''" "`: word `pos' of `scales''" "[`c']" `uni' `dttext'
		if `"`r(expr)'"' != "" {
			local select `select'`sep'`r(expr)' AS [`n']
			local expr 1
		}
		else if "`c'" == "`n'" local select `select'`sep'[`c']
		else local select `select'`sep'[`c'] AS [`n']
		if `uni' & inlist("`t'", "char", "varchar", "text") local unicode `unicode' `n'
		local sep ", "
	}

	return local select `"`select'"'
	return local unicode `unicode'
	return scalar expr = `expr'
end


* Returns r(expr), the expression that sends a column of SQL type t, with
* max_length len, precision prec and scale scale, in a form that odbc load
* reads correctly, or nothing if the column can be sent as it is. ref is the
* bracketed column name; uni is 1 when the column is named in unicode(), and
* dttext is 1 when the site global SQLDTA_DTTEXT asks for date-times as text.
*   - Date-times as a number of milliseconds since 01jan1960, which odbc load
*     reads as a double and _sqldta_convert formats as %tc. The number is the
*     value of the earlier method, the text of 23 characters that
*     CONVERT(..., 121) gives: datetime in its steps of 1/300 of a second
*     (.000, .003, .007), digits below the millisecond cut, not rounded, and
*     datetime2 and datetimeoffset values before 01jan0100 missing. It is
*     computed without that text, which cost more than the load itself on
*     tables with several date-time columns (profile of 20 Oct 2026, at
*     archive fb4b871). For datetime2, and datetimeoffset as its clock time as stored,
*     DATEDIFF by millisecond counts the millisecond boundaries passed since
*     midnight, which cuts the digits below the millisecond. A datetime is
*     stored as two 4-byte integers, the days since 01jan1900 and the ticks of
*     1/300 of a second since midnight; (ticks * 10 + 1) / 3, in integers,
*     rounds each tick to the nearest millisecond, as SQL Server shows it,
*     whatever the compatibility level (DATEDIFF by millisecond would count
*     .00667 s as 6 from level 130). Every value is a whole number below 2^53,
*     which a double holds exactly. With dttext, the text itself is sent and
*     _sqldta_convert converts it with clock(). odbc load drops the
*     milliseconds itself.
*   - time as milliseconds since midnight; odbc load skips time columns.
*   - uniqueidentifier, xml, hierarchyid, geography, geometry and sql_variant
*     as text, and the binary types as hexadecimal text, 0x...
*   - char, varchar and text as they are, so that characters outside ASCII
*     arrive as the bytes of the column's code page; char without its
*     trailing padding. Those named in unicode() as Unicode, so that such
*     characters arrive as valid UTF-8, which costs time (benchmark of 19 Oct
*     2026). nchar without its trailing padding.
*   - decimal and numeric with precision over 15 as text, which
*     _sqldta_convert converts itself: the legacy "SQL Server" driver rounds
*     them to about 15 significant digits, where ODBC Driver 18 gives the
*     nearest double.
program define _sqldta_colexpr, rclass
	version 16
	args t len prec scale ref uni dttext
	if "`uni'" == "" local uni 0
	if "`dttext'" == "" local dttext 0

	local e
	if inlist("`t'", "datetime", "datetime2", "smalldatetime", "datetimeoffset") {
		local x `ref'
		if "`t'" == "datetimeoffset" local x CAST(`ref' AS datetime2(7))
		if `dttext' local e CONVERT(varchar(23), `x', 121)
		else if "`t'" == "datetime" {
			local e CAST(DATEDIFF(day, CAST('19600101' AS datetime), `x') AS float) * 86400000 ///
				+ (CAST(SUBSTRING(CAST(`x' AS binary(8)), 5, 4) AS int) * 10 + 1) / 3
		}
		else {
			if "`t'" == "smalldatetime" local x CAST(`ref' AS datetime2(7))
			local e CAST(DATEDIFF(day, CAST('19600101' AS datetime2(7)), `x') AS float) * 86400000 ///
				+ DATEDIFF(millisecond, CAST(CAST(`x' AS date) AS datetime2(7)), `x')
			if inlist("`t'", "datetime2", "datetimeoffset") {
				local e CASE WHEN `x' >= CAST(N'0100-01-01' AS datetime2) THEN `e' END
			}
		}
	}
	else if "`t'" == "time" {
		local e DATEDIFF(millisecond, CAST('00:00:00' AS time), `ref')
	}
	else if inlist("`t'", "char", "varchar") {
		if `uni' {
			if `len' > 0 & `len' <= 4000 local e CONVERT(nvarchar(`len'), `ref')
			else local e CONVERT(nvarchar(max), `ref')
			if "`t'" == "char" local e RTRIM(`e')
		}
		else if "`t'" == "char" local e RTRIM(`ref')
	}
	else if "`t'" == "nchar" local e RTRIM(`ref')
	else if "`t'" == "text" {
		if `uni' local e CONVERT(nvarchar(max), `ref')
	}
	else if "`t'" == "xml" local e CONVERT(nvarchar(max), `ref')
	else if "`t'" == "uniqueidentifier" local e CONVERT(char(36), `ref')
	else if "`t'" == "hierarchyid" local e `ref'.ToString()
	else if inlist("`t'", "geography", "geometry") local e `ref'.STAsText()
	else if "`t'" == "sql_variant" local e CONVERT(nvarchar(4000), `ref')
	else if inlist("`t'", "binary", "varbinary") {
		if `len' > 0 & 2 * `len' + 2 <= 8000 local e CONVERT(varchar(`=2 * `len' + 2'), `ref', 1)
		else local e CONVERT(varchar(max), CAST(`ref' AS varbinary(max)), 1)
	}
	else if "`t'" == "image" local e CONVERT(varchar(max), CAST(`ref' AS varbinary(max)), 1)
	else if "`t'" == "timestamp" local e CONVERT(varchar(18), CAST(`ref' AS binary(8)), 1)
	else if inlist("`t'", "decimal", "numeric") {
		if `prec' > 15 local e CONVERT(varchar(41), `ref')
	}

	return local expr `"`e'"'
end


* Builds the data query from the FROM clause, the column list, the WHERE
* condition and sqlrand(). Returns r(sql).
program define _sqldta_sql, rclass
	version 16
	args from select where rand

	local sql SELECT
	if "`rand'" != "" local sql `sql' TOP (`rand')
	local sql `"`sql' `select' FROM `from'"'
	if `"`where'"' != "" local sql `"`sql' WHERE `where'"'
	if "`rand'" != "" local sql `"`sql' ORDER BY NEWID()"'

	return local sql `"`sql'"'
end


* Stops with error 459 if the key repeats in a linked table, because only 1:1
* links are supported. Missing keys are ignored; they match no row.
program define _sqldta_keycheck
	version 16
	args server database qlink object key

	tempname f
	frame create `f'
	local sql SELECT COUNT(*) AS repeats FROM (SELECT TOP (1) [`key'] AS k FROM `qlink' ///
		WHERE [`key'] IS NOT NULL GROUP BY [`key'] HAVING COUNT(*) > 1) AS d
	_sqldta_odbc `f' `"`server'"' `"`database'"' `"`object'"' `"`sql'"'
	if r(rc) {
		local rc = r(rc)
		exit `rc'
	}
	frame `f': local repeats = repeats[1]
	if `repeats' > 0 {
		display as error "sqldta: key `key' repeats in linked table `object'; only 1:1 links are supported"
		exit 459
	}
end


* Every odbc load goes through _sqldta_odbc, which is in its own file,
* _sqldta_odbc.ado, because the dialog helper sqldta_dlg.ado uses it too.


* Returns r(vars), the variable names of a frame, and r(lvars), the same names
* in lower case and in the same order, for case-insensitive matching.
program define _sqldta_varnames, rclass
	version 16
	args target

	frame `target': local k = c(k)
	if `k' == 0 exit

	frame `target': unab vars : _all
	local lvars
	foreach v of local vars {
		local lvars `lvars' `=ustrlower("`v'")'
	}
	return local vars `vars'
	return local lvars `lvars'
end


* Converts columns that were loaded as strings and sets display formats. The
* SQL types, precisions and scales come from the column query.
*   - date columns, which the legacy "SQL Server" ODBC driver returns as
*     strings, become Stata dates with %td.
*   - Date-time columns, which _sqldta_colexpr sends as numbers of
*     milliseconds, get %tc; with the site global SQLDTA_DTTEXT they are sent
*     as text and become %tc through clock(), and values before 01jan0100,
*     Stata's earliest date, become missing. Either way they are listed in
*     r(converted).
*   - time columns, which arrive as milliseconds since midnight, get
*     %tcHH:MM:SS.sss.
*   - bigint columns, which odbc load returns as strings with every driver,
*     and decimal and numeric columns with scale 0 and precision over 15,
*     which _sqldta_colexpr sends as text, become numbers if every value
*     loaded can be held exactly in a double, which holds every integer up to
*     2^53; otherwise they stay strings, with a note.
*   - decimal and numeric columns with a scale above 0 and precision over 15,
*     which _sqldta_colexpr sends as text, become doubles with %10.0g.
*   - Other decimal and numeric columns get %(p+2).(s)f for precision p of 15
*     or less and scale s, unless decformat holds nodecformat.
* VariableFormat rows in the label table are applied later and so override
* these formats. Returns r(converted), the columns converted from strings, and
* the date-time columns.
program define _sqldta_convert, rclass
	version 16
	args target cols sqltypes precs scales decformat

	_sqldta_varnames `target'
	local vars `r(vars)'
	local lvars `r(lvars)'
	local lcols
	foreach c of local cols {
		local lcols `lcols' `=ustrlower("`c'")'
	}

	local converted
	local inexact
	local j 0
	foreach v of local vars {
		local ++j
		local lv : word `j' of `lvars'
		local pos : list posof "`lv'" in lcols
		if `pos' == 0 continue
		local sqltype : word `pos' of `sqltypes'
		local p : word `pos' of `precs'
		local s : word `pos' of `scales'
		frame `target': local t : type `v'
		local isstr = substr("`t'", 1, 3) == "str"
		local decimal = inlist("`sqltype'", "decimal", "numeric")
		local wide = `decimal' & `p' > 15

		if "`sqltype'" == "time" {
			if !`isstr' frame `target': format `v' %tcHH:MM:SS.sss
			continue
		}
		if `decimal' & !`wide' {
			if !`isstr' & "`decformat'" == "" & `p' <= 15 {
				frame `target': format `v' %`=`p' + 2'.`s'f
			}
			continue
		}
		local kind
		if "`sqltype'" == "date" local kind date
		else if inlist("`sqltype'", "datetime", "datetime2", "smalldatetime", "datetimeoffset") local kind clock
		else if "`sqltype'" == "bigint" | (`wide' & `s' == 0) local kind integer
		else if `wide' local kind real
		if "`kind'" == "clock" & !`isstr' {
			frame `target': format `v' %tc
			local converted `converted' `v'
			continue
		}
		if "`kind'" == "" | !`isstr' continue

		tempvar d
		if "`kind'" == "date" {
			frame `target' {
				quietly generate long `d' = date(`v', "YMD")
				format `d' %td
			}
		}
		else if "`kind'" == "clock" {
			frame `target' {
				quietly generate double `d' = clock(`v', "YMDhms")
				format `d' %tc
			}
		}
		else if "`kind'" == "real" {
			frame `target' {
				quietly generate double `d' = real(`v')
				format `d' %10.0g
			}
		}
		else {
			frame `target' {
				quietly generate double `d' = real(`v')
				quietly count if `v' != "" & string(`d', "%21.0f") != `v'
				local bad = r(N)
			}
			if `bad' > 0 {
				frame `target': drop `d'
				local inexact `inexact' `v'
				continue
			}
		}
		frame `target' {
			order `d', before(`v')
			drop `v'
			rename `d' `v'
		}
		if "`kind'" == "integer" {
			* The smallest type that holds the values, and a format that shows
			* every digit
			frame `target' {
				quietly compress `v'
				local t : type `v'
				if "`t'" == "double" format `v' %20.0g
				else format `v' %12.0g
			}
		}
		local converted `converted' `v'
	}
	if "`inexact'" != "" {
		display as text "note: columns left as strings, because they hold whole numbers too large to be stored exactly as numbers: `inexact'"
	}
	return local converted `converted'
end


* Fetches the label rows of the table dataset in the schema dschema and of its
* linked tables, the tables ltables in the schemas lschemas, each filed under
* its own schema and name, and applies them to the target frame. old is 1 for
* a label table of the predecessor's layout, whose rows are filed by the
* table's name alone. Returns r(status) (applied or failed), r(description)
* and, when applied, the counts from _sqldta_apply.
program define _sqldta_labels, rclass
	version 16
	args target server database schema table dschema dataset lschemas ltables types allcols old

	_sqldta_qname `"`database'"' `"`schema'"' `"`table'"'
	local qtable `"`r(qname)'"'
	local object `schema'.`table'

	* The rows of each table, by its schema and name
	local tables
	local n : word count `ltables'
	forvalues i = 0/`n' {
		if `i' == 0 {
			local s `"`dschema'"'
			local t `"`dataset'"'
		}
		else {
			local s : word `i' of `lschemas'
			local t : word `i' of `ltables'
		}
		local s : subinstr local s "'" "''", all
		local t : subinstr local t "'" "''", all
		if `i' > 0 local tables `tables' OR
		if `old' local tables `tables' Dataset = '`t''
		else local tables `tables' (TableSchema = N'`s'' AND TableName = N'`t'')
	}

	* One query for all requested label types. Format and DataLabel, the
	* names of VariableFormat and DatasetLabel in sqldta 1.0.0, are read as
	* well, so that label tables made for it keep working. A label table of
	* the predecessor's layout may hold its types as well as these, and they
	* are read as these: Opt, Var, NoteVar, NoteDta and DtaLabel. Its rows are
	* selected with plain literals, for the reason given in _sqldta_meta.
	local alt_VariableFormat Format
	local alt_DatasetLabel DataLabel
	if `old' {
		local alt_ValueLabel Opt
		local alt_VariableLabel Var
		local alt_VariableNote NoteVar
		local alt_DatasetNote NoteDta
		local alt_DatasetLabel DataLabel DtaLabel
	}
	local where
	foreach t of local types {
		foreach w in `t' `alt_`t'' {
			if `"`where'"' != "" local where `where' OR
			if `old' local where `where' LabelType = '`w''
			else local where `where' PropertyType = N'`w''
		}
	}

	* The DatasetDescription rows of the table loaded, but not of its linked
	* tables, come in the same query. They are not applied to the data: the
	* text of the one whose PropertyCode is 1 is returned in r(description),
	* which the dialog shows.
	local s : subinstr local dschema "'" "''", all
	local t : subinstr local dataset "'" "''", all
	if `old' local desc Dataset = '`t'' AND LabelType = 'DatasetDescription'
	else local desc TableSchema = N'`s'' AND TableName = N'`t'' AND PropertyType = N'DatasetDescription'

	if `old' {
		local sql SELECT DISTINCT ///
			LTRIM(RTRIM(CAST(VarName AS nvarchar(128)))) AS ColumnName, ///
			LTRIM(RTRIM(CAST(CASE LabelType WHEN N'Opt' THEN N'ValueLabel' ///
				WHEN N'Var' THEN N'VariableLabel' WHEN N'NoteVar' THEN N'VariableNote' ///
				WHEN N'NoteDta' THEN N'DatasetNote' WHEN N'DtaLabel' THEN N'DatasetLabel' ///
				ELSE LabelType END AS nvarchar(128)))) AS PropertyType, ///
			LTRIM(RTRIM(CAST(DataCode AS nvarchar(50)))) AS PropertyCode, ///
			CAST(LabelName AS nvarchar(max)) AS PropertyText ///
			FROM `qtable' ///
			WHERE DATALENGTH(LabelName) > 0 AND (((`tables') AND (`where')) OR (`desc'))
	}
	else {
		local sql SELECT DISTINCT ///
			LTRIM(RTRIM(CAST(ColumnName AS nvarchar(128)))) AS ColumnName, ///
			LTRIM(RTRIM(CAST(PropertyType AS nvarchar(128)))) AS PropertyType, ///
			LTRIM(RTRIM(CAST(PropertyCode AS nvarchar(50)))) AS PropertyCode, ///
			CAST(PropertyText AS nvarchar(max)) AS PropertyText ///
			FROM `qtable' ///
			WHERE DATALENGTH(PropertyText) > 0 AND (((`tables') AND (`where')) OR (`desc'))
	}

	tempname f
	frame create `f'
	_sqldta_odbc `f' `"`server'"' `"`database'"' `"`object'"' `"`sql'"'
	if r(rc) {
		display as text "note: the label query failed; no labels applied"
		return local status failed
		exit
	}

	* The DatasetDescription rows are taken out before the others are applied
	local description
	frame `f': local n = _N
	if `n' > 0 {
		frame `f' {
			tempvar isdesc
			quietly generate byte `isdesc' = ustrlower(PropertyType) == "datasetdescription"
			mata: _sqldta_desc("`isdesc'")
			quietly drop if `isdesc'
			local n = _N
		}
	}
	return local description `"`macval(description)'"'

	if `n' > 0 {
		* Notes that have a PropertyCode come first, in PropertyCode order:
		* numeric if every code of that variable's notes is a number, otherwise
		* as text. Notes without a PropertyCode follow in the order SQL Server
		* returned them.
		frame `f' {
			tempvar row note grp nocode allnum k1 k2
			quietly generate long `row' = _n
			quietly generate byte `note' = inlist(ustrlower(PropertyType), "variablenote", "datasetnote")
			quietly generate `grp' = cond(ustrlower(PropertyType) == "variablenote", ustrlower(ColumnName), "")
			quietly generate byte `nocode' = PropertyCode == ""
			quietly generate double `k1' = real(PropertyCode)
			quietly bysort `note' `grp': egen byte `allnum' = min(`k1' < . | `nocode')
			quietly replace `k1' = . if !`allnum'
			quietly generate `k2' = cond(`allnum', "", PropertyCode)
			sort `note' `grp' `nocode' `k1' `k2' `row'
		}
		_sqldta_apply `f' `target' "`allcols'"
		return add
	}
	else {
		foreach s in vallabels varlabels formats varnotes dtanotes skipped {
			return scalar n_`s' = 0
		}
	}
	return local status applied
end


* Applies the label rows held in frame lbl to frame target. A row for a column
* that exists in the table but was not loaded is passed over, as is a
* ValueLabel row for a variable that is a string in Stata, which cannot take
* value labels; a row that names no column of the table, or whose application
* fails, counts as skipped.
* The time grows with the label rows alone (rewritten on 20 Oct 2026, after
* the benchmark of 19 Oct 2026 showed the earlier loop, which switched frames
* and searched lists of every variable for each row, taking seconds on a wide
* table with many value-label rows). _sqldta_lblprep, in Mata,
* matches each row to its variable through an associative array and sets,
* with one st_vlmodify() for each variable, the value labels of the
* ValueLabel rows that label define is sure to accept; every other row is
* applied here, in its order, with the commands that sqldta has always used,
* so that what is applied, skipped and counted does not change.
* Returns r(n_vallabels), r(n_varlabels), r(n_formats), r(n_varnotes),
* r(n_dtanotes) and r(n_skipped).
program define _sqldta_apply, rclass
	version 16
	args lbl target allcols

	_sqldta_varnames `target'
	local vars `r(vars)'
	local lvars `r(lvars)'
	frame `target': quietly ds, has(type string)
	local strvars `r(varlist)'

	* Sets the locals _sqldta_nskip (rows skipped so far), _sqldta_vlsets (the
	* variables whose value labels it set) with _sqldta_nopt1, _sqldta_nopt2 and
	* so on (the ValueLabel rows of each), and _sqldta_k, the number of rows
	* left to apply, with the type, variable, code and text of each in
	* _sqldta_t1, _sqldta_v1, _sqldta_c1, _sqldta_x1 and so on
	frame `lbl': mata: _sqldta_lblprep("`target'", st_local("vars"), st_local("lvars"), ///
		st_local("strvars"), st_local("allcols"))

	local n_varlabels 0
	local n_formats 0
	local n_varnotes 0
	local n_dtanotes 0
	local n_skipped = `_sqldta_nskip'
	local vlsets `_sqldta_vlsets'
	local m 0
	foreach v of local vlsets {
		local ++m
		local n_opt`m' = `_sqldta_nopt`m''
	}

	forvalues j = 1/`_sqldta_k' {
		local type `_sqldta_t`j''
		local v `_sqldta_v`j''

		if "`type'" == "valuelabel" {
			capture frame `target': label define `v' `_sqldta_c`j'' `"`macval(_sqldta_x`j')'"', modify
			if _rc {
				local ++n_skipped
			}
			else {
				local m : list posof "`v'" in vlsets
				if `m' {
					local ++n_opt`m'
				}
				else {
					local vlsets `vlsets' `v'
					local m : word count `vlsets'
					local n_opt`m' 1
				}
			}
		}
		else if "`type'" == "variablelabel" {
			capture frame `target': label variable `v' `"`macval(_sqldta_x`j')'"'
			if _rc local ++n_skipped
			else local ++n_varlabels
		}
		else if "`type'" == "variableformat" {
			* The text must be one valid format, so that it cannot name other
			* variables as well
			capture confirm format `macval(_sqldta_x`j')'
			if _rc {
				local ++n_skipped
				continue
			}
			capture frame `target': format `v' `macval(_sqldta_x`j')'
			if _rc local ++n_skipped
			else local ++n_formats
		}
		else if "`type'" == "datasetlabel" {
			mata: st_local("text", usubstr(st_local("_sqldta_x`j'"), 1, 80))
			capture frame `target': label data `"`macval(text)'"'
			if _rc local ++n_skipped
		}
		else {
			* VariableNote and DatasetNote rows are written as the
			* characteristics notes itself uses: the count in [note0] and the
			* text in [note1], [note2] and so on. The notes command turns a
			* standalone TS into a time stamp and fails on some text that
			* contains backquotes.
			frame `target': local nn : char `v'[note0]
			if `"`nn'"' == "" local nn 0
			local ++nn
			capture frame `target': mata: st_global("`v'[note`nn']", st_local("_sqldta_x`j'"))
			if _rc {
				local ++n_skipped
			}
			else {
				frame `target': char `v'[note0] `nn'
				if "`v'" == "_dta" local ++n_dtanotes
				else local ++n_varnotes
			}
		}
	}

	* Attach each value-label set once; a set that cannot be attached is
	* dropped and its rows count as skipped
	local n_vallabels 0
	local m 0
	foreach v of local vlsets {
		local ++m
		capture frame `target': label values `v' `v'
		if _rc {
			local n_skipped = `n_skipped' + `n_opt`m''
			frame `target': label drop `v'
		}
		else local ++n_vallabels
	}

	return scalar n_vallabels = `n_vallabels'
	return scalar n_varlabels = `n_varlabels'
	return scalar n_formats = `n_formats'
	return scalar n_varnotes = `n_varnotes'
	return scalar n_dtanotes = `n_dtanotes'
	return scalar n_skipped = `n_skipped'
end


* ---------------------------------------------------------------------------
* Translation of the if qualifier to T-SQL
*
* The translation keeps Stata's meaning: the rows loaded are the rows that
* loading everything and then keep if would leave. Missing values are greater
* than every number, as in Stata, so x > 5 also selects rows where x is NULL.
* A NULL string is treated as "", which is how odbc load returns it, and
* strings compare case-sensitively, as in Stata. Supported: column names,
* numbers, "strings", ., the relational operators, & | ! ~, parentheses,
* missing(), inlist(), inrange(), substr(), the string case and trim
* functions, year(), month(), day(), td(), tc() and dofc(). Anything else
* stops with an error that points to sqlwhere().
*
* Date-time and time columns are compared as the values that sqldta loads:
* whole milliseconds, with digits below the millisecond dropped, datetime
* values in the steps of 1/300 of a second that SQL Server shows (.000, .003
* and .007 in each 10 milliseconds), and datetime2 values before 01jan0100
* missing. A comparison with a literal becomes a comparison of the column
* itself with the nearest bound that gives the same rows, so that SQL Server
* can use an index on the column.
* ---------------------------------------------------------------------------

version 16
mata:

struct _sqldta_tok {
	string colvector ty, va
	real scalar pos
	string rowvector cols, lcols, kinds, types
}

struct _sqldta_val {
	string scalar sql, kind, str, type
	real scalar nul, lit, num
}

// kind is num, str, date, dt (a date-time column or tc()), time (a time
// column) or bool. For numbers and dates, nul is 0 if the value is never
// missing, 1 if it may be and 2 if it is the literal missing value; for
// strings, 2 marks the literal "". lit is 1 for a literal. type is the SQL
// type of a dt or time column; a datetimeoffset column is compared as its
// clock time, CAST(... AS datetime2(7)), and has the type datetime2.

// Does nothing; sqldta calls it to check that these functions are in memory
void _sqldta_present()
{
}

// Sets the local description to the text of the first DatasetDescription row
// of the current frame, marked by the variable isdesc, whose PropertyCode is
// the number 1, or to "" if there is none
void _sqldta_desc(string scalar isdesc)
{
	real colvector d, c
	string colvector x
	real scalar i

	st_local("description", "")
	d = st_data(., isdesc)
	c = strtoreal(st_sdata(., "PropertyCode"))
	x = st_sdata(., "PropertyText")
	for (i = 1; i <= rows(d); i++) {
		if (d[i] == 1 & c[i] == 1) {
			st_local("description", x[i])
			return
		}
	}
}

// Prepares the label rows of the current frame, in their order, for
// _sqldta_apply. Each row is matched to a variable of frame target without
// regard to case (vars and lvars hold its variables and the same names in
// lower case, strvars its string variables, and allcols every column of the
// table in lower case). The types Format and DataLabel, the names in sqldta
// 1.0.0, are read as VariableFormat and DatasetLabel. As in the earlier loop:
// dataset notes and the data label go to _dta; a row whose ColumnName is
// empty or names no column counts as skipped, and one for a column not loaded is passed over; a ValueLabel row
// for a string variable is passed over, and one whose PropertyCode is not a
// whole number counts as skipped; a row of another type counts as skipped. The
// ValueLabel rows that label define is sure to accept, with a code within the
// range of a long, -2,147,483,647 to 2,147,483,620 (the codes above it are
// those of the missing values of a long, and the test log of archive 717d9c3 showed
// st_vlmodify() accepting 2,147,483,647 without the label being found under
// that code), and text of at most 32,000 bytes that holds no line break, no double quote
// followed by a single quote and no backquote followed by a double quote
// (either of which would upset the compound quotes of the command), are set
// with one st_vlmodify() for each variable, the later of two rows with the
// same code winning, as with label define, modify. Every other row is left in
// locals for _sqldta_apply to run the earlier commands on, so that label
// define decides on codes outside the range of a long.
void _sqldta_lblprep(string scalar target, string scalar vars, string scalar lvars, string scalar strvars, string scalar allcols)
{
	string colvector ty, vn, dc, ln, texts
	string rowvector V, LV, SV, AC, sets
	string matrix K
	string scalar t, v, lv, x, cur, bad1, bad2
	real colvector codes
	real scalar i, j, m, n, k, nskip, code, safe
	transmorphic scalar A, S, C, Q, N

	ty = ustrlower(st_sdata(., "PropertyType"))
	vn = st_sdata(., "ColumnName")
	dc = st_sdata(., "PropertyCode")
	ln = st_sdata(., "PropertyText")
	n = rows(ty)

	V = tokens(vars)
	LV = tokens(lvars)
	SV = tokens(strvars)
	AC = tokens(allcols)
	A = asarray_create()
	for (i = 1; i <= cols(LV); i++) asarray(A, LV[i], V[i])
	S = asarray_create()
	for (i = 1; i <= cols(SV); i++) asarray(S, SV[i], 1)
	C = asarray_create()
	for (i = 1; i <= cols(AC); i++) asarray(C, AC[i], 1)

	// Q holds the text of each (variable, code) and N the ValueLabel rows of
	// each variable that are set here
	Q = asarray_create("string", 2)
	N = asarray_create()
	sets = J(1, 0, "")
	bad1 = char(34) + char(39)
	bad2 = char(96) + char(34)
	nskip = 0
	k = 0
	for (i = 1; i <= n; i++) {
		t = ty[i]
		if (t == "format") t = "variableformat"
		else if (t == "datalabel") t = "datasetlabel"
		if (t == "datasetnote" | t == "datasetlabel") v = "_dta"
		else {
			lv = ustrlower(vn[i])
			if (!asarray_contains(A, lv)) {
				if (lv == "" | !asarray_contains(C, lv)) nskip++
				continue
			}
			v = asarray(A, lv)
		}
		x = ""
		if (t == "valuelabel") {
			if (asarray_contains(S, v)) continue
			code = strtoreal(dc[i])
			if (code >= . | code != floor(code)) {
				nskip++
				continue
			}
			x = strofreal(code, "%21.0g")
			safe = code >= c("minlong") & code <= c("maxlong") & strlen(ln[i]) <= 32000
			safe = safe & !strpos(ln[i], bad1) & !strpos(ln[i], bad2)
			safe = safe & !strpos(ln[i], char(10)) & !strpos(ln[i], char(13))
			if (safe) {
				if (!asarray_contains(N, v)) {
					asarray(N, v, 0)
					sets = sets, v
				}
				asarray(Q, (v, x), ln[i])
				asarray(N, v, asarray(N, v) + 1)
				continue
			}
		}
		else if (t != "variablelabel" & t != "variableformat" & t != "datasetlabel" & t != "variablenote" & t != "datasetnote") {
			nskip++
			continue
		}
		k++
		st_local("_sqldta_t" + strofreal(k), t)
		st_local("_sqldta_v" + strofreal(k), v)
		st_local("_sqldta_c" + strofreal(k), x)
		st_local("_sqldta_x" + strofreal(k), ln[i])
	}

	// The value labels, one st_vlmodify() for each variable, in frame target
	K = asarray_keys(Q)
	if (rows(K)) {
		K = sort(K, (1, 2))
		cur = st_framecurrent()
		st_framecurrent(target)
		i = 1
		while (i <= rows(K)) {
			j = i
			while (j < rows(K)) {
				if (K[j + 1, 1] != K[i, 1]) break
				j++
			}
			codes = strtoreal(K[|i, 2 \ j, 2|])
			texts = J(j - i + 1, 1, "")
			for (m = i; m <= j; m++) texts[m - i + 1] = asarray(Q, K[m, .])
			st_vlmodify(K[i, 1], codes, texts)
			i = j + 1
		}
		st_framecurrent(cur)
	}

	for (m = 1; m <= cols(sets); m++) {
		st_local("_sqldta_nopt" + strofreal(m), strofreal(asarray(N, sets[m])))
	}
	st_local("_sqldta_vlsets", invtokens(sets))
	st_local("_sqldta_nskip", strofreal(nskip))
	st_local("_sqldta_k", strofreal(k))
}

void _sqldta_fail(string scalar msg)
{
	errprintf("if: %s\n", msg)
	errprintf("the if qualifier of sqldta supports part of Stata's expression syntax;\n")
	errprintf("see help sqldta, or give T-SQL in sqlwhere()\n")
	exit(198)
}

real scalar _sqldta_isdigit(string scalar c)
{
	return(strlen(c) == 1 && c >= "0" && c <= "9")
}

real scalar _sqldta_islower(string scalar c)
{
	return(strlen(c) == 1 && c >= "a" && c <= "z")
}

real scalar _sqldta_isname1(string scalar c)
{
	if (strlen(c) != 1) return(0)
	return((c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || c == "_" || ascii(c) >= 128)
}

real scalar _sqldta_isname(string scalar c)
{
	return(_sqldta_isname1(c) || _sqldta_isdigit(c))
}

void _sqldta_push(struct _sqldta_tok scalar t, string scalar ty, string scalar va)
{
	t.ty = t.ty \ ty
	t.va = t.va \ va
}

void _sqldta_lex(string scalar e, struct _sqldta_tok scalar t)
{
	real scalar i, j, k, n
	string scalar c, c2, w, q

	q = char(34)
	t.ty = J(0, 1, "")
	t.va = J(0, 1, "")
	n = strlen(e)
	i = 1
	while (i <= n) {
		c = substr(e, i, 1)
		c2 = substr(e, i, 2)
		if (c == " " || c == char(9) || c == char(10) || c == char(13)) {
			i++
			continue
		}
		if (c == q) {
			j = strpos(substr(e, i + 1, .), q)
			if (j == 0) _sqldta_fail("a string has no closing quote")
			_sqldta_push(t, "str", substr(e, i + 1, j - 1))
			i = i + j + 1
			continue
		}
		if (_sqldta_isdigit(c) || (c == "." && _sqldta_isdigit(substr(e, i + 1, 1)))) {
			j = i
			while (j <= n && (_sqldta_isdigit(substr(e, j, 1)) || substr(e, j, 1) == ".")) j++
			if (j <= n && (substr(e, j, 1) == "e" || substr(e, j, 1) == "E")) {
				if ((substr(e, j + 1, 1) == "+" || substr(e, j + 1, 1) == "-") && _sqldta_isdigit(substr(e, j + 2, 1))) j = j + 2
				else if (_sqldta_isdigit(substr(e, j + 1, 1))) j++
				while (j <= n && _sqldta_isdigit(substr(e, j, 1))) j++
			}
			w = substr(e, i, j - i)
			if (strtoreal(w) >= .) _sqldta_fail(w + " is not a number")
			_sqldta_push(t, "num", w)
			i = j
			continue
		}
		if (c == ".") {
			// the missing value, or one of .a to .z, which are treated alike
			if (_sqldta_islower(substr(e, i + 1, 1)) && !_sqldta_isname(substr(e, i + 2, 1))) i = i + 2
			else i++
			_sqldta_push(t, "miss", ".")
			continue
		}
		if (_sqldta_isname1(c)) {
			j = i
			while (j <= n && _sqldta_isname(substr(e, j, 1))) j++
			w = substr(e, i, j - i)
			i = j
			if (w == "td" || w == "tc" || w == "tC") {
				j = i
				while (j <= n && substr(e, j, 1) == " ") j++
				if (substr(e, j, 1) == "(") {
					if (w == "tC") _sqldta_fail("tC() is not supported; sqldta loads date-times as %tc, so use tc()")
					k = strpos(substr(e, j + 1, .), ")")
					if (k == 0) _sqldta_fail(w + "( has no closing parenthesis")
					_sqldta_push(t, w, strtrim(substr(e, j + 1, k - 1)))
					i = j + k + 1
					continue
				}
			}
			_sqldta_push(t, "name", w)
			continue
		}
		if (c2 == "==" || c2 == "!=" || c2 == "~=" || c2 == "<=" || c2 == ">=") {
			_sqldta_push(t, "op", c2)
			i = i + 2
			continue
		}
		if (c == "=") _sqldta_fail("= assigns in Stata; use == to compare")
		if (c == "+" || c == "*" || c == "/" || c == "^") _sqldta_fail("arithmetic (" + c + ") is not supported")
		if (strpos("<>&|!~(),-", c)) {
			_sqldta_push(t, "op", c)
			i++
			continue
		}
		_sqldta_fail(c + " is not supported")
	}
	_sqldta_push(t, "eof", "")
}

string scalar _sqldta_T()
{
	return("(1 = 1)")
}

string scalar _sqldta_F()
{
	return("(1 = 0)")
}

struct _sqldta_val scalar _sqldta_mk(string scalar sql, string scalar kind, real scalar nul, real scalar lit)
{
	struct _sqldta_val scalar v

	v.sql = sql
	v.kind = kind
	v.nul = nul
	v.lit = lit
	v.num = .
	v.str = ""
	v.type = ""
	return(v)
}

struct _sqldta_val scalar _sqldta_mkbool(string scalar sql)
{
	return(_sqldta_mk(sql, "bool", 0, 0))
}

struct _sqldta_val scalar _sqldta_strlit(string scalar s)
{
	struct _sqldta_val scalar v

	v = _sqldta_mk("N" + char(39) + subinstr(s, char(39), char(39) + char(39), .) + char(39), "str", (s == "" ? 2 : 0), 1)
	v.str = s
	return(v)
}

struct _sqldta_val scalar _sqldta_numlit(real scalar x)
{
	struct _sqldta_val scalar v

	if (x >= .) return(_sqldta_mk("NULL", "num", 2, 1))
	v = _sqldta_mk(strtrim(strofreal(x, "%21.0g")), "num", 0, 1)
	v.num = x
	return(v)
}

// A number compared with a date column is a Stata daily date
struct _sqldta_val scalar _sqldta_num2date(struct _sqldta_val scalar v)
{
	struct _sqldta_val scalar r

	if (v.lit && v.nul == 2) return(_sqldta_mk("NULL", "date", 2, 1))
	if (!v.lit) _sqldta_fail("a date column can be compared only with td() or a number of days")
	if (v.num != floor(v.num)) _sqldta_fail("a date must be a whole number of days")
	if (year(v.num) >= .) _sqldta_fail("a date must lie between 01jan0100 and 31dec9999")
	r = _sqldta_mk("CAST(N" + char(39) + sprintf("%04.0f-%02.0f-%02.0f", year(v.num), month(v.num), day(v.num)) + char(39) + " AS date)", "date", 0, 1)
	r.num = v.num
	return(r)
}

// The literal text s read by SQL Server as type typ
string scalar _sqldta_cast(string scalar s, string scalar typ)
{
	return("CAST(N" + char(39) + s + char(39) + " AS " + typ + ")")
}

// 01jan0100, Stata's earliest date; an earlier datetime2 value is loaded as
// missing
string scalar _sqldta_y100()
{
	return(_sqldta_cast("0100-01-01", "datetime2"))
}

real scalar _sqldta_istime(struct _sqldta_val scalar v)
{
	return(v.kind == "dt" || v.kind == "time")
}

// The Stata %tc value of the text of tc(), which may leave out the seconds,
// or give a time of day alone
real scalar _sqldta_clock(string scalar s)
{
	real scalar x, i
	string rowvector m

	m = ("DMYhms", "DMYhm", "DMYh", "DMY", "hms", "hm")
	for (i = 1; i <= length(m); i++) {
		x = clock(s, m[i])
		if (x < .) return(x)
	}
	return(.)
}

// The range of the values that a column of SQL type typ loads: milliseconds
// since midnight for time, otherwise Stata %tc values
real rowvector _sqldta_dtrange(string scalar typ)
{
	real scalar d

	d = 86400000
	if (typ == "time") return((0, d - 1))
	if (typ == "datetime") return((mdy(1, 1, 1753) * d, mdy(12, 31, 9999) * d + d - 3))
	if (typ == "smalldatetime") return((mdy(1, 1, 1900) * d, mdy(6, 6, 2079) * d + d - 60000))
	return((mdy(1, 1, 100) * d, mdy(12, 31, 9999) * d + d - 1))
}

// The smallest value at or above x that a column of SQL type typ loads.
// Loaded values are whole milliseconds; a datetime column loads only .000,
// .003 and .007 in each 10 milliseconds.
real scalar _sqldta_dtceil(real scalar x, string scalar typ)
{
	real scalar m, r

	m = ceil(x)
	if (typ != "datetime") return(m)
	r = m - 10 * floor(m / 10)
	if (r == 0) return(m)
	if (r <= 3) return(m - r + 3)
	if (r <= 7) return(m - r + 7)
	return(m - r + 10)
}

// The SQL literal of b, a value that a column of SQL type typ loads. A
// datetime column is compared with a datetime literal, which holds the same
// step of 1/300 of a second, so that the result does not depend on the
// compatibility level of the database.
string scalar _sqldta_dtlit(real scalar b, string scalar typ)
{
	real scalar d, r, h, mi, sec, ms
	string scalar s

	d = floor(b / 86400000)
	r = b - d * 86400000
	h = floor(r / 3600000)
	mi = floor((r - h * 3600000) / 60000)
	sec = floor((r - h * 3600000 - mi * 60000) / 1000)
	ms = r - h * 3600000 - mi * 60000 - sec * 1000
	s = sprintf("%02.0f:%02.0f:%02.0f.%03.0f", h, mi, sec, ms)
	if (typ == "time") return(_sqldta_cast(s, "time(3)"))
	s = sprintf("%04.0f-%02.0f-%02.0fT", year(d), month(d), day(d)) + s
	if (typ == "datetime") return(_sqldta_cast(s, "datetime"))
	return(_sqldta_cast(s, "datetime2(3)"))
}

// True where the loaded value of a dt or time column is missing
string scalar _sqldta_dtmiss(struct _sqldta_val scalar v)
{
	if (v.type == "datetime2") return("(" + v.sql + " IS NULL OR " + v.sql + " < " + _sqldta_y100() + ")")
	return("(" + v.sql + " IS NULL)")
}

// True where it is not missing
string scalar _sqldta_dtnmiss(struct _sqldta_val scalar v)
{
	if (v.type == "datetime2") return("(" + v.sql + " >= " + _sqldta_y100() + ")")
	return("(" + v.sql + " IS NOT NULL)")
}

// True where it is not missing and is below b, a value the column loads
string scalar _sqldta_dtlt(struct _sqldta_val scalar v, real scalar b)
{
	real rowvector r
	string scalar s

	r = _sqldta_dtrange(v.type)
	if (b <= r[1]) return(_sqldta_F())
	if (b > r[2]) return(_sqldta_dtnmiss(v))
	s = v.sql + " < " + _sqldta_dtlit(b, v.type)
	if (v.type == "datetime2") return("(" + _sqldta_dtnmiss(v) + " AND " + s + ")")
	return("(" + s + ")")
}

// True where it is not missing and is b or above
string scalar _sqldta_dtge(struct _sqldta_val scalar v, real scalar b)
{
	real rowvector r

	r = _sqldta_dtrange(v.type)
	if (b <= r[1]) return(_sqldta_dtnmiss(v))
	if (b > r[2]) return(_sqldta_F())
	return("(" + v.sql + " >= " + _sqldta_dtlit(b, v.type) + ")")
}

string scalar _sqldta_sqland(string scalar a, string scalar b)
{
	if (a == _sqldta_F() || b == _sqldta_F()) return(_sqldta_F())
	if (a == _sqldta_T()) return(b)
	if (b == _sqldta_T()) return(a)
	return("(" + a + " AND " + b + ")")
}

string scalar _sqldta_sqlor(string scalar a, string scalar b)
{
	if (a == _sqldta_T() || b == _sqldta_T()) return(_sqldta_T())
	if (a == _sqldta_F()) return(b)
	if (b == _sqldta_F()) return(a)
	return("(" + a + " OR " + b + ")")
}

// A dt or time column compared with x, a number of milliseconds or missing.
// The loaded value m is a whole number of milliseconds, so m <= x is
// m < floor(x) + 1, and m == x is b1 <= m < b2.
string scalar _sqldta_cmpdtlit(string scalar op, struct _sqldta_val scalar a, real scalar x)
{
	real scalar b1, b2
	string scalar M

	M = _sqldta_dtmiss(a)
	if (x >= .) {
		if (op == "==" || op == ">=") return(M)
		if (op == "!=" || op == "<") return(_sqldta_dtnmiss(a))
		if (op == ">") return(_sqldta_F())
		return(_sqldta_T())
	}
	if (op == "<") return(_sqldta_dtlt(a, _sqldta_dtceil(x, a.type)))
	if (op == ">=") return(_sqldta_sqlor(M, _sqldta_dtge(a, _sqldta_dtceil(x, a.type))))
	if (op == "<=") return(_sqldta_dtlt(a, _sqldta_dtceil(floor(x) + 1, a.type)))
	if (op == ">") return(_sqldta_sqlor(M, _sqldta_dtge(a, _sqldta_dtceil(floor(x) + 1, a.type))))
	b1 = _sqldta_dtceil(x, a.type)
	b2 = _sqldta_dtceil(floor(x) + 1, a.type)
	if (x != floor(x) || b1 >= b2) return(op == "==" ? _sqldta_F() : _sqldta_T())
	if (op == "==") return(_sqldta_sqland(_sqldta_dtge(a, b1), _sqldta_dtlt(a, b2)))
	return(_sqldta_sqlor(M, _sqldta_sqlor(_sqldta_dtlt(a, b1), _sqldta_dtge(a, b2))))
}

// The loaded value of a dt or time column as SQL, NULL where it is missing,
// for comparisons of one column with another; SQL Server cannot use an index
// for these
string scalar _sqldta_dtval(struct _sqldta_val scalar v)
{
	if (v.type == "time") return("DATEDIFF(millisecond, " + _sqldta_cast("00:00:00", "time") + ", " + v.sql + ")")
	if (v.type == "smalldatetime") return("CAST(" + v.sql + " AS datetime2(3))")
	if (v.type == "datetime") return("CAST(CONVERT(varchar(23), " + v.sql + ", 121) AS datetime2(3))")
	return("CASE WHEN " + v.sql + " >= " + _sqldta_y100() + " THEN CAST(CONVERT(varchar(23), " + v.sql + ", 121) AS datetime2(3)) END")
}

// dofc() of a date-time column, of tc() or of a number: the date, missing
// where the date-time is missing
struct _sqldta_val scalar _sqldta_dofc(struct _sqldta_val scalar v)
{
	if (v.lit && (v.kind == "num" || v.kind == "dt")) {
		if (v.nul == 2) return(_sqldta_mk("NULL", "date", 2, 1))
		return(_sqldta_num2date(_sqldta_numlit(floor(v.num / 86400000))))
	}
	if (v.kind != "dt" || v.lit) _sqldta_fail("dofc() needs a date-time column or tc()")
	if (v.type == "datetime2") return(_sqldta_mk("CASE WHEN " + v.sql + " >= " + _sqldta_y100() + " THEN CAST(" + v.sql + " AS date) END", "date", 1, 0))
	return(_sqldta_mk("CAST(" + v.sql + " AS date)", "date", 1, 0))
}

// A value used as a condition: a number is true unless it is 0, and missing
// is true, as in Stata
string scalar _sqldta_bool(struct _sqldta_val scalar v)
{
	if (v.kind == "bool") return(v.sql)
	if (_sqldta_istime(v)) {
		if (v.lit) return(v.num != 0 ? _sqldta_T() : _sqldta_F())
		return(_sqldta_cmpdtlit("!=", v, 0))
	}
	if (v.kind == "num") {
		if (v.lit) return(v.nul == 2 || v.num != 0 ? _sqldta_T() : _sqldta_F())
		return("(" + v.sql + " <> 0 OR " + v.sql + " IS NULL)")
	}
	_sqldta_fail("a string or a date on its own is not a condition; compare it with ==, < or >")
	return("")
}

// The CASE expression makes the negation of an unknown comparison true, as
// the negation of a false one is in Stata
struct _sqldta_val scalar _sqldta_not(struct _sqldta_val scalar v)
{
	if (v.kind == "bool") return(_sqldta_mkbool("(CASE WHEN " + v.sql + " THEN 1 ELSE 0 END = 0)"))
	if (_sqldta_istime(v)) {
		if (v.lit) return(_sqldta_mkbool(v.num == 0 ? _sqldta_T() : _sqldta_F()))
		return(_sqldta_mkbool(_sqldta_cmpdtlit("==", v, 0)))
	}
	if (v.kind == "num") {
		if (v.lit) return(_sqldta_mkbool(v.nul != 2 && v.num == 0 ? _sqldta_T() : _sqldta_F()))
		return(_sqldta_mkbool("(" + v.sql + " = 0)"))
	}
	_sqldta_fail("! applies only to a condition or a number")
	return(v)
}

string scalar _sqldta_ismiss(struct _sqldta_val scalar v)
{
	if (v.kind == "bool") _sqldta_fail("missing() needs a column or a value, not a condition")
	if (v.lit) return(v.nul == 2 ? _sqldta_T() : _sqldta_F())
	if (_sqldta_istime(v)) return(_sqldta_dtmiss(v))
	if (v.kind == "str") return("(" + v.sql + " IS NULL OR " + v.sql + " = N" + char(39) + char(39) + ")")
	return("(" + v.sql + " IS NULL)")
}

string scalar _sqldta_mirror(string scalar op)
{
	if (op == "<") return(">")
	if (op == ">") return("<")
	if (op == "<=") return(">=")
	if (op == ">=") return("<=")
	return(op)
}

string scalar _sqldta_sqlop(string scalar op)
{
	if (op == "==") return("=")
	if (op == "!=") return("<>")
	return(op)
}

// Numbers and dates, with Stata's rule that a missing value is greater than
// every number and equal to another missing value
string scalar _sqldta_cmpnum(string scalar op0, struct _sqldta_val scalar a0, struct _sqldta_val scalar b0)
{
	struct _sqldta_val scalar a, b
	string scalar op, A, B, base
	real scalar na, nb, x, y, r

	op = op0
	a = a0
	b = b0
	if (a.lit && b.lit) {
		x = (a.nul == 2 ? . : a.num)
		y = (b.nul == 2 ? . : b.num)
		if (op == "==") r = (x == y)
		else if (op == "!=") r = (x != y)
		else if (op == "<") r = (x < y)
		else if (op == ">") r = (x > y)
		else if (op == "<=") r = (x <= y)
		else r = (x >= y)
		return(r ? _sqldta_T() : _sqldta_F())
	}
	if (a.lit) {
		a = b0
		b = a0
		op = _sqldta_mirror(op)
	}
	A = a.sql
	B = b.sql
	na = (a.nul > 0)
	if (b.nul == 2) {
		if (op == "==" || op == ">=") return(na ? "(" + A + " IS NULL)" : _sqldta_F())
		if (op == "!=" || op == "<") return(na ? "(" + A + " IS NOT NULL)" : _sqldta_T())
		if (op == ">") return(_sqldta_F())
		return(_sqldta_T())
	}
	nb = (b.nul > 0)
	base = A + " " + _sqldta_sqlop(op) + " " + B
	if (op == "==") return(na && nb ? "(" + base + " OR (" + A + " IS NULL AND " + B + " IS NULL))" : "(" + base + ")")
	if (op == "!=") {
		if (!na && !nb) return("(" + base + ")")
		if (!nb) return("(" + base + " OR " + A + " IS NULL)")
		if (!na) return("(" + base + " OR " + B + " IS NULL)")
		return("(" + base + " OR (" + A + " IS NULL AND " + B + " IS NOT NULL) OR (" + A + " IS NOT NULL AND " + B + " IS NULL))")
	}
	if (op == ">") {
		if (!na) return("(" + base + ")")
		if (!nb) return("(" + base + " OR " + A + " IS NULL)")
		return("(" + base + " OR (" + A + " IS NULL AND " + B + " IS NOT NULL))")
	}
	if (op == ">=") return(na ? "(" + base + " OR " + A + " IS NULL)" : "(" + base + ")")
	if (op == "<") {
		if (!nb) return("(" + base + ")")
		if (!na) return("(" + base + " OR " + B + " IS NULL)")
		return("(" + base + " OR (" + B + " IS NULL AND " + A + " IS NOT NULL))")
	}
	return(nb ? "(" + base + " OR " + B + " IS NULL)" : "(" + base + ")")
}

// Strings, with NULL treated as "" and a binary collation, so that the
// comparison is case-sensitive and follows character codes, as in Stata
string scalar _sqldta_cmpstr(string scalar op0, struct _sqldta_val scalar a0, struct _sqldta_val scalar b0)
{
	struct _sqldta_val scalar a, b
	string scalar op, A, B, C, E
	real scalar r

	op = op0
	a = a0
	b = b0
	C = " COLLATE Latin1_General_BIN2 "
	E = "N" + char(39) + char(39)
	if (a.lit && b.lit) {
		if (op == "==") r = (a.str == b.str)
		else if (op == "!=") r = (a.str != b.str)
		else if (op == "<") r = (a.str < b.str)
		else if (op == ">") r = (a.str > b.str)
		else if (op == "<=") r = (a.str <= b.str)
		else r = (a.str >= b.str)
		return(r ? _sqldta_T() : _sqldta_F())
	}
	if (a.lit) {
		a = b0
		b = a0
		op = _sqldta_mirror(op)
	}
	A = a.sql
	if (b.lit) {
		if (b.nul == 2) {
			if (op == "==" || op == "<=") return("(" + A + " IS NULL OR " + A + " = " + E + ")")
			if (op == "!=" || op == ">") return("(" + A + " IS NOT NULL AND " + A + " <> " + E + ")")
			if (op == ">=") return(_sqldta_T())
			return(_sqldta_F())
		}
		B = A + C + _sqldta_sqlop(op) + " " + b.sql
		if (op == "==" || op == ">" || op == ">=") return("(" + B + ")")
		return("(" + B + " OR " + A + " IS NULL)")
	}
	return("(ISNULL(" + A + ", " + E + ")" + C + _sqldta_sqlop(op) + " ISNULL(" + b.sql + ", " + E + "))")
}

// A dt or time column a compared with b, which is a literal or a column of
// the same kind
string scalar _sqldta_cmpdt(string scalar op, struct _sqldta_val scalar a, struct _sqldta_val scalar b)
{
	string scalar msg

	msg = "a date-time or time column can be compared only with a number, tc() or another column of the same kind"
	if (b.lit) {
		if (b.kind != "num" && b.kind != "dt") _sqldta_fail(msg)
		return(_sqldta_cmpdtlit(op, a, (b.nul == 2 ? . : b.num)))
	}
	if (b.kind != a.kind) _sqldta_fail(msg)
	return(_sqldta_cmpnum(op, _sqldta_mk(_sqldta_dtval(a), "num", 1, 0), _sqldta_mk(_sqldta_dtval(b), "num", 1, 0)))
}

// A date compared with a date-time is refused: Stata would compare days with
// milliseconds, which is almost never meant
void _sqldta_datedt(struct _sqldta_val scalar a, struct _sqldta_val scalar b)
{
	struct _sqldta_val scalar d, c

	if (a.kind == "date") {
		d = a
		c = b
	}
	else {
		d = b
		c = a
	}
	if (d.lit && !c.lit) _sqldta_fail("td() gives a date in days, but a date-time column holds milliseconds; use tc(), as in x >= tc(01jan2020 00:00), or compare dofc(x) with td()")
	if (c.lit && !d.lit) _sqldta_fail("tc() gives a date-time in milliseconds, but a date column holds days; use td()")
	_sqldta_fail("a date cannot be compared with a date-time; use dofc() to take the date of a date-time column")
}

struct _sqldta_val scalar _sqldta_cmp(string scalar op0, struct _sqldta_val scalar a0, struct _sqldta_val scalar b0)
{
	struct _sqldta_val scalar a, b
	string scalar op

	op = (op0 == "~=" ? "!=" : op0)
	a = a0
	b = b0
	if (a.kind == "bool" || b.kind == "bool") _sqldta_fail("a condition cannot be compared with a value; combine conditions with & or |")
	if ((a.kind == "date" && b.kind == "dt") || (a.kind == "dt" && b.kind == "date")) _sqldta_datedt(a, b)
	if (_sqldta_istime(a) && !a.lit) return(_sqldta_mkbool(_sqldta_cmpdt(op, a, b)))
	if (_sqldta_istime(b) && !b.lit) return(_sqldta_mkbool(_sqldta_cmpdt(_sqldta_mirror(op), b, a)))
	// What remains of tc() is a literal number of milliseconds
	if (a.kind == "dt") a.kind = "num"
	if (b.kind == "dt") b.kind = "num"
	if (a.kind == "date" && b.kind == "num") b = _sqldta_num2date(b)
	if (b.kind == "date" && a.kind == "num") a = _sqldta_num2date(a)
	if (a.kind != b.kind) _sqldta_fail("type mismatch: a string is compared with a number or a date")
	if (a.kind == "str") return(_sqldta_mkbool(_sqldta_cmpstr(op, a, b)))
	return(_sqldta_mkbool(_sqldta_cmpnum(op, a, b)))
}

// inrange() is true only when the value is known to lie between the bounds,
// so a missing value never matches
struct _sqldta_val scalar _sqldta_inrange(struct _sqldta_val scalar z0, struct _sqldta_val scalar lo0, struct _sqldta_val scalar hi0)
{
	struct _sqldta_val scalar z, lo, hi
	string scalar Z
	real scalar r

	z = z0
	lo = lo0
	hi = hi0
	if (_sqldta_istime(z) && !z.lit) {
		if (!lo.lit || !hi.lit || lo.nul != 0 || hi.nul != 0 || !anyof(("num", "dt"), lo.kind) || !anyof(("num", "dt"), hi.kind)) _sqldta_fail("inrange() of a date-time or time column needs two bounds that are numbers or tc() date-times")
		return(_sqldta_mkbool(_sqldta_sqland(_sqldta_dtge(z, _sqldta_dtceil(lo.num, z.type)), _sqldta_dtlt(z, _sqldta_dtceil(floor(hi.num) + 1, z.type)))))
	}
	if (z.kind == "date" && (lo.kind == "dt" || hi.kind == "dt")) _sqldta_fail("tc() gives a date-time in milliseconds, but a date column holds days; use td()")
	if (z.kind == "dt") z.kind = "num"
	if (lo.kind == "dt") lo.kind = "num"
	if (hi.kind == "dt") hi.kind = "num"
	if (z.kind == "date") {
		if (lo.kind == "num") lo = _sqldta_num2date(lo)
		if (hi.kind == "num") hi = _sqldta_num2date(hi)
	}
	if (!lo.lit || !hi.lit || lo.nul != 0 || hi.nul != 0) _sqldta_fail("inrange() needs two bounds that are numbers, td() dates or strings other than " + char(34) + char(34))
	if (z.kind == "bool" || z.kind != lo.kind || z.kind != hi.kind) _sqldta_fail("type mismatch in inrange()")
	if (z.lit) {
		if (z.kind == "str") r = (z.str != "" && z.str >= lo.str && z.str <= hi.str)
		else r = (z.nul != 2 && z.num >= lo.num && z.num <= hi.num)
		return(_sqldta_mkbool(r ? _sqldta_T() : _sqldta_F()))
	}
	Z = z.sql + (z.kind == "str" ? " COLLATE Latin1_General_BIN2" : "")
	return(_sqldta_mkbool("(" + Z + " >= " + lo.sql + " AND " + Z + " <= " + hi.sql + ")"))
}

struct _sqldta_val scalar _sqldta_substr(struct _sqldta_val scalar s, struct _sqldta_val scalar n1, struct _sqldta_val scalar n2)
{
	real scalar len

	len = .
	if (s.kind != "str") _sqldta_fail("substr() needs a string")
	if (!(n1.lit && n1.kind == "num" && n1.nul == 0 && n1.num >= 1 && n1.num == floor(n1.num))) _sqldta_fail("substr() needs a whole-number start position of 1 or more")
	if (n2.lit && n2.kind == "num" && n2.nul == 2) len = .
	else if (n2.lit && n2.kind == "num" && n2.nul == 0 && n2.num >= 0 && n2.num == floor(n2.num)) len = n2.num
	else _sqldta_fail("substr() needs a whole-number length of 0 or more, or .")
	if (s.lit) return(_sqldta_strlit(substr(s.str, n1.num, len)))
	return(_sqldta_mk("SUBSTRING(" + s.sql + ", " + strtrim(strofreal(n1.num, "%12.0f")) + ", " + strtrim(strofreal(len < . ? len : 2147483647, "%12.0f")) + ")", "str", 1, 0))
}

struct _sqldta_val scalar _sqldta_strfn(string scalar fn, struct _sqldta_val scalar v)
{
	string scalar f, s

	if (v.kind != "str") _sqldta_fail(fn + "() needs a string")
	if (anyof(("strlower", "lower", "ustrlower"), fn)) f = "LOWER"
	else if (anyof(("strupper", "upper", "ustrupper"), fn)) f = "UPPER"
	else if (anyof(("strltrim", "ltrim", "ustrltrim"), fn)) f = "LTRIM"
	else if (anyof(("strrtrim", "rtrim", "ustrrtrim"), fn)) f = "RTRIM"
	else f = "TRIM"
	if (v.lit) {
		if (f == "LOWER") s = ustrlower(v.str)
		else if (f == "UPPER") s = ustrupper(v.str)
		else if (f == "LTRIM") s = strltrim(v.str)
		else if (f == "RTRIM") s = strrtrim(v.str)
		else s = strtrim(v.str)
		return(_sqldta_strlit(s))
	}
	if (f == "TRIM") return(_sqldta_mk("LTRIM(RTRIM(" + v.sql + "))", "str", 1, 0))
	return(_sqldta_mk(f + "(" + v.sql + ")", "str", 1, 0))
}

struct _sqldta_val scalar _sqldta_datefn(string scalar fn, struct _sqldta_val scalar v)
{
	real scalar x

	if (_sqldta_istime(v)) _sqldta_fail(fn + "() needs a date; for a date-time column x, write " + fn + "(dofc(x))")
	if (v.kind != "date") _sqldta_fail(fn + "() needs a date column or td()")
	if (v.lit) {
		if (v.nul == 2) return(_sqldta_mk("NULL", "num", 2, 1))
		if (fn == "year") x = year(v.num)
		else if (fn == "month") x = month(v.num)
		else x = day(v.num)
		return(_sqldta_numlit(x))
	}
	return(_sqldta_mk(strupper(fn) + "(" + v.sql + ")", "num", 1, 0))
}

real scalar _sqldta_isop(struct _sqldta_tok scalar t, string scalar op)
{
	return(t.ty[t.pos] == "op" && t.va[t.pos] == op)
}

real scalar _sqldta_isrelop(struct _sqldta_tok scalar t)
{
	return(t.ty[t.pos] == "op" && anyof(("==", "!=", "~=", "<", ">", "<=", ">="), t.va[t.pos]))
}

void _sqldta_unexpected(struct _sqldta_tok scalar t)
{
	if (t.ty[t.pos] == "eof") _sqldta_fail("the expression ends too early")
	if (t.ty[t.pos] == "op" && t.va[t.pos] == "-") _sqldta_fail("arithmetic (-) is not supported")
	_sqldta_fail("unexpected " + t.va[t.pos])
}

// The parser functions below write their result into r. _sqldta_func and
// _sqldta_primary call _sqldta_or, which is defined after them.

void _sqldta_func(struct _sqldta_tok scalar t, string scalar f, struct _sqldta_val scalar r)
{
	struct _sqldta_val rowvector a
	struct _sqldta_val scalar v
	real scalar n, i
	string scalar fn, s

	a = _sqldta_val(1, 256)
	n = 0
	t.pos = t.pos + 1
	if (!_sqldta_isop(t, ")")) {
		while (1) {
			n++
			if (n > 256) _sqldta_fail(f + "() has too many arguments")
			_sqldta_or(t, v)
			a[n] = v
			if (!_sqldta_isop(t, ",")) break
			t.pos = t.pos + 1
		}
	}
	if (!_sqldta_isop(t, ")")) _sqldta_fail("a parenthesis is not closed after " + f + "(")
	t.pos = t.pos + 1

	fn = strlower(f)
	if (fn == "missing") {
		if (n < 1) _sqldta_fail("missing() needs at least one argument")
		s = _sqldta_ismiss(a[1])
		for (i = 2; i <= n; i++) s = s + " OR " + _sqldta_ismiss(a[i])
		r = _sqldta_mkbool("(" + s + ")")
		return
	}
	if (fn == "inlist") {
		if (n < 2) _sqldta_fail("inlist() needs at least two arguments")
		v = _sqldta_cmp("==", a[1], a[2])
		s = _sqldta_bool(v)
		for (i = 3; i <= n; i++) {
			v = _sqldta_cmp("==", a[1], a[i])
			s = s + " OR " + _sqldta_bool(v)
		}
		r = _sqldta_mkbool("(" + s + ")")
		return
	}
	if (fn == "inrange") {
		if (n != 3) _sqldta_fail("inrange() needs three arguments")
		r = _sqldta_inrange(a[1], a[2], a[3])
		return
	}
	if (fn == "substr" || fn == "usubstr") {
		if (n != 3) _sqldta_fail(f + "() needs three arguments")
		r = _sqldta_substr(a[1], a[2], a[3])
		return
	}
	if (anyof(("strlower", "lower", "ustrlower", "strupper", "upper", "ustrupper", "strtrim", "trim", "ustrtrim", "strltrim", "ltrim", "ustrltrim", "strrtrim", "rtrim", "ustrrtrim"), fn)) {
		if (n != 1) _sqldta_fail(f + "() needs one argument")
		r = _sqldta_strfn(fn, a[1])
		return
	}
	if (fn == "year" || fn == "month" || fn == "day") {
		if (n != 1) _sqldta_fail(f + "() needs one argument")
		r = _sqldta_datefn(fn, a[1])
		return
	}
	if (fn == "dofc") {
		if (n != 1) _sqldta_fail(f + "() needs one argument")
		r = _sqldta_dofc(a[1])
		return
	}
	_sqldta_fail(f + "() is not supported")
}

void _sqldta_primary(struct _sqldta_tok scalar t, struct _sqldta_val scalar r)
{
	struct _sqldta_val scalar v
	string scalar ty, va
	real matrix p
	real scalar x

	ty = t.ty[t.pos]
	va = t.va[t.pos]
	if (ty == "num") {
		t.pos = t.pos + 1
		r = _sqldta_mk(va, "num", 0, 1)
		r.num = strtoreal(va)
		return
	}
	if (ty == "miss") {
		t.pos = t.pos + 1
		r = _sqldta_mk("NULL", "num", 2, 1)
		return
	}
	if (ty == "str") {
		t.pos = t.pos + 1
		r = _sqldta_strlit(va)
		return
	}
	if (ty == "td") {
		t.pos = t.pos + 1
		v = _sqldta_mk("", "num", 0, 1)
		v.num = date(va, "DMY")
		if (v.num >= .) _sqldta_fail("td(" + va + ") is not a date; write it as, for example, td(01jan2020)")
		r = _sqldta_num2date(v)
		return
	}
	if (ty == "tc") {
		t.pos = t.pos + 1
		x = _sqldta_clock(va)
		if (x >= .) _sqldta_fail("tc(" + va + ") is not a date and time; write it as, for example, tc(01jan2020 13:45:30.123)")
		r = _sqldta_numlit(x)
		r.kind = "dt"
		return
	}
	if (ty == "name") {
		t.pos = t.pos + 1
		if (_sqldta_isop(t, "(")) {
			_sqldta_func(t, va, r)
			return
		}
		p = selectindex(t.lcols :== ustrlower(va))
		if (length(p) == 0) _sqldta_fail("column " + va + " not found")
		if (t.kinds[p[1]] == "other") _sqldta_fail("column " + va + " has a SQL data type that the if qualifier does not support")
		r = _sqldta_mk("[" + t.cols[p[1]] + "]", t.kinds[p[1]], 1, 0)
		if (_sqldta_istime(r)) {
			r.type = t.types[p[1]]
			if (r.type == "datetimeoffset") {
				r.sql = "CAST(" + r.sql + " AS datetime2(7))"
				r.type = "datetime2"
			}
		}
		return
	}
	if (_sqldta_isop(t, "(")) {
		t.pos = t.pos + 1
		_sqldta_or(t, r)
		if (!_sqldta_isop(t, ")")) _sqldta_fail("a parenthesis is not closed")
		t.pos = t.pos + 1
		if (!r.lit && r.kind != "bool") r.sql = "(" + r.sql + ")"
		return
	}
	_sqldta_unexpected(t)
}

void _sqldta_unary(struct _sqldta_tok scalar t, struct _sqldta_val scalar r)
{
	struct _sqldta_val scalar v

	if (_sqldta_isop(t, "!") || _sqldta_isop(t, "~")) {
		t.pos = t.pos + 1
		_sqldta_unary(t, v)
		r = _sqldta_not(v)
		return
	}
	if (_sqldta_isop(t, "-")) {
		t.pos = t.pos + 1
		_sqldta_unary(t, v)
		if (v.kind != "num") _sqldta_fail("a minus sign applies only to numbers")
		if (v.lit && v.nul == 2) {
			r = v
			return
		}
		if (v.lit) {
			r = _sqldta_numlit(-v.num)
			return
		}
		r = v
		r.sql = "(-" + v.sql + ")"
		return
	}
	_sqldta_primary(t, r)
}

void _sqldta_rel(struct _sqldta_tok scalar t, struct _sqldta_val scalar r)
{
	struct _sqldta_val scalar a, b
	string scalar op

	_sqldta_unary(t, a)
	if (_sqldta_isrelop(t)) {
		op = t.va[t.pos]
		t.pos = t.pos + 1
		_sqldta_unary(t, b)
		if (_sqldta_isrelop(t)) _sqldta_fail("chained comparisons such as a < b < c are not supported")
		r = _sqldta_cmp(op, a, b)
		return
	}
	r = a
}

void _sqldta_and(struct _sqldta_tok scalar t, struct _sqldta_val scalar r)
{
	struct _sqldta_val scalar b

	_sqldta_rel(t, r)
	while (_sqldta_isop(t, "&")) {
		t.pos = t.pos + 1
		_sqldta_rel(t, b)
		r = _sqldta_mkbool("(" + _sqldta_bool(r) + " AND " + _sqldta_bool(b) + ")")
	}
}

void _sqldta_or(struct _sqldta_tok scalar t, struct _sqldta_val scalar r)
{
	struct _sqldta_val scalar b

	_sqldta_and(t, r)
	while (_sqldta_isop(t, "|")) {
		t.pos = t.pos + 1
		_sqldta_and(t, b)
		r = _sqldta_mkbool("(" + _sqldta_bool(r) + " OR " + _sqldta_bool(b) + ")")
	}
}

// Splits the local macro 0 of sqldta, which starts with if, into the
// expression, put in the local ifexp, and the options, put back in 0. The
// expression ends at the first comma outside parentheses and double quotes.
void _sqldta_splitif()
{
	string scalar s, c
	real scalar i, n, depth, inq

	s = strtrim(st_local("0"))
	if (substr(s, 1, 2) == "if") s = substr(s, 3, .)
	n = strlen(s)
	depth = 0
	inq = 0
	for (i = 1; i <= n; i++) {
		c = substr(s, i, 1)
		if (c == char(34)) inq = !inq
		else if (!inq) {
			if (c == "(") depth++
			else if (c == ")") depth--
			else if (c == "," && depth == 0) break
		}
	}
	st_local("ifexp", strtrim(substr(s, 1, i - 1)))
	st_local("0", (i <= n ? substr(s, i, .) : ""))
}

// Translates the if qualifier expr0, using the column names in cols, their
// kinds in kinds and their SQL types in types, and puts the T-SQL condition in
// the local macro named by out
void _sqldta_if(string scalar expr0, string scalar cols, string scalar kinds, string scalar types, string scalar out)
{
	struct _sqldta_tok scalar t
	struct _sqldta_val scalar v
	string scalar expr

	expr = strtrim(expr0)
	if (substr(expr, 1, 3) == "if " || expr == "if") expr = strtrim(substr(expr, 3, .))
	if (expr == "") _sqldta_fail("the expression is empty")
	t.cols = tokens(cols)
	t.lcols = ustrlower(t.cols)
	t.kinds = tokens(kinds)
	t.types = tokens(types)
	_sqldta_lex(expr, t)
	t.pos = 1
	_sqldta_or(t, v)
	if (t.ty[t.pos] != "eof") _sqldta_unexpected(t)
	st_local(out, _sqldta_bool(v))
}

end
