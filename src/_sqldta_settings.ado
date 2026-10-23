*! version 1.1.0 23oct2026
* _sqldta_settings: the settings of sqldta, for sqldta, for its dialog helper
* sqldta_dlg and for _sqldta_odbc
*
*   _sqldta_settings [, server(name) database(name) connect probe display quiet]
*
* Each setting is the global macro of its name if that is set, otherwise the
* line of that name in the settings file, otherwise empty; the callers then
* apply the built-in defaults. The settings file is the first file named
* sqldta_site.cfg along the ado-path, which includes the current directory.
* It is read on each call, so that macro drop _all, which a user's script may
* run and which removes the globals, does not remove the site's settings (the
* maintainer's concern of 21 Oct 2026). Each line of the file holds the name
* of a setting, such as SQLDTA_SERVERS, in any case, then a space or a tab and
* its value; blank lines and lines that begin with * or // are passed over.
* SQLDTA_CONNECTION may be given on several lines, the connection templates to
* try in order; for the other settings a later line replaces an earlier one.
* A line with any other name is passed over, with a note unless quiet is
* given.
*
* Returns r(file), the file read, or empty if none is found; r(servers),
* r(databases), r(defaultdb), r(dlgremember), r(dataschema), r(labeltable)
* and r(dttext); r(nconnections) and r(connection1), r(connection2) and so on,
* the connection templates: the global SQLDTA_CONNECTION alone if it is set,
* otherwise the SQLDTA_CONNECTION lines of the file; r(ignored), the numbers
* of the lines of the file passed over; and r(server), server() if given,
* otherwise the first of r(servers).
*
* connect chooses the connection to r(server) and returns it in
* r(connection), a template, or dsn for the ODBC data source named after the
* server; r(template), its number among the templates, 0 for the data source
* that sqldta falls back on; and r(probed), 1 if the templates were tried in
* this call. A template may itself be the word dsn. The global, a single
* template, or no template at all, is used as it is. Several templates are
* tried in order with SELECT 1, and the first that connects is used; a note
* says so when it is not the first, and when none connects, in which case
* the data source is used. The choice for the templates of the file is kept
* in the Mata external variable _sqldta_conn, one row for each server, which
* _sqldta_odbc reads, so that the file is not read for each query and the
* templates are tried once per session for each server, and again only when
* they change or none connected. probe tries them again although a choice is
* kept. display shows the settings and where each comes from and, with
* connect, tries every template and shows the result and time of each; it
* uses timer 100. These attempts call odbc load directly, quietly, rather
* than through _sqldta_odbc, because their failures are expected.
program define _sqldta_settings, rclass
	version 16
	syntax [, SERver(string) DATABase(string) CONNECT PROBE DISPLAY QUIET]

	local file
	capture findfile sqldta_site.cfg
	if _rc == 0 local file `"`r(fn)'"'

	* The values, the globals over the file, read in Mata so that $ and
	* backquotes in them are kept. Sets the locals servers, databases,
	* defaultdb, dlgremember, dataschema, labeltable and dttext, each with
	* src_<name>, global, file or empty; nconn, conn1, conn2 and so on;
	* connsrc; key, the file's templates joined; and ignored.
	mata: _sqldta_cfg_read(st_local("file"), "`quiet'" != "")

	if `"`server'"' == "" gettoken server : servers

	local probed 0
	local template .
	local connection
	if "`connect'" != "" & `"`server'"' != "" {
		local db `"`database'"'
		if `"`db'"' == "" local db master
		local kept
		if "`connsrc'" == "file" & `nconn' > 1 & "`probe'`display'" == "" {
			mata: _sqldta_cfg_kept(st_local("server"), st_local("key"))
		}
		local ok 1
		if `"`kept'"' != "" {
			local connection `"`macval(kept)'"'
			local template `keptnum'
		}
		else if `nconn' == 0 {
			local connection dsn
			local template 0
		}
		else if `nconn' == 1 & "`display'" == "" {
			local connection `"`macval(conn1)'"'
			local template 1
		}
		else {
			tempname f
			frame create `f'
			local chosen 0
			forvalues i = 1/`nconn' {
				if `chosen' & "`display'" == "" continue, break
				local t `"`macval(conn`i')'"'
				if ustrlower(`"`macval(t)'"') == "dsn" local c dsn(`"`server'"')
				else {
					local cs : subinstr local t "%server%" `"`server'"', all
					local cs : subinstr local cs "%database%" `"`db'"', all
					local c connectionstring(`"`macval(cs)'"')
				}
				if "`display'" != "" {
					timer clear 100
					timer on 100
				}
				capture quietly frame `f': odbc load, exec("SELECT 1 AS sqldta_probe") `c' clear
				local rc`i' = _rc
				if "`display'" != "" {
					timer off 100
					quietly timer list 100
					local sec`i' = r(t100)
				}
				if `rc`i'' == 0 & `chosen' == 0 local chosen `i'
			}
			local probed 1
			if `nconn' == 1 {
				* Only display tries a single template, and it is used whether
				* or not it connects, as a load uses it, so that the display
				* says what a load does
				local connection `"`macval(conn1)'"'
				local template 1
			}
			else if `chosen' {
				local connection `"`macval(conn`chosen')'"'
				local template `chosen'
				if `chosen' > 1 & "`display'" == "" {
					mata: _sqldta_cfg_note("later", st_local("server"), `chosen', `nconn', st_local("connection"))
				}
			}
			else {
				local connection dsn
				local template 0
				local ok 0
				if "`display'" == "" {
					mata: _sqldta_cfg_note("none", st_local("server"), 0, `nconn', "")
				}
			}
		}
		if ustrlower(`"`macval(connection)'"') == "dsn" local connection dsn
		if "`connsrc'" != "global" {
			mata: _sqldta_cfg_keep(st_local("server"), st_local("key"), st_local("connection"), "`template'", "`ok'")
		}
	}

	if "`display'" != "" {
		mata: _sqldta_cfg_show(st_local("file"), "`connect'" != "" & st_local("server") != "")
	}

	return local file `"`file'"'
	foreach n in servers databases defaultdb dlgremember dataschema labeltable dttext {
		return local `n' `"`macval(`n')'"'
	}
	return scalar nconnections = `nconn'
	forvalues i = 1/`nconn' {
		return local connection`i' `"`macval(conn`i')'"'
	}
	return local ignored `ignored'
	return local server `"`server'"'
	if "`connect'" != "" & `"`server'"' != "" {
		return local connection `"`macval(connection)'"'
		return scalar template = `template'
		return scalar probed = `probed'
		if "`display'" != "" {
			forvalues i = 1/`nconn' {
				return scalar rc`i' = `rc`i''
				return scalar sec`i' = `sec`i''
			}
		}
	}
end


version 16
mata:

// Reads the settings file fn, if fn is not "", and the globals, and sets the
// locals described in the program above. A UTF-8 byte-order mark, tabs and
// carriage returns are allowed, so that a file saved by Notepad on Windows
// reads as one saved elsewhere.
void _sqldta_cfg_read(string scalar fn, real scalar quiet)
{
	string colvector lines, conn
	string rowvector names, fval
	real rowvector fhas
	real vector k
	string scalar line, name, value, word, g, ln, ignored
	real scalar i, j, n

	names = ("SERVERS", "DATABASES", "DEFAULTDB", "DLGREMEMBER", "DATASCHEMA", "LABELTABLE", "DTTEXT")
	fval = J(1, cols(names), "")
	fhas = J(1, cols(names), 0)
	conn = J(0, 1, "")
	ignored = ""
	if (fn != "") {
		lines = cat(fn)
		for (i = 1; i <= rows(lines); i++) {
			line = lines[i]
			if (i == 1 & substr(line, 1, 3) == char((239, 187, 191))) line = substr(line, 4, .)
			line = subinstr(line, char(13), "")
			line = strtrim(subinstr(line, char(9), " "))
			if (line == "" | substr(line, 1, 1) == "*" | substr(line, 1, 2) == "//") continue
			j = strpos(line, " ")
			if (j == 0) {
				word = line
				value = ""
			}
			else {
				word = substr(line, 1, j - 1)
				value = strtrim(substr(line, j + 1, .))
			}
			name = strupper(word)
			if (substr(name, 1, 7) == "SQLDTA_") name = substr(name, 8, .)
			else name = ""
			if (name == "CONNECTION") {
				if (value != "") conn = conn \ value
				continue
			}
			k = selectindex(names :== name)
			if (name != "" & length(k) == 1) {
				fval[k] = value
				fhas[k] = 1
				continue
			}
			ignored = ignored + " " + strofreal(i)
			if (!quiet) {
				printf("{txt}note: line %g of the settings file %s is passed over, because %s is not a setting of sqldta\n",
					i, _sqldta_cfg_esc(fn), _sqldta_cfg_esc(word))
			}
		}
	}
	for (i = 1; i <= cols(names); i++) {
		ln = strlower(names[i])
		g = st_global("SQLDTA_" + names[i])
		if (g != "") {
			st_local(ln, g)
			st_local("src_" + ln, "global")
		}
		else if (fhas[i]) {
			st_local(ln, fval[i])
			st_local("src_" + ln, "file")
		}
		else {
			st_local(ln, "")
			st_local("src_" + ln, "")
		}
	}
	g = st_global("SQLDTA_CONNECTION")
	st_local("key", "")
	if (g != "") {
		conn = g
		st_local("connsrc", "global")
	}
	else if (rows(conn) > 0) {
		st_local("connsrc", "file")
		st_local("key", invtokens(conn', char(10)))
	}
	else st_local("connsrc", "")
	n = rows(conn)
	st_local("nconn", strofreal(n))
	for (i = 1; i <= n; i++) st_local("conn" + strofreal(i), conn[i])
	st_local("ignored", strtrim(ignored))
}

// Sets the locals kept and keptnum to the connection kept for the server and
// its number, if one was chosen from the same templates, key, and connected;
// otherwise kept is "". _sqldta_conn is a string matrix with one row for each
// server: the server in lower case, the templates joined, the connection
// chosen (a template, or dsn), its number, and 1 if it connected or 0 if
// sqldta fell back on the data source.
void _sqldta_cfg_kept(string scalar server, string scalar key)
{
	pointer() scalar p
	real scalar i

	st_local("kept", "")
	st_local("keptnum", "")
	p = findexternal("_sqldta_conn")
	if (p == NULL) return
	if (eltype(*p) != "string" | cols(*p) != 5) return
	for (i = 1; i <= rows(*p); i++) {
		if ((*p)[i, 1] == ustrlower(server) & (*p)[i, 2] == key & (*p)[i, 5] == "1") {
			st_local("kept", (*p)[i, 3])
			st_local("keptnum", (*p)[i, 4])
			return
		}
	}
}

// Keeps the connection chosen for the server, replacing any row kept for it
void _sqldta_cfg_keep(string scalar server, string scalar key, string scalar conn, string scalar num, string scalar ok)
{
	pointer() scalar p
	string matrix M
	real colvector keep
	real scalar i

	p = findexternal("_sqldta_conn")
	if (p == NULL) p = crexternal("_sqldta_conn")
	M = J(0, 5, "")
	if (eltype(*p) == "string" & cols(*p) == 5) M = *p
	keep = J(rows(M), 1, 1)
	for (i = 1; i <= rows(M); i++) {
		if (M[i, 1] == ustrlower(server)) keep[i] = 0
	}
	if (rows(M) > 0) M = select(M, keep)
	*p = M \ (ustrlower(server), key, conn, num, ok)
}

// The notes shown when the connection used is not the first template (what
// is later), or when no template connected (none)
void _sqldta_cfg_note(string scalar what, string scalar server, real scalar k, real scalar n, string scalar conn)
{
	string scalar d

	if (what == "later") {
		d = _sqldta_cfg_driver(conn)
		if (ustrlower(conn) == "dsn") d = "the ODBC data source named after the server"
		else if (d != "") d = "driver " + d
		else d = "connection template " + strofreal(k) + " of " + strofreal(n)
		printf("{txt}note: connected to %s via fallback %s;\n", _sqldta_cfg_esc(server), d)
		printf("{txt}  see {cmd:sqldta settings}\n")
	}
	else {
		printf("{txt}note: none of the %g connection templates connected to %s,\n", n, _sqldta_cfg_esc(server))
		printf("{txt}  so sqldta connects through the ODBC data source named %s;\n", _sqldta_cfg_esc(server))
		printf("{txt}  type {cmd:sqldta settings} to see each result\n")
	}
}

// Shows the settings and where each comes from, and, if conn is 1, the
// result and time of each connection template, from the locals of the
// program above
void _sqldta_cfg_show(string scalar fn, real scalar conn)
{
	string rowvector names
	string scalar ln, src, v
	real scalar i, n, k

	printf("\n{txt}Settings of sqldta\n")
	if (fn != "") printf("{txt}  settings file: {res}%s\n", _sqldta_cfg_esc(fn))
	else printf("{txt}  settings file: none; no file sqldta_site.cfg was found along the ado-path\n")
	if (st_local("ignored") != "") printf("{txt}  lines of the file passed over: %s\n", st_local("ignored"))
	names = ("SERVERS", "DATABASES", "DEFAULTDB", "DLGREMEMBER", "DATASCHEMA", "LABELTABLE", "DTTEXT")
	for (i = 1; i <= cols(names); i++) {
		ln = strlower(names[i])
		src = st_local("src_" + ln)
		v = st_local(ln)
		printf("{txt}  %-19s {res}%s{txt}%s\n", "SQLDTA_" + names[i], _sqldta_cfg_esc(v),
			(src == "" ? "(not set)" : (v == "" ? "(empty, from the " + src + ")" : "  (from the " + src + ")")))
	}
	n = strtoreal(st_local("nconn"))
	src = st_local("connsrc")
	if (n == 0) printf("{txt}  %-19s (not set)\n", "SQLDTA_CONNECTION")
	for (i = 1; i <= n; i++) {
		printf("{txt}  %-19s %g. {res}%s{txt}  (from the %s)\n", (i == 1 ? "SQLDTA_CONNECTION" : ""), i,
			_sqldta_cfg_esc(_sqldta_cfg_mask(st_local("conn" + strofreal(i)))), src)
	}
	if (!conn) return
	printf("\n{txt}Connection to %s\n", _sqldta_cfg_esc(st_local("server")))
	for (i = 1; i <= n; i++) {
		printf("{txt}  template %g: %s, r(%s), %s seconds\n", i,
			(st_local("rc" + strofreal(i)) == "0" ? "connects" : "does not connect"),
			st_local("rc" + strofreal(i)), strtrim(strofreal(strtoreal(st_local("sec" + strofreal(i))), "%9.2f")))
	}
	k = strtoreal(st_local("template"))
	if (k > 0) printf("{txt}  sqldta uses template %g, %s\n", k, _sqldta_cfg_what(st_local("connection")))
	else printf("{txt}  sqldta uses the ODBC data source named %s\n", _sqldta_cfg_esc(st_local("server")))
	if (n == 1) {
		printf("{txt}  A single template is used whether or not it connects; sqldta falls back on\n")
		printf("{txt}  the ODBC data source only when there are several and none connects.\n")
	}
}

// A short description of a connection, for notes: the ODBC data source, the
// driver that a template names, or a template that names none
string scalar _sqldta_cfg_what(string scalar conn)
{
	string scalar d

	if (ustrlower(conn) == "dsn") return("the ODBC data source named after the server")
	d = _sqldta_cfg_driver(conn)
	if (d != "") return("which names the driver " + d)
	return("which names no driver")
}

// The driver that a template names, written as SMCL, or "" if it names none
string scalar _sqldta_cfg_driver(string scalar conn)
{
	if (ustrregexm(conn, "(?i)driver\s*=\s*\{([^}]*)\}")) return(_sqldta_cfg_esc(ustrregexs(1)))
	if (ustrregexm(conn, "(?i)driver\s*=\s*([^;]*)")) return(_sqldta_cfg_esc(strtrim(ustrregexs(1))))
	return("")
}

// A template with the value of PWD or Password replaced by ****, for display
string scalar _sqldta_cfg_mask(string scalar s)
{
	return(ustrregexra(s, "(?i)((pwd|password)\s*=\s*)(\{[^}]*\}|[^;]*)", char(36) + "1****"))
}

// Text with its braces written as SMCL, so that printf shows it as it is
string scalar _sqldta_cfg_esc(string scalar s)
{
	string scalar r

	r = subinstr(s, "{", char(1))
	r = subinstr(r, "}", char(2))
	r = subinstr(r, char(1), "{c -(}")
	return(subinstr(r, char(2), "{c )-}"))
}

end
