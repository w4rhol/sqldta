{smcl}
{* *! version 1.3.1 29oct2026}{...}
{vieweralsosee "[D] odbc" "help odbc"}{...}
{vieweralsosee "[D] frames" "help frames"}{...}
{vieweralsosee "[D] label" "help label"}{...}
{vieweralsosee "[D] notes" "help notes"}{...}
{vieweralsosee "[D] format" "help format"}{...}
{viewerjumpto "Syntax" "sqldta##syntax"}{...}
{viewerjumpto "Description" "sqldta##description"}{...}
{viewerjumpto "Options" "sqldta##options"}{...}
{viewerjumpto "Remarks" "sqldta##remarks"}{...}
{viewerjumpto "Examples" "sqldta##examples"}{...}
{viewerjumpto "Stored results" "sqldta##results"}{...}
{viewerjumpto "Author" "sqldta##author"}{...}
{title:Title}

{phang}
{bf:sqldta} {hline 2} Load a SQL Server table into a frame, with labels and notes from a label table


{marker syntax}{...}
{title:Syntax}

{p 8 15 2}
{cmd:sqldta}
[{help if:{it:if}}]
{cmd:,}
{opt datab:ase(name)}
{opt datas:et([schema.]table)}
[{it:options}]

{pstd}
Show the settings in force and try the connection to a server

{p 8 15 2}
{cmd:sqldta settings}
[{cmd:,} {opt ser:ver(name)}]

{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{p2coldent:* {opt datab:ase(name)}}database that holds the table{p_end}
{p2coldent:* {opt datas:et([schema.]table)}}table or view to load{p_end}
{synopt:{opt ser:ver(name)}}server; default is the first word of {cmd:$SQLDTA_SERVERS}{p_end}
{synopt:{opt fra:me(name)}}frame to load into; default is the current frame{p_end}
{synopt:{opt clear}}replace the data in the target frame{p_end}
{synopt:{opt low:ercase}}rename every variable to lower case{p_end}
{synopt:{opt nodec:format}}do not set display formats on {cmd:decimal} and {cmd:numeric} columns{p_end}

{syntab:Labels and notes}
{synopt:{opt labels(types)}}label types to apply; default is {cmd:all}{p_end}
{synopt:{opt labelt:able([schema.]table)}}label table; default is {cmd:ref.DataProperties}{p_end}

{syntab:Columns and rows}
{synopt:{opt sqls:elect(columns)}}load only these columns; the wildcards {cmd:*} and {cmd:?} are allowed{p_end}
{synopt:{opt sqlw:here(condition)}}load only the rows that meet a T-SQL condition{p_end}
{synopt:{opt sqlr:and(#)}}load a random sample of {it:#} rows{p_end}
{synopt:{opt uni:code(columns)}}load these {cmd:char}, {cmd:varchar} and {cmd:text} columns as Unicode; {cmd:*} for all{p_end}
{synoptline}
{p2colreset}{...}
{p 4 6 2}
* {opt database()} and {opt dataset()} are required.{p_end}
{p 4 6 2}
{it:types} is {cmd:all}, {cmd:none}, or one or more of {cmd:values},
{cmd:variables}, {cmd:formats}, {cmd:varnotes}, {cmd:dtanotes} and
{cmd:datalabel}.{p_end}
{p 4 6 2}
The defaults of {opt server()}, of the schema in {opt dataset()} and of
{opt labeltable()} can be set for a site in a settings file or by global
macros; see {help sqldta##site:Site configuration}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:sqldta} loads a table or view from Microsoft SQL Server into a Stata frame
over ODBC. It can then apply value labels, variable labels, display formats,
variable notes, dataset notes and a data label that are stored as rows of a
label table in the same database; see
{help sqldta##labeltable:The label table}. The label table can also describe a
table whose columns are split across several tables, which {cmd:sqldta} then
joins on the server; see {help sqldta##links:Split tables}.

{pstd}
The {it:if} qualifier takes a Stata expression, which {cmd:sqldta} translates to
T-SQL, so that only the rows that meet it are read from the server; see
{help sqldta##if:The if qualifier}. {opt sqlwhere()} takes a T-SQL condition
instead, for anything the {it:if} qualifier does not support.

{pstd}
The dialog box {cmd:sqldta}, which {cmd:db sqldta} opens, lists the servers,
databases, schemas, tables and views, describes the table chosen, and builds
the command; see {help sqldta##dialog:The dialog}.

{pstd}
When it finishes, {cmd:sqldta} displays one line with the number of
observations and variables loaded, the source table as
{it:database}{cmd:.}{it:schema}{cmd:.}{it:table}, the number of linked tables,
the target frame and, unless {cmd:labels(none)} was given, the number of labels and
notes applied and of label rows skipped, or that the label table was not
found. It sets the data label of the frame to
{it:database}{cmd:.}{it:schema}{cmd:.}{it:table}, unless a DatasetLabel row
replaces it.


{marker options}{...}
{title:Options}

{dlgtab:Main}

{phang}
{opt database(name)} names the database that holds the table and the label
table. It is required.

{phang}
{opt dataset([schema.]table)} names the table or view to load, with its schema
or without it, but without the database, which {opt database()} gives. A table
named without a schema is in the schema given by {cmd:SQLDTA_DATASCHEMA}, or in
{cmd:dbo} if that is not set; see {help sqldta##site:Site configuration}. It is
required.
The schema and the table are separated at the dot, so neither name may contain
a dot.

{phang}
{opt server(name)} names the server to connect to. The name is put into the
connection template, or is used as the name of an ODBC data source; see
{help sqldta##connection:Connection}. The default is the first word of
{cmd:SQLDTA_SERVERS}; {opt server()} is required if that is not set; see
{help sqldta##site:Site configuration}.

{phang}
{opt frame(name)} names the frame to load the data into. The frame is created
if it does not exist. The default is the current frame. {cmd:sqldta} does not
change the current frame; type {cmd:frame change} {it:name} to work in the
frame that was loaded.

{phang}
{opt clear} allows {cmd:sqldta} to replace the data in the target frame.
Without {opt clear}, {cmd:sqldta} stops with error 4 if the target frame holds
any variables or observations. This is stricter than {cmd:use}, which refuses
only when the data in memory have changed since they were last saved. With
{opt clear}, {cmd:sqldta} clears the target frame just before the query that
loads the data, after the checks that can stop it; if that query fails, the
frame is left empty.

{phang}
{opt lowercase} renames every loaded variable to lower case, with
{cmd:rename *, lower}, before labels are applied. It overrides the case of the
names typed in {opt sqlselect()}. Label rows are matched to variables without
regard to case, so {opt lowercase} does not change which labels are applied.

{phang}
{opt nodecformat} leaves {cmd:decimal} and {cmd:numeric} columns with the
display format that {cmd:odbc load} gives them, {cmd:%10.0g}. Without it,
{cmd:sqldta} sets a format from the precision and scale of each such column;
see {help sqldta##types:Data types}. The formats of date, date-time and time
columns are not affected.

{dlgtab:Labels and notes}

{phang}
{opt labels(types)} gives the types of label row to apply from the label
table. {it:types} is {cmd:all}, which is the default, {cmd:none}, or one or
more of these words, in any order and in any case:

{p2colset 9 22 24 2}{...}
{p2col:{cmd:values}}value labels, from ValueLabel rows{p_end}
{p2col:{cmd:variables}}variable labels, from VariableLabel rows{p_end}
{p2col:{cmd:formats}}display formats, from VariableFormat rows{p_end}
{p2col:{cmd:varnotes}}notes on variables, from VariableNote rows{p_end}
{p2col:{cmd:dtanotes}}notes on the dataset, from DatasetNote rows{p_end}
{p2col:{cmd:datalabel}}the data label, from a DatasetLabel row{p_end}
{p2colreset}{...}

{pmore}
{cmd:all} and {cmd:none} cannot be combined with other words. With
{cmd:labels(none)}, no label rows are read, but Link rows are still followed;
see {help sqldta##links:Split tables}. See also
{help sqldta##labeltable:The label table} and
{help sqldta##apply:How label rows are applied}.

{phang}
{opt labeltable([schema.]table)} names the label table, which is in
{opt database()}. The default is {cmd:SQLDTA_LABELTABLE}, or
{cmd:ref.DataProperties} if that is not set; see
{help sqldta##site:Site configuration}. A label table named without a schema
is in the schema of the default label table, which is {cmd:ref} unless
{cmd:SQLDTA_LABELTABLE} gives another.

{dlgtab:Columns and rows}

{phang}
{opt sqlselect(columns)} loads only the columns named, in the order given. The
names are separated by spaces or by commas. They are matched to the columns of
the table, and of any linked tables, without regard to case, and may contain the
wildcards {cmd:*}, which matches any characters, and {cmd:?}, which matches one
character, as in Stata's own variable lists: {cmd:birth*} matches the names
that start with birth, {cmd:*loc*} those that contain loc, and {cmd:*loc}
those that end with it. A column is loaded under the name as typed, so that
{cmd:sqlselect(PatientID)} loads the column {cmd:patientid} as
{cmd:PatientID}; a column matched by a wildcard keeps its own name. A column
named twice is loaded once. A name that matches no column stops {cmd:sqldta}
with error 111. Column names only are accepted; expressions and aliases are
not. Without {opt sqlselect()}, every column whose name is a valid Stata name is
loaded; see {help sqldta##names:Column names}.

{phang}
{opt sqlwhere(condition)} loads only the rows that meet a T-SQL condition, as it
would be written after {cmd:WHERE}. The condition is passed to the server as
typed and uses the column names of the table on the server; with linked tables,
it refers to the columns of the joined table by name, without a table prefix.
If the {it:if} qualifier is also given, a row is loaded only if it meets both:
{cmd:sqldta} joins the two conditions with {cmd:AND}.

{phang}
{opt sqlrand(#)} loads a random sample of {it:#} rows, chosen with
{cmd:SELECT TOP (}{it:#}{cmd:) ... ORDER BY NEWID()}. Every row that meets the
{it:if} qualifier and {opt sqlwhere()} has the same chance of selection, and
each run gives a different sample; {cmd:set seed} has no effect. The server
reads and sorts every such row, so a sample from a large table takes time,
although only {it:#} rows are sent to Stata. If {it:#} is more than the number
of rows, every row is loaded.

{phang}
{opt unicode(columns)} loads the {cmd:char}, {cmd:varchar} and {cmd:text}
columns named as Unicode, so that characters outside ASCII, such as accented
letters, arrive as valid UTF-8. The names are given as in {opt sqlselect()}:
separated by spaces or commas, matched without regard to case to the columns
of the table and of any linked tables, with the wildcards {cmd:*} and {cmd:?};
{cmd:unicode(*)} names every column. A name that matches no column stops
{cmd:sqldta} with error 111. Columns of other types may be named and are loaded
as before; {cmd:nchar}, {cmd:nvarchar} and {cmd:ntext} columns are Unicode
already. Without {opt unicode()}, {cmd:char}, {cmd:varchar} and {cmd:text}
columns are loaded as they are, which is faster; see
{help sqldta##text:Text outside ASCII}. Label and note text from the label
table is always loaded as Unicode.


{marker remarks}{...}
{title:Remarks}

{pstd}
Remarks are presented under the following headings:

{phang2}{help sqldta##requirements:Requirements}{p_end}
{phang2}{help sqldta##connection:Connection}{p_end}
{phang2}{help sqldta##site:Site configuration}{p_end}
{phang2}{help sqldta##names:Column names}{p_end}
{phang2}{help sqldta##if:The if qualifier}{p_end}
{phang2}{help sqldta##labeltable:The label table}{p_end}
{phang2}{help sqldta##apply:How label rows are applied}{p_end}
{phang2}{help sqldta##links:Split tables}{p_end}
{phang2}{help sqldta##types:Data types}{p_end}
{phang2}{help sqldta##text:Text outside ASCII}{p_end}
{phang2}{help sqldta##dialog:The dialog}{p_end}
{phang2}{help sqldta##errors:Errors}{p_end}


{marker requirements}{...}
{title:Requirements}

{pstd}
{cmd:sqldta} needs Stata 16 or later. Stata 16 must be updated to 1 September
2020 or later (type {cmd:update all}), because earlier copies of Stata 16 had
faults with temporary frames, which {cmd:sqldta} uses. It has been tested on
Stata 18 and 19, and not yet on Stata 16 or 17.

{pstd}
It needs Microsoft SQL Server, an ODBC driver for SQL Server on the
machine that runs Stata, and permission to read the tables, which SQL Server's
own permissions decide. It supports databases with a case-insensitive
collation, which is the default when SQL Server is installed: it matches
column names without regard to case, so it does not support databases with a
case-sensitive collation, in which two columns or tables can have names that
differ only in case. The columns it loads must have names that are valid
Stata names; see {help sqldta##names:Column names}. The label table, if there
is one, is in the same database as the data.

{pstd}
The setup guide,
{browse "https://github.com/w4rhol/sqldta/blob/main/docs/setup.md":docs/setup.md}
in the package's repository, sets out how to install {cmd:sqldta} for a site,
the settings file, the connection to SQL Server and its drivers, the label
table, and the menu item for the dialog.


{marker connection}{...}
{title:Connection}

{pstd}
{cmd:sqldta} connects with {helpb odbc:odbc load}, through a connection
template: an ODBC connection string in which {cmd:sqldta} replaces each
{cmd:%server%} with the server name and each {cmd:%database%} with the database
name. For example:

{p 8 8 2}
{cmd:Driver={c -(}ODBC Driver 18 for SQL Server{c )-};Server=%server%;Trusted_Connection=yes;TrustServerCertificate=yes;}

{pstd}
The template is the global macro {cmd:SQLDTA_CONNECTION}, if it is set, or a
{cmd:SQLDTA_CONNECTION} line of the settings file; see
{help sqldta##site:Site configuration}. The settings file may hold several
such lines, for example one for each ODBC driver for SQL Server that a site's
machines may have, the preferred first. {cmd:sqldta} then tries them in order,
with the query {cmd:SELECT 1}, the first time it connects to a server in a
Stata session, and uses the first that connects for every later query to that
server in the session; it tries them again only if the lines change, after
{cmd:clear mata} or {cmd:clear all}, or if none connected. If the template
used is not the first, {cmd:sqldta} displays a note that names its driver,
because a later template is usually an older driver, kept as a fallback.
{cmd:sqldta settings} shows the result and the time of each attempt.

{pstd}
The word {cmd:dsn} in place of a template means the ODBC data source named
after the server, as {cmd:odbc load, dsn(}{it:server}{cmd:)} uses it. If no
template is set, or several are set and none connects, {cmd:sqldta} connects
through that data source, which works only where one has been set up on the
machine; in the second case a note says so. A single template is used as it
is, without an attempt first, so if it cannot connect, the load stops with the
driver's message. Setting the global {cmd:SQLDTA_CONNECTION} to
{cmd:dsn} uses the data source although the settings file lists templates.

{pstd}
An attempt through a driver that is not installed, or one that the server
refuses, ends quickly; one to a server that does not answer waits for the
driver's login time-out, 15 seconds by default for Microsoft's drivers, for
each template tried. If a query fails, the message names the connection used.

{pstd}
{cmd:sqldta} names every object in full, as
{cmd:[}{it:database}{cmd:].[}{it:schema}{cmd:].[}{it:table}{cmd:]}, so the
connection needs no database, and the {cmd:%database%} token is optional. A
template that includes {cmd:Database=%database%;} makes object names that are
not qualified, such as a subquery on another table in {opt sqlwhere()}, resolve
in {opt database()} rather than in the default database of the login.

{pstd}
ODBC Driver 18 for SQL Server encrypts connections by default, and rejects a
server certificate that the client does not trust unless
{cmd:TrustServerCertificate=yes} is set. If a connection through Driver 18 fails
with an error about the certificate, add {cmd:TrustServerCertificate=yes;} to
the template, as in the example above. The connection is still encrypted, but
the server's certificate is not checked.


{marker site}{...}
{title:Site configuration}

{pstd}
A site sets {cmd:sqldta}'s settings in a settings file, a text file named
{cmd:sqldta_site.cfg} in a folder on the ado-path, such as the PERSONAL or SITE
folder (see {helpb sysdir}). {cmd:sqldta} reads the first such file along the
ado-path, which includes the current directory, each time it runs, so the
settings stay in force after {cmd:macro drop _all}, which removes global
macros. Each line holds the name of a setting, in any case, then a space or a
tab, then its value; blank lines and lines that begin with {cmd:*} or {cmd://}
are passed over, and a line with another name is passed over with a note.
{cmd:SQLDTA_CONNECTION} may be given on several lines, the connection templates
to try in order; for the other settings a later line replaces an earlier one.
For example:

{p 8 8 2}{cmd:* sqldta_site.cfg}{p_end}
{p 8 8 2}{cmd:SQLDTA_SERVERS     MYSERVER MYSERVER2}{p_end}
{p 8 8 2}{cmd:SQLDTA_LABELTABLE  ref.DataProperties}{p_end}
{p 8 8 2}{cmd:SQLDTA_CONNECTION  Driver={c -(}ODBC Driver 18 for SQL Server{c )-};Server=%server%;Trusted_Connection=yes;TrustServerCertificate=yes;}{p_end}
{p 8 8 2}{cmd:SQLDTA_CONNECTION  Driver={c -(}ODBC Driver 17 for SQL Server{c )-};Server=%server%;Trusted_Connection=yes;}{p_end}
{p 8 8 2}{cmd:SQLDTA_CONNECTION  Driver={c -(}SQL Server{c )-};Server=%server%;Trusted_Connection=yes;}{p_end}

{pstd}
{cmd:net install} installs an example of the settings file, with every setting
and a comment on each, as {cmd:sqldta_site_example.cfg}; {cmd:sqldta} never
reads a file of that name. {cmd:findfile sqldta_site_example.cfg} shows where
it was installed. A site administrator copies it, as {cmd:sqldta_site.cfg}, to
the SITE folder or to a shared PERSONAL folder, and edits the copy. A single
user can instead copy or rename it to {cmd:sqldta_site.cfg} in the folder where
it was installed, for example:

{p 8 8 2}{cmd:. findfile sqldta_site_example.cfg}{p_end}
{p 8 8 2}{cmd:. local cfg = subinstr(r(fn), "sqldta_site_example.cfg", "sqldta_site.cfg", 1)}{p_end}
{p 8 8 2}{cmd:. copy "`r(fn)'" "`cfg'"}{p_end}
{p 8 8 2}{cmd:. doedit "`cfg'"}{p_end}

{pstd}
A copy in that folder, which is in PLUS unless the package was installed
elsewhere, is read only when no file {cmd:sqldta_site.cfg} is in SITE, the
current directory or PERSONAL, which come before PLUS on the ado-path.
{cmd:adoupdate} replaces the example with that of the new version, or puts it
back if it was renamed, and
{cmd:ado uninstall sqldta} removes it; neither changes {cmd:sqldta_site.cfg},
which is not one of the package's files. {cmd:sqldta settings} shows which
settings file is read.

{pstd}
Each setting may also be set as a global macro of the same name, for example
in {cmd:profile.do} or in a do-file, and a global that is set replaces the
line of the settings file; {cmd:macro drop _all} removes it again. An option,
where there is one, replaces both. {cmd:sqldta settings} shows the settings
file read, each setting and where it comes from, and, for the server in
{opt server()} or else the first of {cmd:SQLDTA_SERVERS}, the result and the
time of each connection template.

{p2colset 9 30 32 2}{...}
{p2col:{cmd:SQLDTA_SERVERS}}server names separated by spaces; the first is the
default of {opt server()}{p_end}
{p2col:{cmd:SQLDTA_DATABASES}}database names separated by spaces, which the
dialog lists instead of the databases on the server, for every server{p_end}
{p2col:{cmd:SQLDTA_DEFAULTDB}}the database that the dialog selects first: words
separated by spaces, each a database for every server, or
{it:server}{cmd:=}{it:database} for one server; see
{help sqldta##dialog:The dialog}{p_end}
{p2col:{cmd:SQLDTA_DLGREMEMBER}}set to anything other than {cmd:0} to make the
dialog reopen at the server used last, and at the database and schema chosen
last on each server, in the same Stata session{p_end}
{p2col:{cmd:SQLDTA_DATASCHEMA}}schema of a table named in {opt dataset()}
without one; {cmd:dbo} if not set{p_end}
{p2col:{cmd:SQLDTA_LABELTABLE}}default of {opt labeltable()}, as
{it:schema}{cmd:.}{it:table} or {it:table}, which is then in {cmd:ref};
{cmd:ref.DataProperties} if not set{p_end}
{p2col:{cmd:SQLDTA_LABELFALLBACK}}for backward compatibility, a label table of
the layout of sqldta's predecessor, as {it:schema}{cmd:.}{it:table} or
{it:table}, read in place of the label table when that is not found; not set
by default{p_end}
{p2col:{cmd:SQLDTA_CONNECTION}}connection template, or in the settings file
several, tried in order, or {cmd:dsn}; see
{help sqldta##connection:Connection}{p_end}
{p2col:{cmd:SQLDTA_DTTEXT}}set to anything other than {cmd:0} to load
date-time columns by the earlier method, as text converted with {cmd:clock()};
see {help sqldta##types:Data types}{p_end}
{p2colreset}{...}


{marker names}{...}
{title:Column names}

{pstd}
The columns of a table that {cmd:sqldta} reads must have names that are valid
Stata names: letters, digits and underscores, not starting with a digit, at
most 32 characters, with no spaces, and not a reserved word such as {cmd:in} or
{cmd:long}. {cmd:sqldta} leaves out a column whose name is not valid, lists it
in a note, and returns it in {cmd:r(dropped)}. If no column of the table has a
valid name, {cmd:sqldta} stops with error 111; a view on the server that
renames the columns, with {cmd:AS}, can then be loaded. Columns are matched to names in
{opt sqlselect()} and in the {it:if} qualifier without regard to case.

{pstd}
Each column is placed in brackets in the SQL, so a column named after a T-SQL
reserved word, such as {cmd:Order}, can be loaded and used in the {it:if}
qualifier. In {opt sqlwhere()}, which is passed as typed, such a name must be
written in brackets, as in {cmd:sqlwhere([Order] > 3)}.


{marker if}{...}
{title:The if qualifier}

{pstd}
The {it:if} qualifier selects rows on the server, before they are loaded. It
takes a Stata expression, written with the part of Stata's syntax listed below,
and {cmd:sqldta} translates it to T-SQL. The rows loaded are the rows that
loading the whole table and then typing {cmd:keep if} {it:exp} would leave.
So the translation follows Stata's rules:

{p 8 11 2}o{space 2}A missing value is greater than every number, so
{cmd:age > 65} also selects the rows where {cmd:age} is missing, as
{cmd:keep if age > 65} would keep them. Type
{cmd:age > 65 & !missing(age)} to leave them out.{p_end}
{p 8 11 2}o{space 2}{cmd:!} or {cmd:~} before a condition is true wherever the
condition is false, including where the condition involves a missing value.{p_end}
{p 8 11 2}o{space 2}A missing string is treated as {cmd:""}, which is how it is
loaded.{p_end}
{p 8 11 2}o{space 2}Strings are compared with regard to case and by character
code, as in Stata, so that {cmd:"B" < "a"}.{p_end}
{p 8 11 2}o{space 2}A number compared with a date column is a Stata date, the
number of days since 01jan1960; {cmd:td(01jan2020)} gives such a number. A
number compared with a date-time column is a Stata date-time, the number of
milliseconds since 01jan1960 00:00:00.000, which {cmd:tc(01jan2020 13:45:30)}
gives. A number compared with a time column is a number of milliseconds since
midnight, which {cmd:tc()} with a time of day alone, such as
{cmd:tc(13:45:30)}, gives.{p_end}
{p 8 11 2}o{space 2}Date-time and time columns are compared as the values that
{cmd:sqldta} loads: whole milliseconds, without the digits below the
millisecond, and missing before 01jan0100; see
{help sqldta##types:Data types}. So {cmd:x == tc(01jan2020 13:45:30.123)}
selects a {cmd:datetime2} value of 13:45:30.1234567, which loads as
13:45:30.123.{p_end}
{p 8 11 2}o{space 2}A number used as a condition on its own is true unless it is
0, so {cmd:if flag} selects the rows where {cmd:flag} is not 0, including those
where it is missing.{p_end}
{p 8 11 2}o{space 2}Text is compared as it is stored on the server. A
{cmd:char}, {cmd:varchar} or {cmd:text} column that is not named in
{opt unicode()} is loaded as it is, and its characters outside ASCII arrive as
bytes that are not valid UTF-8 (see {help sqldta##text:Text outside ASCII}). So
{cmd:if name == "Zoë"} selects the rows whose stored name is Zoë, but
{cmd:keep if name == "Zoë"} on the loaded column would not keep them. With the
column in {opt unicode()}, the two agree. Comparisons of ASCII text are not
affected.{p_end}

{pstd}
The {it:if} qualifier supports:

{p 8 11 2}o{space 2}column names, written in full, in any case. Columns of
linked tables, and columns that {opt sqlselect()} does not load, can be
used.{p_end}
{p 8 11 2}o{space 2}numbers, strings in double quotes, and the missing value
{cmd:.}; {cmd:.a} to {cmd:.z} are treated as {cmd:.}, because SQL has one
missing value.{p_end}
{p 8 11 2}o{space 2}the operators {cmd:==}, {cmd:!=}, {cmd:~=}, {cmd:<},
{cmd:<=}, {cmd:>}, {cmd:>=}, {cmd:&}, {cmd:|}, {cmd:!} and {cmd:~},
parentheses, and a minus sign before a number or a numeric column.{p_end}
{p 8 11 2}o{space 2}{cmd:missing()} and {cmd:inlist()}.{p_end}
{p 8 11 2}o{space 2}{cmd:inrange()}, with bounds that are numbers, {cmd:td()}
dates, {cmd:tc()} date-times or strings other than {cmd:""}. As in Stata, it is
not true for a missing value.{p_end}
{p 8 11 2}o{space 2}{cmd:substr()} and {cmd:usubstr()}, with a start position
that is a whole number of 1 or more, and a length that is a whole number or
{cmd:.}.{p_end}
{p 8 11 2}o{space 2}{cmd:strlower()}, {cmd:strupper()}, {cmd:strtrim()},
{cmd:strltrim()} and {cmd:strrtrim()}, their {cmd:ustr} forms, and
{cmd:lower()}, {cmd:upper()}, {cmd:trim()}, {cmd:ltrim()} and
{cmd:rtrim()}.{p_end}
{p 8 11 2}o{space 2}{cmd:year()}, {cmd:month()} and {cmd:day()} of a date
column, and {cmd:td()}.{p_end}
{p 8 11 2}o{space 2}{cmd:tc()}, for a date and time such as
{cmd:tc(01jan2020 13:45:30.123)}, in which the seconds or the minutes and
seconds may be left out, and {cmd:dofc()} of a date-time column, which gives
its date, as in {cmd:dofc(admitted) >= td(01jul2024)} or
{cmd:year(dofc(admitted)) == 2024}.{p_end}

{pstd}
Anything else, including arithmetic, stops {cmd:sqldta} with error 198 and a
message that points to {opt sqlwhere()}. Columns of character types
({cmd:char}, {cmd:varchar}, {cmd:nchar}, {cmd:nvarchar}), numeric types
({cmd:tinyint}, {cmd:smallint}, {cmd:int}, {cmd:bigint}, {cmd:bit},
{cmd:decimal}, {cmd:numeric}, {cmd:float}, {cmd:real}, {cmd:money},
{cmd:smallmoney}), the type {cmd:date}, the date-time types ({cmd:datetime},
{cmd:datetime2}, {cmd:smalldatetime}, {cmd:datetimeoffset}) and the type
{cmd:time} can be used. Columns of other types, such as {cmd:text},
{cmd:ntext}, {cmd:uniqueidentifier} and the binary types, cannot be used in
the {it:if} qualifier, but can be in {opt sqlwhere()}.

{pstd}
In Stata, {cmd:td()} gives a number of days and a date-time holds milliseconds,
so {cmd:x > td(01jan2020)} for a date-time column {cmd:x} would compare days
with milliseconds and select nearly every row. {cmd:sqldta} therefore stops with
error 198 when a date is compared with a date-time, when {cmd:year()},
{cmd:month()} or {cmd:day()} is applied to a date-time column, and when a time
column is compared with a date-time column, and suggests {cmd:tc()} or
{cmd:dofc()} instead. {cmd:tC()} is not supported, because {cmd:sqldta} loads
date-times as {cmd:%tc}.

{pstd}
The expression ends at the first comma outside parentheses and double quotes,
which starts the options, as for any Stata command.

{pstd}
Limitations:

{p 8 11 2}o{space 2}SQL Server ignores trailing spaces when it compares
strings, so {cmd:name == "abc"} also selects a {cmd:varchar} or
{cmd:nvarchar} value stored as {cmd:"abc  "}, which is loaded with its trailing
spaces. {cmd:char} and {cmd:nchar} values are loaded without them, so for
these the comparison is exact.{p_end}
{p 8 11 2}o{space 2}{cmd:substr()} counts characters, where Stata's
{cmd:substr()} counts bytes. The two differ only for text with characters
outside ASCII.{p_end}
{p 8 11 2}o{space 2}String comparisons use the binary collation
{cmd:Latin1_General_BIN2}, so that they are case-sensitive. SQL Server cannot
use an index for a comparison through that collation, so on a large table a
condition on a string column reads every row. A condition in {opt sqlwhere()}
can use an index.{p_end}
{p 8 11 2}o{space 2}A condition that compares a date-time or time column with a
literal or a number can use an index on the column, except for a
{cmd:datetimeoffset} column, which is compared as its clock time. A condition
that compares two date-time or time columns, or that uses {cmd:dofc()} of a
{cmd:datetime2} or {cmd:datetimeoffset} column, cannot.{p_end}


{marker labeltable}{...}
{title:The label table}

{pstd}
The label table, {cmd:ref.DataProperties} by default, is in the same database
as the data. It holds one row for each label item, in these columns:

{p2colset 9 24 26 2}{...}
{p2col:{bf:Column}}{bf:Meaning}{p_end}
{p2line}
{p2col:{cmd:TableSchema}}schema of the table or view the row applies to{p_end}
{p2col:{cmd:TableName}}name of that table or view{p_end}
{p2col:{cmd:ColumnName}}column name; empty for DatasetNote and DatasetLabel
rows; for Link rows, the key column{p_end}
{p2col:{cmd:PropertyType}}{cmd:ValueLabel} (value label), {cmd:VariableLabel}
(variable label), {cmd:VariableFormat} (display format), {cmd:VariableNote}
(variable note), {cmd:DatasetNote} (dataset note), {cmd:DatasetLabel} (data
label), {cmd:DatasetDescription} (a paragraph of a description of the table)
or {cmd:Link} (linked table of a split table), in any case{p_end}
{p2col:{cmd:PropertyCode}}for ValueLabel rows, the integer code; for
VariableNote and DatasetNote rows, optionally, the order in which the notes are
applied; for DatasetDescription rows, the number of the paragraph{p_end}
{p2col:{cmd:PropertyText}}the label or note text; for VariableFormat rows, the
format, such as {cmd:%9.2fc}; for DatasetLabel rows, the data label; for Link rows, the
linked table as {it:table} (in the schema of the main table) or
{it:schema}{cmd:.}{it:table}{p_end}
{p2line}
{p2colreset}{...}

{pstd}
The rows of a table are those whose TableSchema and TableName are its schema
and name, compared under the database's collation, so tables of the same name
in different schemas of one database have rows of their own. Rows of the types
{cmd:Format} and {cmd:DataLabel}, the names that {cmd:sqldta} 1.0.0 used, are
read as {cmd:VariableFormat} and {cmd:DatasetLabel} rows. All the columns
are of character types, such as {cmd:nvarchar}, so that other software can read
the same table; {cmd:sqldta} checks that the PropertyCode of a ValueLabel row is
a whole number before it applies the row. The table may have other columns,
which {cmd:sqldta} does not read. Any table or view of this layout can be used
as a label table. Its queries select rows by TableSchema, TableName and
PropertyType, so on a large label table an index on those three columns makes
them faster; the setup guide (see {help sqldta##requirements:Requirements})
gives an example and the types the columns need for it. Some example rows, all
with TableSchema {cmd:dbo}:

{col 9}{bf:TableName}{col 19}{bf:ColumnName}{col 30}{bf:PropertyType}{col 45}{bf:PropertyCode}{col 59}{bf:PropertyText}
{col 9}MyTable{col 19}sex{col 30}ValueLabel{col 45}1{col 59}Male
{col 9}MyTable{col 19}sex{col 30}ValueLabel{col 45}2{col 59}Female
{col 9}MyTable{col 19}sex{col 30}VariableLabel{col 59}Sex of the patient
{col 9}MyTable{col 19}amount{col 30}VariableFormat{col 59}%9.2fc
{col 9}MyTable{col 19}age{col 30}VariableNote{col 45}1{col 59}Age at admission
{col 9}MyTable{col 30}DatasetNote{col 59}Extracted each month
{col 9}MyTable{col 30}DatasetLabel{col 59}Hospital admissions
{col 9}MyTable{col 19}id{col 30}Link{col 59}MyTablePart2

{pstd}
A label table of another layout, such as one that other software reads and
that cannot be changed, can be given this layout by a view over it; the setup
guide shows an example.

{pstd}
If the label table does not exist, or cannot be read, {cmd:sqldta} loads the
data without labels, the summary line says that the label table was not found,
and {cmd:r(labelstatus)} is {cmd:notfound}. If the label table lacks any of the
six columns above, {cmd:sqldta} displays a note that names them, loads the data
without labels and without following Link rows, and {cmd:r(labelstatus)} is
{cmd:failed}. If the query that reads the label rows fails, {cmd:sqldta}
displays a note and keeps the data, and {cmd:r(labelstatus)} is {cmd:failed}.


{marker apply}{...}
{title:How label rows are applied}

{pstd}
{cmd:sqldta} reads the rows of the label types given in {opt labels()}, all of
them by default, for {opt dataset()} and for any linked tables, in one query,
after the data are loaded. Rows whose PropertyText is empty are not read, and
rows that are the same in ColumnName, PropertyType, PropertyCode and
PropertyText are read once. ColumnName is matched to the loaded variables
without regard to case. Label and note text is applied
exactly as stored, including quotes, backquotes and {cmd:$}.

{p 8 11 2}o{space 2}{bf:ValueLabel} ({cmd:values}): rows for a variable that is numeric once loaded
are applied; rows for a variable that is a string in Stata are passed over,
because Stata cannot attach value labels to it, and do not count as skipped.
The PropertyCode must be a whole number, which may be negative, and
PropertyText is the label of that code. The rows of one variable form a value-label set named
after the variable, which is attached to it with {cmd:label values}. A set that
cannot be attached is dropped, and its rows count as skipped.{p_end}
{p 8 11 2}o{space 2}{bf:VariableLabel} ({cmd:variables}): PropertyText is the variable label. Stata allows at
most 80 characters.{p_end}
{p 8 11 2}o{space 2}{bf:VariableFormat} ({cmd:formats}): PropertyText is a display format, such as
{cmd:%9.2fc} or {cmd:%tdDD/NN/CCYY}. It must be one valid format that suits the
type of the variable; otherwise the row is skipped.{p_end}
{p 8 11 2}o{space 2}{bf:VariableNote} ({cmd:varnotes}) and {bf:DatasetNote} ({cmd:dtanotes}): PropertyText is a note on the
variable or on the dataset, as listed by {helpb notes}. Notes that have a
PropertyCode are applied first, in PropertyCode order: in numeric order if
every PropertyCode among the notes of that variable, or of the dataset, is a
number, and otherwise in text order. Notes without a PropertyCode follow, in
the order in which
SQL Server returns them, which is not guaranteed. Unlike the {cmd:notes}
command, {cmd:sqldta} does not replace {cmd:TS} with a time stamp.{p_end}
{p 8 11 2}o{space 2}{bf:DatasetLabel} ({cmd:datalabel}): PropertyText is the data label, in place of
{it:database}{cmd:.}{it:schema}{cmd:.}{it:table}. The first 80 characters are
used.{p_end}
{p 8 11 2}o{space 2}{bf:DatasetDescription}: not applied to the data. The text of the row of the
table loaded whose PropertyCode is 1 is returned in {cmd:r(description)}, and
the dialog shows it.{p_end}

{pstd}
A row is skipped, and counted in the summary line and in {cmd:r(n_skipped)},
when its ColumnName names no column of the table or of its linked tables, when
a ValueLabel row of a numeric variable has a PropertyCode that is not a whole
number, or
when Stata refuses to apply it. Skipped rows show errors in the label table. A
row for a column that exists but was not loaded, because {opt sqlselect()} left
it out, and a ValueLabel row for a variable that is a string in Stata, are passed over
and not counted.


{marker links}{...}
{title:Split tables}

{pstd}
A table whose columns are split across several tables, which share a key
column, can be loaded as one table. The label table holds one Link row for each
linked table: TableSchema and TableName are those of the main table,
ColumnName is the key column, and PropertyText is the linked table, as
{it:table}, which is then looked for in the schema of the main table, or as
{it:schema}{cmd:.}{it:table}. Whenever the label table has Link rows for
{opt dataset()}, {cmd:sqldta} joins the linked tables to the main table on the
server, in the order of their PropertyText, even with
{cmd:labels(none)}. The join is a left join, so every row of the main table
is loaded, and the columns of a linked table are missing where it has no row
with that key.

{p 8 11 2}o{space 2}The key has the same name in the main table and in every
linked table, and must be a valid Stata name. It is loaded once, from the main
table.{p_end}
{p 8 11 2}o{space 2}Only 1:1 links are supported. Before it loads the data,
{cmd:sqldta} checks that the key does not repeat in any linked table, and stops
with error 459 if it does, because a repeated key would multiply rows. Missing
keys are ignored, because they match no row.{p_end}
{p 8 11 2}o{space 2}A column name that appears in more than one table is taken
from the first table that has it: the main table, then the linked tables in
order. A note lists the columns left out, and {cmd:r(dropped)} holds them.{p_end}
{p 8 11 2}o{space 2}{opt sqlselect()}, the {it:if} qualifier, {opt sqlwhere()}
and {opt sqlrand()} apply to the joined table as if it were one wide table, and
the linked tables are not read in full.{p_end}
{p 8 11 2}o{space 2}Label rows filed under the schema and name of a linked
table are applied as well as those of {opt dataset()}.{p_end}


{marker types}{...}
{title:Data types}

{pstd}
{cmd:odbc load} mishandles several SQL Server types, and some differently with
different drivers: it drops the fractions of a second of date-times, skips
columns of some types, and returns text outside ASCII in {cmd:char},
{cmd:varchar} and {cmd:text} columns as bytes that are not valid UTF-8.
{cmd:sqldta} therefore sends columns of most of these types as expressions that
{cmd:odbc load} reads correctly, and converts them after the load, so that the
result does not depend on the driver. The query then names every column instead
of using {cmd:*}; {cmd:r(sql)} shows it. The {it:if} qualifier and
{opt sqlwhere()} still refer to the columns as they are on the server. Text in
{cmd:char}, {cmd:varchar} and {cmd:text} columns is the exception: it is sent as
it is unless {opt unicode()} names the column, because converting it costs
time; see {help sqldta##text:Text outside ASCII}.

{p2colset 9 32 34 2}{...}
{p2col:{bf:SQL type}}{bf:Loaded as}{p_end}
{p2line}
{p2col:{cmd:datetime}, {cmd:datetime2}, {cmd:smalldatetime}}a date-time with
milliseconds, format {cmd:%tc}{p_end}
{p2col:{cmd:datetimeoffset}}the clock time as stored, without its offset from
UTC, format {cmd:%tc}{p_end}
{p2col:{cmd:date}}a date, format {cmd:%td}{p_end}
{p2col:{cmd:time}}milliseconds since midnight, format {cmd:%tcHH:MM:SS.sss}{p_end}
{p2col:{cmd:char}}a string without its trailing padding; characters outside
ASCII arrive as bytes, or in UTF-8 with {opt unicode()}{p_end}
{p2col:{cmd:nchar}}a string in UTF-8 without its trailing padding{p_end}
{p2col:{cmd:varchar}, {cmd:text}}a string; characters outside ASCII arrive as
bytes, or in UTF-8 with {opt unicode()}; {cmd:varchar(max)}, {cmd:text} and
{cmd:varchar} longer than 4,000 characters may arrive as {cmd:strL}, depending
on the driver and the length of the values{p_end}
{p2col:{cmd:nvarchar}, {cmd:ntext}}a string in UTF-8, as {cmd:odbc load}
returns it{p_end}
{p2col:{cmd:uniqueidentifier}}a string of 36 characters{p_end}
{p2col:{cmd:binary}, {cmd:varbinary}, {cmd:image}, {cmd:rowversion}}hexadecimal
text, such as {cmd:0x01020304}{p_end}
{p2col:{cmd:xml}, {cmd:sql_variant}}text{p_end}
{p2col:{cmd:hierarchyid}}text, such as {cmd:/1/2/}{p_end}
{p2col:{cmd:geography}, {cmd:geometry}}well-known text, such as
{cmd:POINT (1 2)}{p_end}
{p2col:{cmd:decimal}, {cmd:numeric}}a double, with a format from the precision
and scale; see below{p_end}
{p2col:{cmd:bigint}}a number if every value loaded can be held exactly,
otherwise a string; see below{p_end}
{p2col:{cmd:bit}}{cmd:odbc load}'s own result, a numeric variable holding 0
and 1, with NULL as missing; Stata has no Boolean type{p_end}
{p2col:{cmd:int}}{cmd:odbc load}'s own result, a {cmd:long}, or a {cmd:double}
if a value is above 2,147,483,620; see below{p_end}
{p2col:other types}{cmd:odbc load}'s own result{p_end}
{p2line}
{p2colreset}{...}

{pstd}
{cmd:odbc load} reads an {cmd:int} column as a {cmd:long}, whose largest value
in Stata is 2,147,483,620, below the largest {cmd:int} of SQL Server,
2,147,483,647. If a value is above it, such as 2,147,483,647 used to mark a
missing or unknown value, {cmd:odbc load} stores the variable as a
{cmd:double} instead and displays a message such as
{cmd:variable x was long now double}. The values are exact.

{pstd}
Date-times keep their milliseconds. Digits below the millisecond, which
{cmd:datetime2}, {cmd:datetimeoffset} and {cmd:time} can hold, are dropped, not
rounded, so 23:59:59.9999999 loads as 23:59:59.999 on the same day. A
{cmd:datetime} column holds steps of 1/300 of a second, which load as SQL
Server shows them: .000, .003 and .007 in each 10 milliseconds. Stata's
earliest date is 01jan0100, so a {cmd:datetime2} or {cmd:datetimeoffset} value
before it loads as missing. The format {cmd:%tc} does not show milliseconds; a
VariableFormat row such as {cmd:%tcCCYY-NN-DD_HH:MM:SS.sss} shows them.

{pstd}
A {cmd:datetimeoffset} value loads as the clock time it was stored with, and
its offset is not kept: 13:45 +10:00 loads as 13:45, and so does 13:45 +00:00.
Values stored with different offsets may therefore not be in the order of the
instants they record. Stata has no time zones.

{pstd}
{cmd:sqldta} sends each date-time value as a number of milliseconds since
01jan1960 00:00:00.000, which is the Stata date-time value itself, computed on
the server so that the rules above hold: a {cmd:datetime} value from its stored
steps of 1/300 of a second, each rounded to the millisecond as SQL Server shows
it, and other values by counting the whole milliseconds since midnight. Every
such number is a whole number below 2^53, which a double holds exactly. If a
problem appears with this method, setting {cmd:SQLDTA_DTTEXT} to {cmd:1}, in the
settings file or as a global macro (see
{help sqldta##site:Site configuration}), makes {cmd:sqldta} send date-times as
that text instead and convert it with
{cmd:clock()}, a slower method that gives the same values, and
{cmd:r(datetimes)} shows which method was used. Either way the {it:if}
qualifier selects the same rows.

{pstd}
A date-time column is listed in {cmd:r(converted)}. So is a {cmd:date} column
that the driver returns as a string, as the legacy driver named "SQL Server"
does; current drivers, such as ODBC Driver 18 for SQL Server, return dates as
Stata dates.

{pstd}
A {cmd:decimal} or {cmd:numeric} column of precision {it:p} of 15 or less and
scale {it:s} gets the format {cmd:%}{it:p+2}{cmd:.}{it:s}{cmd:f}, so
{cmd:decimal(9,2)} gets {cmd:%11.2f}. A double holds about 15 significant
digits, so a wider column keeps {cmd:%10.0g}, and its values may not be exact.
{opt nodecformat} turns these formats off. A VariableFormat row in the label
table replaces any format that {cmd:sqldta} sets.

{pstd}
A {cmd:decimal} or {cmd:numeric} column of precision over 15 and a scale above
0 is sent as text and converted to a double by {cmd:sqldta}, which gives the
nearest double to each value. ODBC Driver 18 gives the same, but the legacy
driver named "SQL Server" rounds such values to about 15 significant digits,
so that 99999999999999.99 would load as 100000000000000.

{pstd}
{cmd:odbc load} returns {cmd:bigint} columns as strings, and {cmd:sqldta}
sends {cmd:decimal} and {cmd:numeric} columns of scale 0 and precision over 15,
such as {cmd:numeric(18,0)}, as text. {cmd:sqldta} converts such a column to a
number, stored in the smallest type that holds its values, if every value
loaded can be held exactly; a double holds every whole number up to 2^53, which
is 9,007,199,254,740,992. Otherwise the column stays a string, so that large
identifiers are not altered, and a note says so. A converted column is listed
in {cmd:r(converted)}. The {it:if} qualifier compares such a column as a number
on the server in either case.


{marker text}{...}
{title:Text outside ASCII}

{pstd}
SQL Server stores {cmd:char}, {cmd:varchar} and {cmd:text} columns in the code
page of their collation, 1252 for the Latin1_General collations, in which
characters outside ASCII, such as accented letters, take one byte each.
{cmd:odbc load} passes those bytes to Stata as they are, so such characters are
not valid UTF-8 in Stata and show as {cmd:?} or as a replacement character.
ASCII text is not affected, and neither are {cmd:nchar}, {cmd:nvarchar} and
{cmd:ntext} columns, which are Unicode.

{pstd}
{cmd:sqldta} loads {cmd:char}, {cmd:varchar} and {cmd:text} columns as they are
by default, as earlier programs did, because converting them to Unicode on the
server makes it send two bytes for each character instead of one, and makes
loads of large tables with many text columns take up to twice as long.
{opt unicode()} names the columns to convert, such as columns of names or
addresses that may hold accented letters, or {cmd:unicode(*)} converts them
all.

{pstd}
Text already loaded without {opt unicode()} can be converted in Stata, for a
column of code page 1252, with

{phang2}{cmd:. replace} {it:var} {cmd:= ustrfrom(}{it:var}{cmd:, "windows-1252", 1) if ustrinvalidcnt(}{it:var}{cmd:) > 0}{p_end}

{pstd}
which gives the same text as {opt unicode()}. For a collation with another code
page, use its name in place of {cmd:windows-1252}. Finding the values to
convert reads every value of the column, so for a large table with many such
columns {opt unicode()} on the columns that need it is quicker.


{marker dialog}{...}
{title:The dialog}

{pstd}
{cmd:db sqldta} opens a dialog box with two tabs, which builds a {cmd:sqldta}
command and runs it. A site can add it to Stata's User menu, for example in
{cmd:profile.do}:

{p 8 8 2}
{cmd:window menu append item "stUser" "Load a SQL Server table (sqldta)" "db sqldta"}{break}
{cmd:window menu refresh}

{pstd}
On the {bf:Import} tab, the lists are filled from the site configuration and
from the server, and none is fixed in advance:

{p 8 11 2}o{space 2}{bf:Server} lists {cmd:SQLDTA_SERVERS}, and the first is
selected, or, if {cmd:SQLDTA_DLGREMEMBER} is set, the server used last in the
Stata session.{p_end}
{p 8 11 2}o{space 2}{bf:Database} lists {cmd:SQLDTA_DATABASES} if it is set;
otherwise the databases on the server that are online and that the login can
open, other than master, tempdb, model and msdb, in alphabetical order. A
login that cannot open a database does not see it in the list. The database
selected is the server's default from {cmd:SQLDTA_DEFAULTDB}, or the first
listed if it has none or its default is not listed. When the dialog is opened
again, it selects the server's default database and the default schema
again, not those chosen before, unless {cmd:SQLDTA_DLGREMEMBER} is set, when it
selects the database and schema chosen last on that server, if they are still
listed.{p_end}
{p 8 11 2}o{space 2}{bf:Schema} lists the schemas of the database that hold a
table or view that the login can see; {cmd:SQLDTA_DATASCHEMA}, or else
{cmd:dbo}, is selected if it is listed.{p_end}
{p 8 11 2}o{space 2}{bf:Tables and views} lists those of the schema, after the
entry {bf:(none chosen)}, which is selected when the dialog opens, so that
nothing is read until a table is chosen. {bf:OK}, {bf:Submit} and {bf:Copy}
ask for a table while it is selected.{p_end}

{pstd}
Each word of {cmd:SQLDTA_DEFAULTDB} is a database for every server, or
{it:server}{cmd:=}{it:database} for one server, whose name is matched without
regard to case; a name that contains a space is written in double quotes. A
word for the server comes before a word for every server. For example, with
two servers, in the settings file:

{p 8 8 2}
{cmd:SQLDTA_SERVERS   MYSERVER MYSERVER2}{break}
{cmd:SQLDTA_DEFAULTDB MyDatabase MYSERVER2=MyArchive}

{pstd}
selects MyDatabase on MYSERVER, and on any other server that has it, and
MyArchive on MYSERVER2. When the server is changed, its default is selected if
it is listed; otherwise the database of the same name as the one chosen
before, if it is listed; otherwise the first. {cmd:SQLDTA_DEFAULTDB} is read
by the dialog only: {opt database()} is still required in a command.

{pstd}
A server, database or schema that is not listed can be typed; {bf:Refresh lists}
then lists what depends on it. Choosing a table shows its description: the
approximate number of rows (not shown for a view), the number of columns that
can be loaded, its linked tables, its data label, the paragraph of its
description whose PropertyCode is 1, and any columns that would be left out. The
description is read from the label table given on the {bf:Import} tab, or
the default label table; after changing it, click {bf:Refresh lists}. Names
that contain a double quote, a backquote, {cmd:$}, a backslash or a dot are
not listed; such tables can still be loaded by typing the command.

{pstd}
The {bf:Import} tab also has, in the group {bf:Frame}, the frame to load into,
{opt clear} and a box that changes to that frame after the load; in the group
{bf:Variables}, {opt lowercase} and {opt nodecformat}; and, in the group of
labels and notes, a box for each label type of {opt labels()}, all ticked by
default, and {opt labeltable()}.

{pstd}
The {bf:Advanced} tab has, in the group {bf:Columns to load}, {opt sqlselect()}
and {opt unicode()}, the list of the columns of the table and a box that shows
the column chosen in the list; and, in the group {bf:Rows to load}, the {it:if}
qualifier, {opt sqlwhere()} and {opt sqlrand()}. If both conditions are given,
a row is loaded only if it meets both, and a random sample is drawn from those
rows. The box of the column chosen shows its variable label, whether it is a
{cmd:char}, {cmd:varchar} or {cmd:text} column, which {opt unicode()} affects, its value
labels and its notes, as a load would apply them. These are read once, when
the table is chosen, so that clicking a column reads nothing from the server.

{pstd}
{bf:Find}, above the list, shows only the columns whose name, variable label or
value labels contain every word typed in it, in any case: {cmd:smok} shows
{cmd:smoker}, a column labelled "Smoking status", and a column with a value
labelled "Never smoked". The line below the list says how many columns are
shown. Above {opt sqlselect()} and above {opt unicode()}, {bf:Add selected}
adds the column selected in the list to that field, as a double-click does
for {opt sqlselect()}, and {bf:Add all shown} adds every column that the list
shows. Find starts empty each time the dialog opens.

{pstd}
The command leaves out {opt server()} when the server is the first of
{cmd:SQLDTA_SERVERS}, {opt labeltable()} when it is {cmd:SQLDTA_LABELTABLE},
and {opt labels()} when every label box is ticked, so that a command copied
into a do-file uses each site's defaults. {bf:OK} and {bf:Submit} run the
command, followed by {cmd:frame change} if that box is ticked and a frame is
named; {bf:Copy} copies the {cmd:sqldta} command alone.


{marker errors}{...}
{title:Errors}

{pstd}
{cmd:sqldta} stops with these errors before it creates a frame, so an error
leaves no new frame behind.

{p2colset 9 19 21 2}{...}
{p2col:{cmd:r(4)}}the target frame holds data and {opt clear} was not
given{p_end}
{p2col:{cmd:r(111)}}a name in {opt sqlselect()} or {opt unicode()} matches no
column, or no column of the table has a valid Stata name{p_end}
{p2col:{cmd:r(198)}}{opt server()} is not given and {cmd:SQLDTA_SERVERS} is not
set, as a global or in the settings file; {opt labels()} holds a word that is not a label type, or {cmd:all} or
{cmd:none} with other words; {opt dataset()}, {opt labeltable()} or
{cmd:SQLDTA_LABELTABLE} is not {it:table} or {it:schema}{cmd:.}{it:table}; or
the {it:if} qualifier uses something that is not supported or a column that
does not exist{p_end}
{p2col:{cmd:r(459)}}a Link row is not valid, its key is not a column of the main
table and of the linked table, or the key repeats in the linked table{p_end}
{p2col:{cmd:r(601)}}the table or a linked table does not exist or cannot be
read{p_end}
{p2colreset}{...}

{pstd}
If a query fails, {cmd:sqldta} shows the message from the driver, followed by
the server, the database, the object and the connection used, the driver that
its template names or the ODBC data source, and stops with the return code of
{cmd:odbc load}. If the query that loads the data fails, a frame that
{cmd:sqldta} created for the load is dropped again, and a frame that held data
and was cleared, because {opt clear} was given, is left empty. A failure of the
query that
reads the label rows is the exception: {cmd:sqldta} displays a note and keeps
the data.


{marker examples}{...}
{title:Examples}

{pstd}
Show the settings in force, from the settings file and global macros, and try
the connection templates on the default server{p_end}
{phang2}{cmd:. sqldta settings}{p_end}

{pstd}
Set the server and the template for this Stata session only, as global
macros{p_end}
{phang2}{cmd:. global SQLDTA_SERVERS MYSERVER}{p_end}
{phang2}{cmd:. global SQLDTA_CONNECTION "Driver={c -(}ODBC Driver 18 for SQL Server{c )-};Server=%server%;Trusted_Connection=yes;TrustServerCertificate=yes;"}{p_end}

{pstd}
Load a table, with its labels and notes, into the current frame, which must be
empty{p_end}
{phang2}{cmd:. sqldta, database(MyDatabase) dataset(MyTable)}{p_end}

{pstd}
Load a table into a new frame, then work in that frame{p_end}
{phang2}{cmd:. sqldta, database(MyDatabase) dataset(MyTable) frame(adm)}{p_end}
{phang2}{cmd:. frame change adm}{p_end}

{pstd}
Load some columns of the rows that meet a condition, with value labels and
variable labels only, replacing the data in frame {cmd:adm}{p_end}
{phang2}{cmd:. sqldta if sex == 1 & age >= 65 & !missing(age), database(MyDatabase) dataset(MyTable) frame(adm) clear sqlselect(id sex age diag*) labels(values variables)}{p_end}

{pstd}
Load a table without labels{p_end}
{phang2}{cmd:. sqldta, database(MyDatabase) dataset(MyTable) frame(raw) labels(none)}{p_end}

{pstd}
Select rows by strings and dates{p_end}
{phang2}{cmd:. sqldta if inlist(region, "North", "South") & admdate >= td(01jul2024), database(MyDatabase) dataset(MyTable) frame(adm) clear}{p_end}

{pstd}
Select rows by a date-time column, and by the date of one{p_end}
{phang2}{cmd:. sqldta if admitted >= tc(01jul2024 00:00) & admitted < tc(01aug2024 00:00), database(MyDatabase) dataset(MyTable) frame(adm) clear}{p_end}
{phang2}{cmd:. sqldta if dofc(admitted) == td(15jul2024), database(MyDatabase) dataset(MyTable) frame(adm) clear}{p_end}

{pstd}
Use a T-SQL condition for what the {it:if} qualifier does not support{p_end}
{phang2}{cmd:. sqldta, database(MyDatabase) dataset(MyTable) sqlwhere(diag1 LIKE 'C1%' AND DATEDIFF(day, admdate, sepdate) > 30)}{p_end}

{pstd}
Load a random sample of 1,000 rows{p_end}
{phang2}{cmd:. sqldta, database(MyDatabase) dataset(MyTable) frame(sample) sqlrand(1000)}{p_end}

{pstd}
Load a table from another schema, with variable labels from another label
table{p_end}
{phang2}{cmd:. sqldta, server(MYSERVER) database(MyDatabase) dataset(staging.MyTable) labeltable(dbo.DataPropertiesNew) labels(variables)}{p_end}


{marker results}{...}
{title:Stored results}

{pstd}
{cmd:sqldta} stores the following in {cmd:r()}:

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}number of observations loaded{p_end}
{synopt:{cmd:r(k)}}number of variables loaded{p_end}
{synopt:{cmd:r(n_vallabels)}}number of value-label sets applied{p_end}
{synopt:{cmd:r(n_varlabels)}}number of variable labels applied{p_end}
{synopt:{cmd:r(n_formats)}}number of display formats applied{p_end}
{synopt:{cmd:r(n_varnotes)}}number of variable notes applied{p_end}
{synopt:{cmd:r(n_dtanotes)}}number of dataset notes applied{p_end}
{synopt:{cmd:r(n_skipped)}}number of label rows skipped{p_end}

{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(frame)}}target frame{p_end}
{synopt:{cmd:r(server)}}server{p_end}
{synopt:{cmd:r(database)}}database{p_end}
{synopt:{cmd:r(table)}}source table as {it:database}{cmd:.}{it:schema}{cmd:.}{it:table}{p_end}
{synopt:{cmd:r(sql)}}the query that loaded the data{p_end}
{synopt:{cmd:r(labels)}}label types applied, from {cmd:values variables formats varnotes dtanotes datalabel}; empty for {cmd:labels(none)}{p_end}
{synopt:{cmd:r(labelstatus)}}{cmd:none} ({cmd:labels(none)}), {cmd:applied},
{cmd:notfound} or {cmd:failed}{p_end}
{synopt:{cmd:r(description)}}the text of the DatasetDescription row of
PropertyCode 1, or empty{p_end}
{synopt:{cmd:r(converted)}}date-time columns, and date, bigint and wide numeric
columns converted from strings{p_end}
{synopt:{cmd:r(unicode)}}columns loaded as Unicode through {opt unicode()}{p_end}
{synopt:{cmd:r(datetimes)}}{cmd:number}, or {cmd:text} when {cmd:SQLDTA_DTTEXT}
asks for the earlier method{p_end}
{synopt:{cmd:r(links)}}linked tables, as {it:schema}{cmd:.}{it:table}{p_end}
{synopt:{cmd:r(linkkeys)}}keys of the linked tables, in the same order{p_end}
{synopt:{cmd:r(dropped)}}columns left out, separated by commas{p_end}
{synopt:{cmd:r(settings)}}the settings file read, or empty if none was found{p_end}
{p2colreset}{...}

{pstd}
{cmd:sqldta settings} stores the settings file in {cmd:r(file)}; each setting
in force in {cmd:r(servers)}, {cmd:r(databases)}, {cmd:r(defaultdb)},
{cmd:r(dlgremember)}, {cmd:r(dataschema)}, {cmd:r(labeltable)},
{cmd:r(labelfallback)} and {cmd:r(dttext)}; the connection templates in {cmd:r(connection1)},
{cmd:r(connection2)} and so on, with their number in {cmd:r(nconnections)};
the numbers of the lines of the file passed over in {cmd:r(ignored)}; and, for
the server in {cmd:r(server)}, the connection used in {cmd:r(connection)}, its
number in {cmd:r(template)}, 0 for the ODBC data source, and the return code
and seconds of each attempt in {cmd:r(rc1)}, {cmd:r(sec1)} and so on.


{marker author}{...}
{title:Author}

{pstd}
Warren Holroyd{break}
{browse "https://github.com/w4rhol/sqldta"}


{title:Also see}

{psee}
Help: {helpb odbc}, {helpb frames}, {helpb label}, {helpb notes}, {helpb format}
{p_end}
