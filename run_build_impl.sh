#!/bin/bash

# Hardcode the new gtest version.
GTEST_ROOT=$HOME/gtest-1.7.0

# Get the directory of the script.
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
       echo "Usage: run_build [{-d|--dependencies}=dependency_github_url.git] [{-p|--packages}=packages]"
    ;;
esac
done
echo PACKAGES = "${PACKAGES}"
echo DEPENDENCIES = "${DEPENDENCIES}"

DEPS=src/dependencies

# Prepare cppcheck ignore list. We want to skip dependencies.
CPPCHECK_PARAMS=". src --xml --enable=all -j8 -ibuild -i$DEPS"

mkdir -p $WORKSPACE/$DEPS && cd $WORKSPACE/$DEPS
for dependency in ${DEPENDENCIES}
do
    foldername_w_ext=${dependency##*/}
    foldername=${foldername_w_ext%.*}
    if [ -d $foldername ]; then
      echo Package "$foldername" exists, running git pull on "$dependency"
      cd "$foldername" && git pull && cd ..
    else
      echo Package "$foldername" does not exists, running git clone "$dependency"
      git clone "$dependency" --recursive
    fi
done
cd $WORKSPACE

#Now run the build.
if $DIR/run_build_catkin_or_rosbuild ${PACKAGES}; then
  echo "Running cppcheck $CPPCHECK_PARAMS ..."
  # Run cppcheck excluding dependencies.
  cd $WORKSPACE
  rm -f cppcheck-result.xml
  cppcheck $CPPCHECK_PARAMS 2> cppcheck-result.xml || true
else
 exit 1
fi


