#!/bin/sh
clear
bat --language r --theme ansi --style plain --paging never demos/c-m4/v03-red/oracle.R
sleep 5
clear
exec R --quiet --no-save
