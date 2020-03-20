#!/bin/sh

cd test && (
  ls | grep \.sh$ | while read script; do
    sh ${script}
    if [ "$?" -ne "0" ]; then
      echo "ERROR: ${script}"
    fi
  done
) | tee /dev/stderr | grep ERROR

# Error occured
if [ "$?" -eq "0" ]; then
  exit 1
else
  exit 0
fi
