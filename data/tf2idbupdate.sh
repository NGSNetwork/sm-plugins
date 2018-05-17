#!/bin/bash
# Update TF2IDB DB, V1

# DEPENDENCIES:
#       python3

# Place in the sourcemod/data directory and point it to the other directories.

# This simply runs the python script for updating, and copies it where needed.
# Very simplistic program, set what you need with absolute paths.

TF2IDBSCRIPTDIR="/path/to/tf2idb"
SOURCEMODDATADIR="/path/to/sourcemod/data"

cd $TF2IDBSCRIPTDIR

echo "Working in:"
pwd

python3 tf2idb.py
cp tf2idb.sq3 $SOURCEMODDATADIR/sqlite

echo "Finished!"
