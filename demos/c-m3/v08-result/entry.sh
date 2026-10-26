#!/bin/sh
clear
bat --language r --theme ansi --style plain --paging never demos/c-m3/v08-result/oracle.R
sleep 5
clear
exec R --quiet --no-save
