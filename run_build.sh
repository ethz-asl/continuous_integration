#!/bin/bash
CWD=$(pwd)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Reload ci scripts from repo.
cd $DIR
git pull
cd $CWD

# Now run actual script.
run_build_impl.sh
