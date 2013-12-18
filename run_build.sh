#!/bin/bash
CWD=$(pwd)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR
git pull
cd $CWD

PACKAGE="--all"
DEPENDENCIES=""

for i in "$@"
do
case $i in
    -p=*|--packages=*)
    PACKAGES="${i#*=}"
    ;;
    -d=*|--dependencies=*)
    DEPENDENCIES="${i#*=}"
    ;;
    *)
       echo "Usage: run_build [{-d|--dependencies}=dependency.git] [{-p|--packages}=packages]"
    ;;
esac
done
echo PACKAGES = "${PACKAGES}"
echo DEPENDENCIES = "${DEPENDENCIES}"

mkdir -p $WORKSPACE/src && cd $WORKSPACE/src
for dependencies in ${DEPENDENCIES}
do
    git clone "$dependencies"
done
cd $WORKSPACE

$DIR/run_build_catkin_or_rosbuild ${PACKAGES}
