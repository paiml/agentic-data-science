#!/bin/sh
clear
bat --language r --theme ansi --style plain --paging never demos/c-m3/v05-green/oracle.R
sleep 5
clear
exec R --quiet --no-save
