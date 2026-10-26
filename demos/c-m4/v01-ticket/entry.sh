#!/bin/sh
clear
bat --language r --theme ansi --style plain --paging never demos/c-m4/v01-ticket/oracle.R
sleep 5
clear
exec R --quiet --no-save
