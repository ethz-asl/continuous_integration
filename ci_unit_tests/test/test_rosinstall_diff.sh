#!/bin/bash

echo "Testing: NONE vs abc"
../../modules/rosinstall_diff.py NONE abc.rosinstall 2>&1
echo "RETURNED $?"

echo
echo "Testing: ab vs ab"
../../modules/rosinstall_diff.py ab.rosinstall ab.rosinstall 2>&1
echo "RETURNED $?"

echo
echo "Testing: ab vs abc"
../../modules/rosinstall_diff.py ab.rosinstall abc.rosinstall  2>&1
echo "RETURNED $?"

echo
echo "Testing: ab vs workspace/test_repos/"
../../modules/rosinstall_diff.py ab.rosinstall workspace/test_repos/  2>&1; 
echo "RETURNED $?"
