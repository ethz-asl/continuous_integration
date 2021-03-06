#!/bin/bash -e
export PATH=/usr/local/bin/:$PATH

# Get the directory of this script.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export CI_MODULES=$DIR/modules

# "Setup common functions and definitions and source current ROS"
source $CI_MODULES/common_definitions.sh

PACKAGE="--all"
DEPENDENCIES=""
COMPILER="gcc"
RUN_TESTS=true
DEFAULT_NUM_PARALLEL_TEST_JOBS=1
NUM_PARALLEL_TEST_JOBS=$DEFAULT_NUM_PARALLEL_TEST_JOBS
RUN_CPPCHECK=true
MERGE_DEVEL=true
CHECKOUT_CATKIN_SIMPLE=true
PREPARE_SCRIPT=""
DEFAULT_NICENESS=5
NICENESS=$DEFAULT_NICENESS
START_ROSCORE=false


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
  --niceness=*)
    NICENESS="${i#*=}"
  ;;
  -r|--roscore)
    START_ROSCORE=true
  ;;
  --num_parallel_test_jobs=*)
    NUM_PARALLEL_TEST_JOBS="${i#*=}"
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
    echo "  [{--niceness} niceness for the job (default $DEFAULT_NICENESS)]"
    echo "  [{--num_parallel_test_jobs} maximum number of parallel unit tests executed (default $DEFAULT_NUM_PARALLEL_TEST_JOBS)]"
    echo "  [{-r|--roscore} start a roscore for this job]"
    exit 2
  ;;
esac
done

# run sanity checks:
source $CI_MODULES/sanity_checks.sh

# Find workspace
cd $WORKSPACE
echo "-----------------------------"
# Locate the main folder everything is checked out into.
REP=$(find . -maxdepth 3 -type d -name .git -a \( -path "./$DEPS/*" -prune -o -path "./test_repos/*" -prune -o -print -quit \) )
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
    elif [[ ${pkg_path} == *"thirdparty"* ]]; then
      echo "Skipping package $package because its path contains 'thirdparty'."
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
echo "CATKIN_ARGS: ${CATKIN_ARGS}"
echo "NUM_PARALLEL_TEST_JOBS: ${NUM_PARALLEL_TEST_JOBS}"
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


echo "Process setup:"
echo "-----------------------------"

echo "Setting niceness to $NICENESS."
renice -n $NICENESS -p $$

if (( $NICENESS >= 10 )) ; then
  if [[ $(uname) == 'Linux' ]] ; then
    echo "Setting scheduling class to 'idle' because $NICENESS is >= 10."
    ionice -c 3 -p $$
  fi
fi
echo "-----------------------------"

echo "Initialize workspace:"
echo "-----------------------------"
source /opt/ros/$ROS_VERSION_NAME/setup.sh

cd $WORKSPACE/
mkdir -vp $WORKSPACE/src
catkin init
echo "-----------------------------"

echo "Pull dependencies:"
echo "-----------------------------"
mkdir -vp $WORKSPACE/$DEPS
cd $WORKSPACE/$DEPS

if [[ $DEPENDENCIES == *.rosinstall ]]
then
  CHECKOUT_ASLAM_INSTALL=true
  source $CI_MODULES/prepare_wstool_workspace.sh

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
  cp dependencies.rosinstall .rosinstall
  $WSTOOL_UPDATE_REPLACE

elif [ "$DEPENDENCIES" == "AUTO" ]; then
  echo "Performing AUTO dependency discovery:";
  $CI_MODULES/pull_auto_dependencies.sh
else
  if $CHECKOUT_CATKIN_SIMPLE; then
    DEPENDENCIES="${DEPENDENCIES} ${CATKIN_SIMPLE_URL}"
  fi

  for dependency_w_branch in ${DEPENDENCIES}
  do
    cd $WORKSPACE/$DEPS
    
    source $CI_MODULES/parse_dependency.sh

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
echo "-----------------------------"


if [[ -n "$PREPARE_SCRIPT" ]]; then
  echo "Run prepare script:"
  echo "-----------------------------"
  cd $WORKSPACE

  function runPrepareScript() {
    export DEBIAN_FRONTEND=noninteractive
    echo "Running $PREPARE_SCRIPT in $WORKSPACE:";
    bash -ex $PREPARE_SCRIPT
    echo "Successfully run $PREPARE_SCRIPT.";
  }

  # Prepare scripts should run exclusively per node because they might install packages.
  if [ -d /var/lock ] && command -v flock >/dev/null 2>&1; then
    LOCKFILE=/var/lock/jenkins-prepare-script.lock
    echo "Acquiring prepare script lock $LOCKFILE";
    (
      if ! flock -w 300 9; then
        echo "Locking $LOCKFILE timed out!" >&2
        exit 3
      fi
      runPrepareScript
    ) 9>$LOCKFILE
  else
    echo "WARNING going to run prepare script on a crippled UNIX ($unamestr) : no /var/lock or flock available and therefore no exclusive run!" >&2
    runPrepareScript
  fi
  echo "-----------------------------"
fi


echo "Build workspace:"
echo "-----------------------------"
cd $WORKSPACE

# Prepare cppcheck ignore list. We want to skip dependencies.
CPPCHECK_PARAMS="src --xml --enable=missingInclude,performance,style,portability,information -j8 -ibuild -i$DEPS"

function kill_roscore_on_exit {
  if $START_ROSCORE && [[ "$ROS_PID" -gt 0 ]] ; then
    # Kill roscore.
    kill $ROS_PID
  fi
}

if $START_ROSCORE ; then
  ROS_PORT=-1
  ROS_HOME=$HOME/.ros

  # Check if lsof is installed.
  if ! (command -v lsof > /dev/null) ; then
    if [[ $(uname) == 'Linux' ]] ; then
      export DEBIAN_FRONTEND=noninteractive
      sudo apt-get install -y lsof
    else
      fatal "lsof not installed: can't scan for free port for the roscore."
    fi
  fi

  # Check for a free port.
  echo "Looking for an unused port for the roscore."
  for i in `seq 12000 13000`
  do
    # Check if port is unused.
    if ! (lsof -i :$i > /dev/null ) ; then
      export ROS_PORT=$i
      break
    fi
  done

  if [ $ROS_PORT -lt 0 ] ; then
    fatal "Couldn't find an unused port for the roscore."
  fi

  # Start roscore.
  export ROS_MASTER_URI="http://localhost:$ROS_PORT"
  echo "Starting roscore on port $ROS_PORT."
  roscore -p $ROS_PORT > /dev/null & 
  ROS_PID=$!
  trap kill_roscore_on_exit EXIT
fi

#Now run the build.
if $DIR/run_build_catkin_or_rosbuild ${RUN_TESTS} ${NUM_PARALLEL_TEST_JOBS} ${PACKAGES}; then
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
  exit $?
fi

echo "-----------------------------"
