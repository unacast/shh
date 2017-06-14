#!/bin/bash

_file=$1

git secret remove $_file

rm $_file.secret
git add $_file.secret
git commit -m "Removed secret of $_file"

# Remove line from .gitignore
sed "/$_file/d" .gitignore > .gitignore_bak & mv .gitignore_bak .gitignore
