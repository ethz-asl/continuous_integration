#!/bin/bash


CWD=$(pwd)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PACKAGE="--all"
DEPENDENCIES=""

# Download / update dependencies.
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

# Prepare cppcheck ignore list. We want to skip dependencies.
CPPCHECK_PARAMS=". --xml --quiet --enable=all "

mkdir -p $WORKSPACE/src && cd $WORKSPACE/src
for dependencies in ${DEPENDENCIES}
do
    foldername_w_ext=${dependencies##*/}
    foldername=${foldername_w_ext%.*}
    if [ -d $foldername ]; then
      echo Folder "$foldername" exists, running git pull on "$dependencies"
      cd "$foldername" && git pull && cd ..
    else
      echo Folder "$foldername" does not exists, running git clone "$dependencies"
      git clone "$dependencies" --recursive
    fi  
    CPPCHECK_PARAMS="$CPPCHECK_PARAMS -i$foldername"
done
cd $WORKSPACE

#Now run the build.
$DIR/run_build_catkin_or_rosbuild ${PACKAGES}

echo "Running cppcheck $CPPCHECK_PARAMS ..."
# Run cppcheck excluding dependencies.
cd $CWD
cppcheck $CPPCHECK_PARAMS > cppcheck-result.xml
