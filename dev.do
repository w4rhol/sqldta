* dev.do: switches this Stata session to this clone's copy of sqldta, or back
*
* Run from the root of the clone:
*     cd "C:/path/to/sqldta"
*     do dev            this session uses the clone's src/
*     do dev release    this session uses the installed release again
*
* Stata runs the first sqldta.ado it finds along the ado-path, and the
* ado-path belongs to one session, so the clone's copy is used only in the
* session where do dev has run, until do dev release or the end of the
* session. Nothing is installed, and the installed release is not changed. A
* second Stata window, with do dev, can try a branch while the first keeps
* the release. The branch and commit shown are read from .git, because Stata
* cannot run git.

version 16
args mode

capture confirm file "src/sqldta.ado"
if _rc {
	display as error "run dev.do from the root of the sqldta clone"
	exit 601
}

local srcdir "`c(pwd)'/src"

if "`mode'" == "release" {
	capture adopath - "`srcdir'"
	discard
	capture mata: mata drop _sqldta_conn
	capture which sqldta
	if _rc {
		display as text "the clone's src/ is off the ado-path; no installed copy of sqldta was found"
	}
	else {
		display as text "the clone's src/ is off the ado-path; this session now uses the installed copy:"
		which sqldta
	}
	exit
}
else if "`mode'" != "" {
	display as error "do dev takes no argument, or release"
	exit 198
}

capture adopath - "`srcdir'"
adopath ++ "`srcdir'"
discard
capture mata: mata drop _sqldta_conn

* For trying the dialog: if neither a global nor the settings file
* sqldta_site.cfg sets SQLDTA_SERVERS or SQLDTA_CONNECTION, take them from the
* test settings in tests/test_config_local.do, which git ignores, with the
* second test server, TEST_SERVER2, after the first if it is set. They last
* until Stata is restarted.
capture confirm file "tests/test_config_local.do"
if _rc == 0 {
	run "tests/test_config_local.do"
	_sqldta_settings, quiet
	local servers `"`r(servers)'"'
	local nconn = r(nconnections)
	if `"`r(file)'"' != "" display as text `"settings file: `r(file)'"'
	if `"`servers'"' == "" & `"$TEST_SERVER"' != "" {
		global SQLDTA_SERVERS = strtrim(`"$TEST_SERVER $TEST_SERVER2"')
		display as text "SQLDTA_SERVERS set from tests/test_config_local.do: $SQLDTA_SERVERS"
	}
	else if `"`servers'"' != "" {
		* Servers set earlier in the session, by the site or by an earlier
		* run of dev.do, or in the settings file, are kept; macro drop
		* SQLDTA_SERVERS before do dev takes the test servers instead of a
		* global
		display as text `"SQLDTA_SERVERS was already set and is kept: `servers'"'
	}
	if `nconn' == 0 & `"$TEST_CONNECTION"' != "" {
		global SQLDTA_CONNECTION `"$TEST_CONNECTION"'
		display as text "SQLDTA_CONNECTION set from tests/test_config_local.do"
	}
}

* For trying the dialog: an item on the User menu that opens it. Because src/
* is first on the ado-path, it opens this clone's dialog, and running dev.do
* again after a Pull reloads it through discard above. Stata can neither list
* the items of a menu nor remove one of them, so the item is added once per
* session, and the global sqldta_dev_menu, which only dev.do uses, records
* that it has been. Console Stata has no menus. After do dev release, the
* item opens the installed dialog.
if "`c(console)'" == "" & `"$sqldta_dev_menu"' == "" {
	window menu append item "stUser" "Load a SQL Server table (sqldta, development copy)" "db sqldta"
	window menu refresh
	global sqldta_dev_menu 1
	display as text "User menu: Load a SQL Server table (sqldta, development copy)"
}

capture program drop dev_gitcommit
program define dev_gitcommit
	* Displays the branch and commit checked out in the current directory
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

display as text _n "This session now uses the development copy of sqldta in `srcdir':"
which sqldta
dev_gitcommit
display as text "Type do dev release to switch this session back to the installed release."
