
README
------

### IMPORTANT 

1. If you are trying out the examples from a folder that does not have
write access (e.g. /opt/local/lib...), then you may have to run the
examples, with "sudo", since a log file is created. Or else, you could
copy the examples elsewhere, or change to location of the log file
(view.log) before running.

    sudo ruby test2.rb

2. Please change directory to the examples folder before executing, since
some data files, or local programs may be loaded.

## sqlc.rb

A sql client using tabbedpanes.

Enter an sql query in the textbox. Click Run.

Or Press Enter on the name of a table in the tables listing. Its
contents will be shown in a new tab in the tabbedpane.

Or Press Space on a table. Its columns are shown below. Now select
columns and then click Construct. Selected columns will be used to
construct a query. Press Run to execute it.

If you are inside a table, use Alt-TAb to exit.

## sqlm.rb

Identical to sqlc.rb. This demo uses a multi-container for multiple
resultsets instead of a tabbedpane.

* * * * *

Please check the examples  with  test*.rb - since they are updated. 
At the time of writing, viewtodo.rb may not be functional since I
changed to structure of the yaml file.

## vim:tw=72:ai:formatoptions=tcqln:nocindent:


