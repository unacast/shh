#!/bin/bash

_public_key=$1
_email=$2

gpg --import $_public_key
git secret tell $_email

git secret reveal -f
git secret hide

git add .gitsecret
git add *.secret
git commit -m "Added public key of $_email"
