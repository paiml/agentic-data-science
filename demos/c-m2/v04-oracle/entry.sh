#!/bin/sh
clear
bat --language r --theme ansi --style plain --paging never demos/c-m2/v04-oracle/oracle.R
sleep 5
clear
exec R --quiet --no-save
