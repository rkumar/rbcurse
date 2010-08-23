
README
------

### For ruby 1.9.2, 2010-08-23 11:48 

 Changes in 1.9.2 require the following changes:
  - $: no longer includes ".". 
    Fixed 2 examples.
  - hash_update: cannot update hash during iteration
    Modified rwidget.rb and rtable.rb

### IMPORTANT 

1. If you are trying out the examples from a folder that does not have
write access (e.g. /opt/local/lib...), then you may have to run the
examples, with "sudo", since a log file is created. Or else, you could
copy the examples elsewhere, or change to location of the log file
(view.log) before running.

    sudo ruby test2.rb

Update: in some examples, test1 test2 sqlm sqlc testkeypress i check
for LOGDIR. So you may do:

    LOGDIR=~/ ruby test2.rb

or just set LOGDIR

    export LOGDIR=~/tmp

2. Please change directory to the examples folder before executing, since
some data files, or local programs may be loaded.

## sqlc.rb

A sql client using tabbedpanes.

This uses a file testd.db that can be downloaded (check file for
location) or created using:

    sqlite3 testd.db < data.txt

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


