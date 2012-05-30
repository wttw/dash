dash - Dashboard and Reporting
==============================

dash is a simple web application that takes ajax queries containing
SQL and a list of variable bindings, runs that query against a postgresql
database and returns the results as a JSON (or XML, HTML, CSV, etc.)
format document.

That makes it easy to create simple tabular reports with just a little
javascript, and possible to do more complex things such as embedded charts,
clouds, or anything else you can do with your favorite javascript libraries.

dash is implemented in pure perl as a [Dancer](http://perldancer.org/)
application, so can be run standalone or embedded via PSGI or FastCGI
in a bigger application.

Reports are written mostly in javascript, and dash bundles quite a few
javascript libraries (jquery, TableTools, ZeroClipboard, chosen,
d3, jquery.sparkline...) that are useful for developing reports.

No screenshots right now, but there will be some at
http://labs.wordtothewise.com/dash eventually.

dash was developed to provide basic dashboard and reporting functionality
for the [Abacus](http://wordtothewise.com/products/abacus.html) CRM system.
This release was extracted from abacus, but you may still see some references
and I've included some of the Abacus reports as examples.
