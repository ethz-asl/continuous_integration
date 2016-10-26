#!/bin/bash -e
export PATH=/usr/local/bin/:$PATH

source /opt/ros/indigo/setup.sh
# Get the directory of this script.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PACKAGE="--all"
DEPENDENCIES=""
COMPILER="gcc"
RUN_TESTS=true
RUN_CPPCHECK=true
MERGE_DEVEL=true
CHECKOUT_CATKIN_SIMPLE=true
PREPARE_SCRIPT=""

# DEPS must be below src/ !
DEPS=src/dependencies

WSTOOL_MERGE_REPLACE="wstool merge --confirm-all --merge-replace -t $WORKSPACE/$DEPS"
WSTOOL_UPDATE_REPLACE="wstool update --delete-changed-uris -t $WORKSPACE/$DEPS -j8"

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
  -c=*|--compiler=*)
  COMPILER="${i#*=}"
  ;;
  -t|--no_tests)
  RUN_TESTS=false
  ;;
  -M|--no_merge_devel)
  MERGE_DEVEL=false
  ;;
  -n|--no_cppcheck)
  RUN_CPPCHECK=false
  ;;
  -s|--no_catkinsimple)
  CHECKOUT_CATKIN_SIMPLE=false
  ;;
  -x=*|--prepare-system-script=*)
    PREPARE_SCRIPT="${i#*=}"
  ;;
  *)
    echo "Unknown option: $i!" >&2
    echo "Usage: run_build [{-d|--dependencies}=dependency_github_url.git]"
    echo "  [{-p|--packages}=packages]"
    echo "  [{--compiler}=gcc/clang]"
    echo "  [{-t|--no_tests} skip gtest execution]"
    echo "  [{-M|--no_merge_devel} don't activate catkin merge-devel mode]"
    echo "  [{-c|--no_cppcheck} skip cppcheck execution]"
    echo "  [{-s|--no_catkinsimple} skip checking out catkin simple]"
    echo "  [{-x|--prepare-system-script} run this script between cloning and building]"
    exit -1
  ;;
esac
done

cd $WORKSPACE
echo "-----------------------------"
# Locate the main folder everything is checked out into.
REP=$(find . -maxdepth 3 -type d -name .git -a \( -path "./$DEPS/*" -prune -o -print -quit \) )
if [ -n "${REP}" ]; then
  REP=$(dirname "${REP}")
  repo_url_self=$(cd "${REP}" && git config --get remote.origin.url)
  echo "Found my repository at ${REP}: repo_url_self=${repo_url_self}."
fi

echo "-----------------------------"

# If no packages are defined, we select all packages that are non-dependencies.
# Get all package xmls in the tree, which are non dependencies.
if [ -z "$PACKAGES" ]; then
  echo "Auto discovering packages to build."
  all_package_xmls="$(find ./src -name package.xml | grep -v $DEPS)"
  catkin list | cut -f2 -d\  > ./all_catkin_packages_in_src.list

  for package_xml in ${all_package_xmls}
  do
    # Read the package name from the xml.
    package="$(echo 'cat //name/text()' | xmllint --shell ${package_xml} | grep -Ev "/|-")"
    pkg_path=${package_xml%package.xml}
    if [ -f "${pkg_path}/CATKIN_IGNORE" ]; then
      echo "Skipping package $package since the package contains CATKIN_IGNORE."
    elif [ -f "${pkg_path}/CI_IGNORE" ]; then
      echo "Skipping package $package since the package contains CI_IGNORE."
    elif ! echo $package | grep -qxFf ./all_catkin_packages_in_src.list; then
      echo "Skipping package $package because 'catkin list' did not find it!"
    else
      PACKAGES="${PACKAGES} $package"
      echo "Added package $package."
    fi
  done
  echo "Found $PACKAGES by autodiscovery."
fi

# If the build job specifies a rosinstall file, we overwrite the build-job config dep list.
if [ -n "$rosinstall_file" ]; then
  echo "Variable '$rosinstall_file' specified, overwriting specified dependencies."
  DEPENDENCIES=$rosinstall_file
fi

echo "Parameters:"
echo "-----------------------------"
echo "Workspace: ${WORKSPACE}"
echo "Packages: ${PACKAGES}"
echo "Dependencies: ${DEPENDENCIES}"
echo "Execute integration tests: ${RUN_TESTS}"
echo "Run cppcheck: ${RUN_CPPCHECK}"
echo "Checkout catkin simple: ${CHECKOUT_CATKIN_SIMPLE}"
echo "Run prepare script: ${PREPARE_SCRIPT}"
echo "-----------------------------"

# If we are on a mac we only support Apple Clang for now.
unamestr=`uname`
if [[ "$unamestr" == 'Darwin' ]]; then
  echo "Running on OSX setting compiler to clang."
  COMPILER="clang"
fi

echo "Compilers:"
echo "-----------------------------"
if [ "$COMPILER" == "gcc" ]
then
  gcc -v
  g++ -v
  export CC=gcc
  export CXX=g++
fi
if [ "$COMPILER" == "clang" ]
then
  clang -v
  export CC=clang
  export CXX=clang++
fi
echo "-----------------------------"

# Dependencies: Install using rosinstall or list of repositories from the build-job config.

if $CHECKOUT_CATKIN_SIMPLE; then
  CATKIN_SIMPLE_URL=https://github.com/catkin/catkin_simple.git
else
  CATKIN_SIMPLE_URL=""
fi
mkdir -p $WORKSPACE/$DEPS && cd $WORKSPACE/$DEPS

if [[ $DEPENDENCIES == *.rosinstall ]]
then
  source /opt/ros/indigo/setup.sh
  cd $WORKSPACE/src
  catkin_init_workspace || true

  mkdir -p $WORKSPACE/$DEPS
  cd $WORKSPACE/$DEPS

  # Make a separate workspace for the deps, so we can exclude them from cppcheck etc.
  echo "Dependencies specified by rosinstall file.";
  if [ ! -f .rosinstall ]
  then
    wstool init || true
  fi

  # We need aslam_install for its rosinstall/ folder ...
  echo "- git: {local-name: aslam_install, uri: 'git@github.com:ethz-asl/aslam_install.git'}" | $WSTOOL_MERGE_REPLACE -
  # therefore we must update fore once already.
  $WSTOOL_UPDATE_REPLACE

  # Make sure catkin_simple is onboard unless ! CHECKOUT_CATKIN_SIMPLE :
  if $CHECKOUT_CATKIN_SIMPLE; then
    echo "- git: {local-name: catkin_simple, uri: '${CATKIN_SIMPLE_URL}'}" | $WSTOOL_MERGE_REPLACE -
  fi

  truncate -s 0 dependencies.rosinstall
  for dep in $DEPENDENCIES; do
    # Remove the entry from the provided rosinstall that specifies this repository itself (if any).
    if [[ $dep == ./* ]]; then # DEPENDENCIES starting with ./ are considered local (within the repository) rosinstall files
      depPath="${WORKSPACE}/src/${dep}"
    else
      depPath="${WORKSPACE}/${DEPS}/aslam_install/rosinstall/${dep}"
    fi
    echo "Collecting dependencies from $depPath."
    if [ -n "$repo_url_self" ] ;then
      grep -iv $repo_url_self "$depPath" >> dependencies.rosinstall
    else
      cat "$depPath" >> dependencies.rosinstall
    fi
  done
  
  echo "Rosinstall to use:"
  cat dependencies.rosinstall
  $WSTOOL_MERGE_REPLACE dependencies.rosinstall
  $WSTOOL_UPDATE_REPLACE
else
  DEPENDENCIES="${DEPENDENCIES} ${CATKIN_SIMPLE_URL}"

  for dependency_w_branch in ${DEPENDENCIES}
  do
    cd $WORKSPACE/$DEPS
    
    source $DIR/modules/parse_dependency.sh

    if [ -d $foldername ]; then
      echo "Package $foldername exists, running: git fetch $depth_args && git checkout ${revision} && git submodule update --recursive"
      (cd "$foldername" && git fetch $depth_args && git checkout ${revision} && git submodule update --recursive)
    else
      echo "Package $foldername does not exist, running: clone $clone_args $depth_args --recursive \"$dependency\""
      git clone $clone_args $depth_args --recursive "$dependency"
      if [ -z "$branch" ]; then # this means we know a specific (nameless) commit to checkout
        (cd "$foldername" && git checkout ${revision} && git submodule update --recursive)
      fi
    fi
  done
fi

cd $WORKSPACE

if [[ -n "$PREPARE_SCRIPT" ]]; then
  echo
  echo "--------------------------------------------------------------------------------"
  # Prepare scripts must run exclusively per node because they might install packages.
  LOCKFILE=/var/lock/jenkins-prepare-script.lock
  echo "Acquiring prepare script lock $LOCKFILE";
  (
    export DEBIAN_FRONTEND=noninteractive
    if ! flock -w 300 -n 9; then
     echo "Locking $LOCKFILE timed out!" >&2
     exit -2
    fi
    echo "Running $PREPARE_SCRIPT in $WORKSPACE:";
    bash -ex $PREPARE_SCRIPT
    echo "Successfully run $PREPARE_SCRIPT.";
    rm $LOCKFILE;
  ) 9>$LOCKFILE
  echo "--------------------------------------------------------------------------------"
  echo
fi

# Prepare cppcheck ignore list. We want to skip dependencies.
CPPCHECK_PARAMS="src --xml --enable=missingInclude,performance,style,portability,information -j8 -ibuild -i$DEPS"

#Now run the build.
if $DIR/run_build_catkin_or_rosbuild ${RUN_TESTS} ${PACKAGES}; then
  if [[ "$unamestr" == 'Linux' ]]; then
    echo "Running cppcheck $CPPCHECK_PARAMS ..."
    # Run cppcheck excluding dependencies.
    cd $WORKSPACE
    if $RUN_CPPCHECK; then
      rm -f cppcheck-result.xml
      cppcheck $CPPCHECK_PARAMS 2> cppcheck-result.xml
    fi
  fi
else
  exit 1
fi


