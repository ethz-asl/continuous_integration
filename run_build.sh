#!/bin/bash
CWD=$(pwd)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR
git pull
cd $CWD

OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Store the package to build or otherwise build all with rosbuild:
package_to_build="--all"

while getopts "h?p:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    p)  package_to_build=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

echo "package_to_build='$package_to_build', Leftovers: $@"

for dependencies in "$@"
do
    git clone "$dependencies"
done

$DIR/run_build_catkin_or_rosbuild $package_to_build
