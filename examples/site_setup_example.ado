*! version 0.1.0 21oct2026
* site_setup_example: an example of a site's start-up program for sqldta.
* Rename it, and the program, to the site's own name, put it in a folder on
* the ado-path, and run it when Stata starts, from profile.do or
* sysprofile.do (see "Executing commands every time Stata is started" in
* Stata's Getting Started manual). It adds the dialog of sqldta to the User
* menu and, if the site's network needs one, sets the proxy for net install
* and adoupdate.
*
* sqldta's own settings, such as the servers and the connection templates,
* are not set here but in the settings file sqldta_site.cfg, made from the
* example sqldta_site_example.cfg that net install installs, which sqldta
* reads itself each time it runs, so that macro drop _all in a user's do-file
* does not undo them.
program define site_setup_example
	version 16

	* The dialog on the User menu. Console Stata has no menus. Items added
	* here last until Stata exits. window menu clear is not used, because it
	* would remove every item that any program has added.
	if "`c(console)'" == "" {
		window menu append item "stUser" "Access server data" "db sqldta"
		window menu refresh
	}

	* The proxy, if the site's network needs one; remove the stars and set
	* the host and port. Each user enters the password once, in Stata for
	* Windows under Edit > Preferences > General Preferences > Internet, and
	* Stata keeps it between sessions.
	* quietly set httpproxy on
	* quietly set httpproxyhost "proxy.example.org"
	* quietly set httpproxyport 8080
	* quietly set httpproxyauth on
	* quietly set httpproxyuser "`c(username)'"
end
