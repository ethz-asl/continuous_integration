#!/bin/bash
## This script does nothing but update the local repo and then forward everything
## to the actual build script which by this time is updated from the remote.
CWD=$(pwd)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Reload ci scripts from repo.
cd $DIR
git checkout master
git pull
cd $CWD

# Now run actual script.
$DIR/run_build_impl.sh "$@"
