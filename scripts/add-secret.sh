#!/bin/bash

# fail fast
set -e

files="$@"

# call reveal in case some new files have been added by
# someone else
git secret reveal -f

for _file in "$@"
do
	echo $_file >> .gitignore
	git secret add $_file
	git secret hide

done
find "$PWD" -type f -name "*.secret" -print0 | xargs -0 git add
git add .gitignore
git add .gitsecret/
git commit -m "Added secret for $files"
