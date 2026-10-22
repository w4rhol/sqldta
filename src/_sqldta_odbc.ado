*! version 1.0.0 21oct2026
* Runs one odbc load into a frame, for sqldta and for its dialog helper,
* sqldta_dlg. This is the only place in the package where odbc load is
* called for a query, apart from the attempts of _sqldta_settings to connect.
* It connects through the global SQLDTA_CONNECTION if it is set, otherwise
* through the connection that _sqldta_settings chose for the server and
* keeps, from the templates of the settings file, otherwise through the one
* that _sqldta_settings chooses now. A template has %server% and %database%
* replaced; dsn means the ODBC data source named after the server. Prints
* the server, database, object and connection on failure. Returns r(rc), 0 on
* success, and leaves the decision to stop or continue to the caller.
program define _sqldta_odbc, rclass
	version 16
	args frame server database object sql

	local template `"$SQLDTA_CONNECTION"'
	if `"`template'"' == "" {
		mata: _sqldta_odbc_kept(st_local("server"))
		if `"`template'"' == "" {
			_sqldta_settings, server(`"`server'"') database(`"`database'"') connect quiet
			local template `"`r(connection)'"'
		}
	}
	if `"`template'"' == "" | ustrlower(`"`template'"') == "dsn" {
		local connect dsn(`"`server'"')
		local via the ODBC data source named `server'
	}
	else {
		local cs `"`template'"'
		local cs : subinstr local cs "%server%" `"`server'"', all
		local cs : subinstr local cs "%database%" `"`database'"', all
		local connect connectionstring(`"`cs'"')
		mata: st_local("via", _sqldta_odbc_via(st_local("template")))
	}

	capture noisily frame `frame': odbc load, exec(`"`macval(sql)'"') `connect' clear
	local rc = _rc
	if `rc' {
		display as error "sqldta: query failed, r(`rc')"
		display as error `"  server:     `server'"'
		display as error `"  database:   `database'"'
		display as error `"  object:     `object'"'
		display as error `"  connection: `via'"'
	}
	return scalar rc = `rc'
end


version 16
mata:

// Sets the local template to the connection that _sqldta_settings keeps for
// the server in the Mata external variable _sqldta_conn, or to "" if it keeps
// none
void _sqldta_odbc_kept(string scalar server)
{
	pointer() scalar p
	real scalar i

	st_local("template", "")
	p = findexternal("_sqldta_conn")
	if (p == NULL) return
	if (eltype(*p) != "string" | cols(*p) != 5) return
	for (i = 1; i <= rows(*p); i++) {
		if ((*p)[i, 1] == ustrlower(server)) {
			st_local("template", (*p)[i, 3])
			return
		}
	}
}

// The connection, for the message on failure: the driver that the template
// names, without its braces, which SMCL would read, or that it names none
string scalar _sqldta_odbc_via(string scalar t)
{
	if (ustrregexm(t, "(?i)driver\s*=\s*\{([^}]*)\}")) return("a connection template, driver " + ustrregexs(1))
	if (ustrregexm(t, "(?i)driver\s*=\s*([^;]*)")) return("a connection template, driver " + strtrim(ustrregexs(1)))
	return("a connection template that names no driver")
}

end
