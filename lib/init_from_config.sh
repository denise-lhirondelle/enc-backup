#!/bin/bash

function init_from_config {
    # Reads config file and sets settings from the file
    # Taken from:
    # http://mywiki.wooledge.org/glob
    # http://stackoverflow.com/a/20815951

    if [ -z "$1" ]; then
        echo "Error: first argument must be configuration file name"
        exit 1
    fi

    if [ ! -e $1 ]; then
        echo "Error: file does not exist"
        exit 1
    fi

    local configfile=$1

    # TODO: does this work in shells other than Bash?
    shopt -q extglob; extglob_set=$?
    ((extglob_set)) && shopt -s extglob

    tr -d '\r' < $configfile > $configfile.unix 

    while IFS='= ' read lhs rhs
    do
        if [[ ! $lhs =~ ^\ *# && -n $lhs ]]; then
            rhs="${rhs%%\#*}"    # Del in line right comments
            rhs="${rhs%%*( )}"   # Del trailing spaces
            rhs="${rhs%\"*}"     # Del opening string quotes 
            rhs="${rhs#\"*}"     # Del closing string quotes 
            declare $lhs="$rhs"
        fi
    done < $configfile.unix

    # Clean up after ourselves
    ((extglob_set)) && shopt -u extglob
    rm $configfile.unix
}
