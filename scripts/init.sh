#!/bin/bash

echo "cleaning up git history"
rm -rf .git/

echo "git initialization"
git init

echo "git secret initialization"
git secret init

echo -n "Enter your gpg mail and press [ENTER]: "
read email

echo "Adding the first user to shh."
git secret tell $email

echo "Add initial commit"
git add .
git commit -m "initial commit"