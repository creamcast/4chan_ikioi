# Trendchan
Outputs an html site showing a table of the most active threads on 4chan. Written in PureBasic

## Compiling
This program requires the latest version of Purebasic (http://www.purebasic.com) to compile. Open ikio.pb with the PB IDE and compile as a console application.

## Usage
execute the command in a terminal (Linux, Mac) or Command Line (Windows)
It will automatically download the required info from 4chan api and calculate the most active threads for each board that was added to the hard coded list. (located at line 284 )
An index.html file will be generated containing a comprehensive active ranking of threads from the calculated boards. For each board it will create html file containing an active ranking of threads.
