#!/bin/bash

echo "Testing: NONE vs abc"
../../modules/rosinstall-diff.py NONE abc.rosinstall 2>&1
echo "RETURNED $?"

echo
echo "Testing: ab vs ab"
../../modules/rosinstall-diff.py ab.rosinstall ab.rosinstall 2>&1
echo "RETURNED $?"

echo
echo "Testing: ab vs abc"
../../modules/rosinstall-diff.py ab.rosinstall abc.rosinstall  2>&1
echo "RETURNED $?"
