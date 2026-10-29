*! version 1.3.1 29oct2026
* sqldta_dlg: helper for the sqldta dialog, sqldta.dlg
*
*   sqldta_dlg query databases, server(name)
*   sqldta_dlg query schemas,   server(name) database(name)
*   sqldta_dlg query tables,    server(name) database(name) schema(name)
*   sqldta_dlg query describe,  server(name) database(name) dataset([schema.]table)
*                               [labeltable([schema.]table)]
*   sqldta_dlg query column,    name(name)
*   sqldta_dlg query find       [, text(string)]
*   sqldta_dlg preinit|start|databases|schemas|tables|describe|column|find|refresh
*   sqldta_dlg addall select|unicode
*
* query returns its results in r() and does not touch the dialog. The lists
* in r(list) hold names separated by spaces, each in double quotes if it
* contains a space. Names that contain a double quote, a backquote, a dollar
* sign, a backslash or a dot are left out, because the dialog's list code
* would expand or split them, and sqldta splits [schema.]table at the dot. A
* query that fails shows the driver's message and returns r(rc) other than 0
* and an empty list; it does not stop. query databases also returns
* r(default), the server's default database from the global
* SQLDTA_DEFAULTDB. query describe also keeps a text for each column of the
* table, its labels and notes, until the next description; query column
* returns that text, and query find the columns whose name, variable label or
* value labels contain every word of a text, and neither makes a query.
*
* The other subcommands are run by the dialog. preinit fills the list of
* servers before the dialog's controls exist; the others read the controls
* through the class system, run query, and set the lists, the selected
* values, the description, the list of columns and the text of the column
* selected. A change of server refills the databases, a change of database
* the schemas, and so on down to the description; refresh does the same from
* the databases down, keeping the names chosen or typed. find applies the
* text of the field Find to the list of columns, and addall adds every column
* that the list shows to the columns to load or to the Unicode columns. With
* the global SQLDTA_DLGREMEMBER set to anything other than 0, the dialog
* reopens at the server used last, and at the database and schema chosen
* last on each server.
program define sqldta_dlg, rclass
	version 16
	gettoken sub 0 : 0, parse(" ,")
	local what
	if `"`sub'"' == "query" {
		gettoken what 0 : 0, parse(" ,")
		if inlist(`"`what'"', "databases", "schemas", "tables", "describe", "column", "find") {
			_sqldta_dlg_`what' `0'
			return add
			exit
		}
	}
	else if `"`sub'"' == "preinit" {
		capture noisily _sqldta_dlg_onpreinit
		exit _rc
	}
	else if inlist(`"`sub'"', "start", "databases", "schemas", "tables", "describe", "column", "find", "refresh", "addall") {
		* The dialog's handlers do nothing while its property isLoading is
		* true, so that the values set here do not start the helper again.
		* The dialog may have been closed, so a failure to set it is ignored.
		capture .sqldta_dlg.isLoading.settrue
		capture noisily _sqldta_dlg_on`sub' `0'
		local rc = _rc
		capture .sqldta_dlg.isLoading.setfalse
		exit `rc'
	}
	display as error `"sqldta_dlg: unknown subcommand `sub' `what'"'
	exit 198
end


* The databases offered: SQLDTA_DATABASES if it is set, as a global or in the
* settings file, without contacting the server; otherwise the databases on
* the server that are online and that the login can open, leaving out
* master, tempdb, model and msdb. Returns r(list), r(rc) and r(default), the
* server's default database, whether or not it is listed.
program define _sqldta_dlg_databases, rclass
	version 16
	syntax , SERver(string)

	_sqldta_dlg_defaultdb `"`server'"'
	local default `"`r(default)'"'
	_sqldta_settings, quiet
	local databases `"`r(databases)'"'
	if `"`databases'"' != "" {
		* In compound quotes, because a list that begins with a quoted name
		* would otherwise lose its first and last double quotes
		return local list `"`databases'"'
		return local default `"`default'"'
		return scalar rc = 0
		exit
	}
	local sql SELECT CAST(name AS nvarchar(128)) AS name FROM sys.databases ///
		WHERE HAS_DBACCESS(name) = 1 AND state_desc = N'ONLINE' AND database_id > 4 ///
		ORDER BY name
	_sqldta_dlg_list `"`server'"' master sys.databases `"`sql'"'
	return add
	return local default `"`default'"'
end


* The default database of a server, from SQLDTA_DEFAULTDB, as a global or in
* the settings file. Each word is a database for every server, or
* server=database for one server, whose name is matched without regard to
* case; a name with a space is in double quotes. A word for the server comes
* before a word for every server, and the first of each kind is taken.
* Returns r(default), empty if no word applies.
program define _sqldta_dlg_defaultdb, rclass
	version 16
	args server

	_sqldta_settings, quiet
	local defaultdb `"`r(defaultdb)'"'
	local every
	local this
	foreach w of local defaultdb {
		local eq = strpos(`"`w'"', "=")
		if `eq' == 0 {
			if `"`every'"' == "" local every `"`w'"'
		}
		else if `"`this'"' == "" {
			if ustrlower(substr(`"`w'"', 1, `eq' - 1)) == ustrlower(`"`server'"') {
				local this = substr(`"`w'"', `eq' + 1, .)
			}
		}
	}
	if `"`this'"' == "" local this `"`every'"'
	return local default `"`this'"'
end


* The schemas of the database that hold a table or view that the login can
* see, other than those that SQL Server itself supplies. Returns r(list) and
* r(rc).
program define _sqldta_dlg_schemas, rclass
	version 16
	syntax , SERver(string) DATABase(string)

	local qdb : subinstr local database "]" "]]", all
	local sql SELECT DISTINCT CAST(s.name AS nvarchar(128)) AS name ///
		FROM [`qdb'].sys.schemas AS s ///
		JOIN [`qdb'].sys.objects AS o ON o.schema_id = s.schema_id ///
		WHERE o.type IN ('U', 'V') AND o.is_ms_shipped = 0 ORDER BY name
	_sqldta_dlg_list `"`server'"' `"`database'"' sys.schemas `"`sql'"'
	return add
end


* The tables and views in a schema of the database. The schema is matched
* through [database].sys.schemas, because SCHEMA_ID() and SCHEMA_NAME()
* resolve in the database of the connection. Returns r(list) and r(rc).
program define _sqldta_dlg_tables, rclass
	version 16
	syntax , SERver(string) DATABase(string) SCHema(string)

	local qdb : subinstr local database "]" "]]", all
	local lit : subinstr local schema "'" "''", all
	local sql SELECT CAST(o.name AS nvarchar(128)) AS name ///
		FROM [`qdb'].sys.objects AS o ///
		JOIN [`qdb'].sys.schemas AS s ON s.schema_id = o.schema_id ///
		WHERE s.name = N'`lit'' AND o.type IN ('U', 'V') AND o.is_ms_shipped = 0 ///
		ORDER BY name
	_sqldta_dlg_list `"`server'"' `"`database'"' sys.objects `"`sql'"'
	return add
end


* Describes a table for the dialog. The columns, links, data label, dataset
* description, dataset notes and the labels of each column come from sqldta
* itself, run with the condition if 0, so that no rows are read, and with
* labels(all), so that they are exactly what a load would give; unicode(*)
* makes sqldta list in r(unicode) the char, varchar and text columns, which
* unicode() affects. The number of rows comes from sys.partitions and is
* missing for a view. Returns
* r(rc), r(columns) (the variables a load would give, in order), r(textcols)
* (the char, varchar and text columns), r(links), r(dropped),
* r(labelstatus), r(datalabel) (empty unless a DatasetLabel row gives one),
* r(description) (the DatasetDescription paragraph of PropertyCode 1, or
* empty), r(n_notes), r(note1), r(note2) and so on, r(rows), and r(text), the
* description that the dialog shows, made from the others. The text of each
* column, which query column returns, is kept until the next description,
* and emptied if this one fails.
program define _sqldta_dlg_describe, rclass
	version 16
	syntax , SERver(string) DATABase(string) DATASet(string) [LABELTable(string)]

	mata: _sqldta_dlg_store(J(0, 1, ""), J(0, 1, ""), J(0, 1, ""))
	local lt
	if `"`labeltable'"' != "" local lt labeltable(`"`labeltable'"')
	tempname f
	capture sqldta if 0, server(`"`server'"') database(`"`database'"') ///
		dataset(`"`dataset'"') frame(`f') labels(all) unicode(*) `lt'
	local rc = _rc
	if `rc' {
		return scalar rc = `rc'
		return scalar rows = .
		return scalar n_notes = 0
		exit
	}
	local table `"`r(table)'"'
	local links `r(links)'
	local dropped `"`r(dropped)'"'
	local labelstatus `r(labelstatus)'
	local textcols `r(unicode)'
	mata: st_local("description", st_global("r(description)"))

	local columns
	local datalabel
	local nn 0
	frame `f' {
		if c(k) > 0 unab columns : _all
		local dl : data label
		if `"`macval(dl)'"' != usubstr(`"`table'"', 1, 80) local datalabel `"`macval(dl)'"'
		local nn : char _dta[note0]
		if "`nn'" == "" local nn 0
		forvalues i = 1/`nn' {
			mata: st_local("note`i'", st_global("_dta[note`i']"))
		}
		mata: _sqldta_dlg_coltexts(st_local("textcols"), st_local("labelstatus"))
	}

	* r(table) of sqldta is database.schema.table; the object is named here
	* in brackets, as sqldta names it
	local st = substr(`"`table'"', strlen(`"`database'"') + 2, .)
	local dot = strpos(`"`st'"', ".")
	local s = substr(`"`st'"', 1, `dot' - 1)
	local t = substr(`"`st'"', `dot' + 1, .)
	local qdb : subinstr local database "]" "]]", all
	local s : subinstr local s "]" "]]", all
	local t : subinstr local t "]" "]]", all
	local lit [`qdb'].[`s'].[`t']
	local lit : subinstr local lit "'" "''", all
	local sql SELECT CAST(SUM(p.rows) AS float) AS n FROM [`qdb'].sys.partitions AS p ///
		WHERE p.object_id = OBJECT_ID(N'`lit'') AND p.index_id IN (0, 1)
	local rows .
	tempname g
	frame create `g'
	_sqldta_odbc `g' `"`server'"' `"`database'"' sys.partitions `"`sql'"'
	if r(rc) == 0 {
		frame `g': local rows = n[1]
	}
	mata: st_local("text", _sqldta_dlg_text())

	* Returned after the last call of another program that returns results
	return local text `"`macval(text)'"'
	return scalar rc = 0
	return scalar rows = `rows'
	return local links `links'
	return local dropped `"`dropped'"'
	return local labelstatus `labelstatus'
	return local columns `columns'
	return local textcols `textcols'
	return local datalabel `"`macval(datalabel)'"'
	return local description `"`macval(description)'"'
	return scalar n_notes = `nn'
	forvalues i = 1/`nn' {
		return local note`i' `"`macval(note`i')'"'
	}
end


* The text kept by the last description for the column named, as listed.
* Makes no query. Returns r(rc), 0 if the column is known and 111 otherwise,
* and r(text).
program define _sqldta_dlg_column, rclass
	version 16
	syntax , NAME(string)

	local found 0
	mata: st_local("text", _sqldta_dlg_coltext(st_local("name")))
	return local text `"`macval(text)'"'
	return scalar rc = cond(`found', 0, 111)
end


* The columns kept by the last description whose name, variable label or
* value labels contain every word of text, without regard to case, in the
* order of the table, or every column kept if text is empty. Makes no query.
* Returns r(list), r(n), the number of columns in it, and r(k), the number
* kept.
program define _sqldta_dlg_find, rclass
	version 16
	syntax [, TEXT(string)]

	local names
	local n 0
	local k 0
	mata: _sqldta_dlg_match(st_local("text"))
	return local list `names'
	return scalar n = `n'
	return scalar k = `k'
end


* Runs sql, whose column name holds names, and returns them in r(list), as
* described at the top of this file, with r(rc).
program define _sqldta_dlg_list, rclass
	version 16
	args server database object sql

	tempname f
	frame create `f'
	_sqldta_odbc `f' `"`server'"' `"`database'"' `"`object'"' `"`sql'"'
	local rc = r(rc)
	local list
	if `rc' == 0 {
		frame `f' {
			capture confirm variable name
			if _rc == 0 & _N > 0 {
				mata: st_local("list", _sqldta_dlg_names(st_sdata(., "name")))
			}
		}
	}
	return local list `"`list'"'
	return scalar rc = `rc'
end


* ---------------------------------------------------------------------------
* Subcommands run by the dialog
*
* Lists are filled in two ways, as StataCorp showed on Statalist (Hassell,
* 14 Nov 2006). Before the controls exist, in the dialog's PREINIT script,
* the items are written to the dialog's LIST array, from which the control is
* then created. After that, the items of the control and of its LIST are
* replaced together, as the class dynamic_list_control, which Stata ships for
* this, does it (see _sqldta_dlg_setlist).
* ---------------------------------------------------------------------------

* Fills the list of servers from SQLDTA_SERVERS, as a global or in the
* settings file, before the controls exist
program define _sqldta_dlg_onpreinit
	version 16
	_sqldta_settings, quiet
	local servers `"`r(servers)'"'
	.sqldta_dlg.ls_server.Arrdropall
	foreach s of local servers {
		.sqldta_dlg.ls_server.Arrpush "`s'"
	}
end


* Selects the server used last if SQLDTA_DLGREMEMBER is set and a server is
* kept, because Stata's memory of the dialog does not restore it; otherwise
* the server that Stata's memory holds, if any, or the first. Makes the first
* server the default, so that the dialog leaves server() out of the command
* when it is chosen, and fills the lists that depend on the server. Makes
* SQLDTA_LABELTABLE the default of the label-table field, so that the command
* leaves labeltable() out when it is typed; the field itself starts blank,
* which means the same.
program define _sqldta_dlg_onstart
	version 16
	_sqldta_settings, quiet
	local servers `"`r(servers)'"'
	local labeltable `"`r(labeltable)'"'
	local remember `"`r(dlgremember)'"'
	local first : word 1 of `servers'
	.sqldta_dlg.main.cb_server.setdefault `"`first'"'
	if `"`labeltable'"' != "" {
		.sqldta_dlg.main.ed_labeltable.setdefault `"`labeltable'"'
	}
	_sqldta_dlg_value main.cb_server
	local cur `"`r(value)'"'
	if !inlist(`"`remember'"', "", "0") {
		mata: st_local("lastserver", _sqldta_dlg_lastserver())
		if `"`lastserver'"' != "" {
			.sqldta_dlg.main.cb_server.setvalue `"`lastserver'"'
			local cur `"`lastserver'"'
		}
	}
	if `"`cur'"' == "" & `"`first'"' != "" {
		.sqldta_dlg.main.cb_server.setvalue `"`first'"'
	}
	_sqldta_dlg_ondatabases start
end


* As a change of database, but keeping the names chosen or typed
program define _sqldta_dlg_onrefresh
	version 16
	_sqldta_dlg_ondatabases refresh
end


* Refills the databases of the selected server, then the schemas. how is
* start when the dialog opens, refresh for Refresh lists, and empty for a
* change of server. On opening and on a refresh, the database selected is the
* one chosen before if it is listed, or, on a refresh, if it was typed;
* otherwise the server's default database from SQLDTA_DEFAULTDB, if it is
* listed; otherwise the first. On a change of server, the server's default
* database comes first, then the one chosen before, then the first.
program define _sqldta_dlg_ondatabases
	version 16
	args how

	_sqldta_settings, quiet
	local remember `"`r(dlgremember)'"'
	local servers `"`r(servers)'"'
	_sqldta_dlg_value main.cb_server
	local server `"`r(value)'"'
	* A change of server that names the server already listed is not a
	* change: the dialog can report a selection after the helper has filled
	* the lists, and acting on it would replace the database chosen, or kept
	* with SQLDTA_DLGREMEMBER, with the server's default (the maintainer's
	* report of 20 Oct 2026)
	if "`how'" == "" & `"`server'"' != "" {
		local listed
		capture local listed `"`.sqldta_dlg.listedServer.value'"'
		if ustrlower(`"`listed'"') == ustrlower(`"`server'"') exit
	}
	_sqldta_dlg_value main.cb_database
	local cur `"`r(value)'"'
	local list
	local default
	local rc 0
	if `"`server'"' != "" {
		_sqldta_dlg_databases, server(`"`server'"')
		local list `"`r(list)'"'
		local default `"`r(default)'"'
		local rc = r(rc)
	}
	capture .sqldta_dlg.listedServer.setvalue `"`server'"'
	* With SQLDTA_DLGREMEMBER, the dialog reopens at the database chosen last
	* on this server, which Stata's memory of the dialog cannot restore
	* because the list is filled after the controls exist
	if "`how'" == "start" & !inlist(`"`remember'"', "", "0") {
		mata: _sqldta_dlg_getlast(st_local("server"))
		if `"`lastdb'"' != "" local cur `"`lastdb'"'
	}
	local keep = "`how'" == "refresh"
	if "`how'" == "" {
		_sqldta_dlg_setlist main.cb_database `"`list'"' `"`default'"' 0 `"`"`cur'"'"' 1
	}
	else {
		_sqldta_dlg_setlist main.cb_database `"`list'"' `"`cur'"' `keep' `"`"`default'"'"' 1
	}
	if `"`r(value)'"' == "" {
		_sqldta_dlg_clear schemas
		if `"`server'"' == "" & `"`servers'"' == "" {
			local msg No servers are set in SQLDTA_SERVERS, as a global or in the settings file, so none are listed. Type a server and click Refresh lists.
		}
		else if `"`server'"' == "" local msg Choose or type a server.
		else if `rc' local msg The databases on `server' could not be listed; the message is in the Results window. A database can be typed.
		else local msg No databases were found on `server'. A database can be typed.
		_sqldta_dlg_message `"`msg'"'
		exit
	}
	_sqldta_dlg_onschemas `keep' `how'
end


* Refills the schemas of the selected database, then the tables. The schema
* selected is the one before if it is listed, or was typed and keep is 1;
* otherwise SQLDTA_DATASCHEMA, dbo or the first, whichever is listed first.
* how is passed on to the tables.
program define _sqldta_dlg_onschemas
	version 16
	args keep how

	_sqldta_settings, quiet
	local remember `"`r(dlgremember)'"'
	local dataschema `"`r(dataschema)'"'
	_sqldta_dlg_value main.cb_server
	local server `"`r(value)'"'
	_sqldta_dlg_value main.cb_database
	local database `"`r(value)'"'
	_sqldta_dlg_value main.cb_schema
	local cur `"`r(value)'"'
	if "`how'" == "start" & !inlist(`"`remember'"', "", "0") {
		mata: _sqldta_dlg_getlast(st_local("server"))
		if `"`lastdb'"' == `"`database'"' & `"`lastschema'"' != "" local cur `"`lastschema'"'
	}
	local list
	local rc 0
	if `"`database'"' != "" {
		_sqldta_dlg_schemas, server(`"`server'"') database(`"`database'"')
		local list `"`r(list)'"'
		local rc = r(rc)
	}
	_sqldta_dlg_setlist main.cb_schema `"`list'"' `"`cur'"' "`keep'" `"`dataschema' dbo"' 1
	if `"`r(value)'"' == "" {
		_sqldta_dlg_clear tables
		if `rc' local msg The schemas of `database' could not be listed; the message is in the Results window.
		else local msg No tables or views were found in `database'.
		_sqldta_dlg_message `"`msg'"'
		exit
	}
	_sqldta_dlg_ontables `how'
end


* Refills the tables and views of the selected schema, with the entry
* "(none chosen)" first. A list box with items always has one selected, the
* first unless another is chosen, so the entry is selected when the dialog
* opens (how is start) and whenever the table selected before is not listed,
* and then nothing is described; otherwise that table stays selected and is
* described.
program define _sqldta_dlg_ontables
	version 16
	args how

	_sqldta_settings, quiet
	local remember `"`r(dlgremember)'"'
	_sqldta_dlg_value main.cb_server
	local server `"`r(value)'"'
	_sqldta_dlg_value main.cb_database
	local database `"`r(value)'"'
	_sqldta_dlg_value main.cb_schema
	local schema `"`r(value)'"'
	_sqldta_dlg_value main.lb_table
	local cur `"`r(value)'"'
	if "`how'" == "start" local cur
	local list
	local rc 0
	if `"`schema'"' != "" {
		_sqldta_dlg_tables, server(`"`server'"') database(`"`database'"') schema(`"`schema'"')
		local list `"`r(list)'"'
		local rc = r(rc)
	}
	if `"`list'"' != "" & !inlist(`"`remember'"', "", "0") {
		mata: _sqldta_dlg_keeplast(st_local("server"), st_local("database"), st_local("schema"))
	}
	mata: st_local("none", _sqldta_dlg_none())
	local items
	if `"`list'"' != "" local items `""`none'" `list'"'
	_sqldta_dlg_setlist main.lb_table `"`items'"' `"`cur'"' 0 `"`"`none'"'"' 0
	if `"`r(value)'"' == "" | `"`r(value)'"' == `"`none'"' {
		_sqldta_dlg_clear columns
		if `rc' local msg The tables of `database'.`schema' could not be listed; the message is in the Results window.
		else if `"`list'"' == "" local msg No tables or views were found in `database'.`schema'.
		else local msg Choose a table or view to see its description.
		_sqldta_dlg_message `"`msg'"'
		exit
	}
	_sqldta_dlg_ondescribe
end


* Shows the description of the selected table, fills the list of its columns
* on the Advanced tab, as the field Find leaves it, selects the first column
* and shows its labels
program define _sqldta_dlg_ondescribe
	version 16

	_sqldta_dlg_value main.cb_server
	local server `"`r(value)'"'
	_sqldta_dlg_value main.cb_database
	local database `"`r(value)'"'
	_sqldta_dlg_value main.cb_schema
	local schema `"`r(value)'"'
	_sqldta_dlg_value main.lb_table
	local table `"`r(value)'"'
	_sqldta_dlg_value main.ed_labeltable
	local labeltable `"`r(value)'"'
	mata: st_local("none", _sqldta_dlg_none())
	if `"`table'"' == `"`none'"' local table
	if `"`table'"' == "" {
		_sqldta_dlg_clear columns
		_sqldta_dlg_message "Choose a table or view to see its description."
		exit
	}
	local dataset `"`table'"'
	if `"`schema'"' != "" local dataset `"`schema'.`table'"'
	local lt
	if `"`labeltable'"' != "" local lt labeltable(`"`labeltable'"')

	_sqldta_dlg_describe, server(`"`server'"') database(`"`database'"') dataset(`"`dataset'"') `lt'
	local rc = r(rc)
	local columns `r(columns)'
	* Cut to about what the description box shows, 230 by 360 pixels
	mata: st_local("text", _sqldta_dlg_clip(st_global("r(text)"), 720))
	* sqldta runs under capture in the description, so its own message is not
	* shown; loading the table shows it
	if `rc' {
		local text sqldta stopped with error `rc' on `database'.`dataset'; loading the table shows the reason.
	}
	_sqldta_dlg_message `"`macval(text)'"'
	_sqldta_dlg_showlist
end


* Applies the text of the field Find to the list of columns, unless that
* text is already applied: the dialog queues this once for each keystroke,
* and by the time it runs the text may be the one applied by an earlier run
program define _sqldta_dlg_onfind
	version 16
	_sqldta_dlg_value advanced.ed_find
	mata: st_local("same", strofreal(_sqldta_dlg_sameshown(st_global("r(value)"))))
	if `same' exit
	_sqldta_dlg_showlist
end


* Fills the list of columns on the Advanced tab with the columns of the table
* described that the text of the field Find leaves, selects the first and
* shows its labels, and says below the list how many are shown
program define _sqldta_dlg_showlist
	version 16
	_sqldta_dlg_value advanced.ed_find
	mata: _sqldta_dlg_setshown(st_global("r(value)"))
	_sqldta_dlg_find, text(`"`r(value)'"')
	local n = r(n)
	local k = r(k)
	local list `r(list)'
	_sqldta_dlg_setlist advanced.lb_column "`list'" "" 0 "" 1
	_sqldta_dlg_showcolumn `"`r(value)'"'
	local msg " "
	if `k' > 0 {
		local s = cond(`k' == 1, "", "s")
		if `n' == `k' local msg `k' column`s'
		else local msg `n' of `k' column`s' shown
	}
	.sqldta_dlg.advanced.tx_shown.setlabel `"`msg'"'
end


* Adds every column that the list shows, as the field Find leaves it, to the
* end of the columns to load (target select) or of the Unicode columns
* (unicode). The names are valid Stata names, so they need no quotes.
program define _sqldta_dlg_onaddall
	version 16
	args target

	if !inlist("`target'", "select", "unicode") {
		display as error "sqldta_dlg addall: select or unicode expected"
		exit 198
	}
	_sqldta_dlg_value advanced.ed_find
	_sqldta_dlg_find, text(`"`r(value)'"')
	local list `r(list)'
	if "`list'" != "" {
		.sqldta_dlg.advanced.ed_`target'.append `" `list'"'
	}
end


* Shows the labels of the column selected on the Advanced tab
program define _sqldta_dlg_oncolumn
	version 16
	_sqldta_dlg_value advanced.lb_column
	_sqldta_dlg_showcolumn `"`r(value)'"'
end


* Shows in the box beside the list of columns the text that the last
* description kept for the column named, cut to what the box shows
program define _sqldta_dlg_showcolumn
	version 16
	args name

	local text
	if `"`name'"' == "" {
		local text Choose a table on the Import tab, then a column here to see its labels.
	}
	else {
		_sqldta_dlg_column, name(`"`name'"')
		if r(rc) == 0 {
			* Cut to about what the box Column chosen shows, 400 by 225 pixels
			mata: st_local("text", _sqldta_dlg_clip(st_global("r(text)"), 800))
		}
		else local text The labels of `name' are not known; choose the table again on the Import tab.
	}
	.sqldta_dlg.advanced.tb_column.setlabel `"`macval(text)'"'
end


* Empties the list named, and the lists and description that depend on it:
* schemas, tables or columns
program define _sqldta_dlg_clear
	version 16
	args what

	if "`what'" == "schemas" _sqldta_dlg_setlist main.cb_schema "" "" 0 "" 0
	if inlist("`what'", "schemas", "tables") _sqldta_dlg_setlist main.lb_table "" "" 0 "" 0
	_sqldta_dlg_setlist advanced.lb_column "" "" 0 "" 0
	_sqldta_dlg_showcolumn ""
	.sqldta_dlg.advanced.tx_shown.setlabel " "
	* So that Find does not bring back the columns of a table no longer chosen
	mata: _sqldta_dlg_store(J(0, 1, ""), J(0, 1, ""), J(0, 1, ""))
	mata: rmexternal("_sqldta_dlg_shown")
end


* Returns r(value), the value of a control of the dialog, such as
* main.cb_server
program define _sqldta_dlg_value, rclass
	version 16
	args control

	return local value `"`.sqldta_dlg.`control'.value'"'
end


* Replaces the items of the control named, such as main.lb_table, with the
* names in items, and selects one: cur if it is listed, or if keep is 1 and
* cur is not empty; otherwise the first of the names in pref that is listed;
* otherwise, if first is 1, the first item. Returns r(value), the name
* selected, which is empty if none is.
*
* The items are replaced as dynamic_list_control does it, in the control and
* in the LIST named by its contents() together, but without that class's
* setList, which ends with setvalue "", and setvalue "" on a LISTBOX stops
* with error 111 (trace of 19 Oct 2026).
program define _sqldta_dlg_setlist, rclass
	version 16
	args control items cur keep pref first

	local lname `.sqldta_dlg.`control'.contents'
	.sqldta_dlg.`lname'.Arrdropall
	.sqldta_dlg.`control'.clearlist
	foreach item of local items {
		.sqldta_dlg.`control'.additem `"`item'"'
		.sqldta_dlg.`lname'.Arrpush `"`item'"'
	}

	local value
	if `"`cur'"' != "" {
		if "`keep'" == "1" | `: list posof `"`cur'"' in items' local value `"`cur'"'
	}
	if `"`value'"' == "" {
		foreach p of local pref {
			if `"`value'"' == "" & `: list posof `"`p'"' in items' local value `"`p'"'
		}
	}
	if `"`value'"' == "" & "`first'" == "1" gettoken value : items
	if `"`value'"' != "" {
		.sqldta_dlg.`control'.setvalue `"`value'"'
	}
	return local value `"`value'"'
end


* Shows text in the description box of the Import tab
program define _sqldta_dlg_message
	version 16
	args text

	.sqldta_dlg.main.tb_desc.setlabel `"`macval(text)'"'
end



version 16
mata:

// The first entry of the list of tables, which stands for no table. The same
// text is in sqldta.dlg, where OK, Submit and Copy refuse it.
string scalar _sqldta_dlg_none()
{
	return("(none chosen)")
}

// Joins the names in s into a list separated by spaces, with a name that
// contains a space in double quotes. Leaves out empty names, names with
// leading or trailing spaces, and names that contain a double quote, a
// dollar sign, a dot, a backslash or a backquote.
string scalar _sqldta_dlg_names(string colvector s)
{
	string scalar list, n
	real scalar i

	list = ""
	for (i = 1; i <= rows(s); i++) {
		n = s[i]
		if (n == "" | n != strtrim(n)) continue
		if (strpos(n, char(34)) | strpos(n, char(36)) | strpos(n, char(46)) | strpos(n, char(92)) | strpos(n, char(96))) continue
		if (strpos(n, " ")) n = char(34) + n + char(34)
		list = list + (list == "" ? "" : " ") + n
	}
	return(list)
}

// The description of a table that the dialog shows, made from the locals of
// _sqldta_dlg_describe. The facts come first, because the dialog's box shows
// only the start of a long description: the number of rows and of columns,
// the linked tables, whether the label table was found, then the data label
// and the DatasetDescription paragraph of PropertyCode 1, and last the
// columns left out. Dataset notes are not shown (the maintainer's choice of
// 28 Oct 2026). Each part ends with a full stop.
string scalar _sqldta_dlg_text()
{
	string scalar t, status
	real scalar rows, k

	rows = strtoreal(st_local("rows"))
	k = cols(tokens(st_local("columns")))
	t = _sqldta_dlg_sentence("", (rows < . ? "About " + strtrim(strofreal(rows, "%20.0fc")) + (rows == 1 ? " row" : " rows") : "A view, so the number of rows is not known") + "; " + strofreal(k) + (k == 1 ? " column" : " columns") + " can be loaded")
	if (st_local("links") != "") t = _sqldta_dlg_sentence(t, "Linked tables: " + subinstr(st_local("links"), " ", ", "))
	status = st_local("labelstatus")
	if (status == "notfound") t = _sqldta_dlg_sentence(t, "The label table was not found, so there is no description")
	else if (status == "failed") t = _sqldta_dlg_sentence(t, "The label table could not be read, so there is no description")
	else {
		t = _sqldta_dlg_sentence(t, st_local("datalabel"))
		if (st_local("description") != "") t = _sqldta_dlg_sentence(t, st_local("description"))
		else t = _sqldta_dlg_sentence(t, "No dataset description available")
	}
	if (st_local("dropped") != "") t = _sqldta_dlg_sentence(t, "Columns left out: " + st_local("dropped"))
	return(t)
}

// Makes the text that the dialog shows for each variable of the current
// frame, which holds the empty load of the table described, and keeps it for
// _sqldta_dlg_coltext(): the variable label; whether the column is a char,
// varchar or text column, one of the words of textcols; its value labels,
// with their number, in order of code; and its notes, in order. Each part
// ends with a full stop. A column with none of these says so, or that the
// label table was not found or could not be read, as status gives it. Also
// keeps, for _sqldta_dlg_match(), the name, variable label and value labels
// of each column in lower case, which Find searches.
void _sqldta_dlg_coltexts(string scalar textcols, string scalar status)
{
	string colvector names, texts, keys, vtext
	string rowvector tc
	string scalar t, v, vl, s, nt, none
	real colvector values, o
	real scalar i, j, n, k

	k = st_nvar()
	names = J(k, 1, "")
	texts = J(k, 1, "")
	keys = J(k, 1, "")
	tc = tokens(textcols)
	if (status == "notfound") none = "The label table was not found, so there are no labels"
	else if (status == "failed") none = "The label table could not be read, so there are no labels"
	else none = "No variable label, value labels or notes in the label table"
	for (i = 1; i <= k; i++) {
		v = st_varname(i)
		names[i] = v
		keys[i] = v + " " + st_varlabel(i)
		t = _sqldta_dlg_sentence("", st_varlabel(i))
		s = ""
		vl = st_varvaluelabel(i)
		if (vl != "") {
			if (st_vlexists(vl)) {
				values = .
				vtext = ""
				st_vlload(vl, values, vtext)
				o = order(values, 1)
				n = rows(values)
				s = "Value labels (" + strofreal(n) + "): "
				for (j = 1; j <= n; j++) {
					s = s + (j > 1 ? "; " : "") + strtrim(strofreal(values[o[j]], "%12.0f")) + " " + vtext[o[j]]
					keys[i] = keys[i] + " " + vtext[o[j]]
				}
			}
		}
		n = strtoreal(st_global(v + "[note0]"))
		if (n >= . | n < 0) n = 0
		nt = ""
		for (j = 1; j <= n; j++) {
			nt = _sqldta_dlg_sentence(nt, st_global(v + "[note" + strofreal(j) + "]"))
		}
		if (nt != "") nt = (n == 1 ? "Note: " : "Notes: ") + nt
		if (t == "" & s == "" & nt == "") t = _sqldta_dlg_sentence("", none)
		if (anyof(tc, v)) t = _sqldta_dlg_sentence(t, "A char, varchar or text column, loaded as it is unless it is named under Unicode columns")
		t = _sqldta_dlg_sentence(t, s)
		t = _sqldta_dlg_sentence(t, nt)
		texts[i] = t
		keys[i] = ustrlower(keys[i])
	}
	_sqldta_dlg_store(names, texts, keys)
}

// Keeps the names, texts and search keys of the columns of the table last
// described, in the Mata external variable _sqldta_dlg_columns, until the
// next description
void _sqldta_dlg_store(string colvector names, string colvector texts, string colvector keys)
{
	pointer() scalar p

	p = findexternal("_sqldta_dlg_columns")
	if (p == NULL) p = crexternal("_sqldta_dlg_columns")
	*p = (names, texts, keys)
}

// The names of the kept columns whose search key contains every word of q,
// without regard to case, in the order of the table; all of them if q has no
// word. Sets the locals names, n (the number found) and k (the number kept).
void _sqldta_dlg_match(string scalar q)
{
	pointer() scalar p
	string rowvector w
	string scalar names
	real scalar i, j, n, k, ok

	names = ""
	n = 0
	k = 0
	p = findexternal("_sqldta_dlg_columns")
	if (p != NULL) {
		if (eltype(*p) == "string" & cols(*p) == 3) k = rows(*p)
	}
	w = tokens(ustrlower(q))
	for (i = 1; i <= k; i++) {
		ok = 1
		for (j = 1; j <= cols(w); j++) {
			if (!ustrpos((*p)[i, 3], w[j])) {
				ok = 0
				break
			}
		}
		if (ok) {
			names = names + (n ? " " : "") + (*p)[i, 1]
			n++
		}
	}
	st_local("names", names)
	st_local("n", strofreal(n))
	st_local("k", strofreal(k))
}

// Keeps the text of Find that the list of columns shows, in the Mata external
// variable _sqldta_dlg_shown, so that the helper, queued once for each
// keystroke, refills the list only when the text has changed
void _sqldta_dlg_setshown(string scalar q)
{
	pointer() scalar p

	p = findexternal("_sqldta_dlg_shown")
	if (p == NULL) p = crexternal("_sqldta_dlg_shown")
	*p = q
}

// 1 if q is the text of Find that the list of columns shows, 0 otherwise
real scalar _sqldta_dlg_sameshown(string scalar q)
{
	pointer() scalar p

	p = findexternal("_sqldta_dlg_shown")
	if (p == NULL) return(0)
	if (eltype(*p) != "string" | rows(*p) != 1 | cols(*p) != 1) return(0)
	return(*p == q)
}

// With SQLDTA_DLGREMEMBER, keeps the database and schema chosen last on each
// server, in the Mata external variable _sqldta_dlg_last, a string matrix of
// server, database and schema, for the next opening of the dialog. The row
// of the server used last is the last row.
void _sqldta_dlg_keeplast(string scalar server, string scalar database, string scalar schema)
{
	pointer() scalar p
	string matrix M
	real colvector keep
	real scalar i

	p = findexternal("_sqldta_dlg_last")
	if (p == NULL) p = crexternal("_sqldta_dlg_last")
	M = J(0, 3, "")
	if (eltype(*p) == "string" & cols(*p) == 3) M = *p
	keep = J(rows(M), 1, 1)
	for (i = 1; i <= rows(M); i++) {
		if (ustrlower(M[i, 1]) == ustrlower(server)) keep[i] = 0
	}
	if (rows(M) > 0) M = select(M, keep)
	*p = M \ (server, database, schema)
}

// With SQLDTA_DLGREMEMBER, the server used last, or "" if none is kept
string scalar _sqldta_dlg_lastserver()
{
	pointer() scalar p

	p = findexternal("_sqldta_dlg_last")
	if (p == NULL) return("")
	if (eltype(*p) != "string" | cols(*p) != 3 | rows(*p) == 0) return("")
	return((*p)[rows(*p), 1])
}

// Sets the locals lastdb and lastschema to the database and schema kept for
// the server, or to "" if none is kept
void _sqldta_dlg_getlast(string scalar server)
{
	pointer() scalar p
	real scalar i

	st_local("lastdb", "")
	st_local("lastschema", "")
	p = findexternal("_sqldta_dlg_last")
	if (p == NULL) return
	if (eltype(*p) != "string" | cols(*p) != 3) return
	for (i = 1; i <= rows(*p); i++) {
		if (ustrlower((*p)[i, 1]) == ustrlower(server)) {
			st_local("lastdb", (*p)[i, 2])
			st_local("lastschema", (*p)[i, 3])
			return
		}
	}
}

// The text kept for the column named, or "" if it is not known; sets the
// local found to 1 if it is known and to 0 otherwise
string scalar _sqldta_dlg_coltext(string scalar name)
{
	pointer() scalar p
	real scalar i

	st_local("found", "0")
	p = findexternal("_sqldta_dlg_columns")
	if (p == NULL) return("")
	if (eltype(*p) != "string" | cols(*p) != 3) return("")
	for (i = 1; i <= rows(*p); i++) {
		if ((*p)[i, 1] == name) {
			st_local("found", "1")
			return((*p)[i, 2])
		}
	}
	return("")
}

// The first n characters of s, cut at a space and followed by " ..." if s is
// longer, for the dialog's text boxes, which do not scroll
string scalar _sqldta_dlg_clip(string scalar s, real scalar n)
{
	string scalar c
	real scalar j

	if (ustrlen(s) <= n) return(s)
	c = usubstr(s, 1, n)
	for (j = ustrlen(c); j > 1; j--) {
		if (usubstr(c, j, 1) == " ") break
	}
	if (j > 1) c = usubstr(c, 1, j - 1)
	return(c + " ...")
}

// Appends the sentence s to the text t, with a space between them and a full
// stop after s unless s already ends with one, a question mark or an
// exclamation mark
string scalar _sqldta_dlg_sentence(string scalar t, string scalar s)
{
	string scalar e

	s = strtrim(s)
	if (s == "") return(t)
	e = usubstr(s, ustrlen(s), 1)
	if (e != "." & e != "?" & e != "!") s = s + "."
	return(t == "" ? s : t + " " + s)
}

end
