#!/bin/bash

# Get the directory of this script.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

PACKAGE="--all"
DEPENDENCIES=""
COMPILER="gcc"
RUN_TESTS=true
RUN_CPPCHECK=true

DEPS=src/dependencies

echo "******************** $SVN_URL"

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
    -n|--no_cppcheck)
    RUN_CPPCHECK=false
    ;;
    *)
       echo "Usage: run_build [{-d|--dependencies}=dependency_github_url.git]"
       echo "  [{-p|--packages}=packages]"
       echo "  [{--compiler}=gcc/clang]"
       echo "  [{-t|--no_tests} skip gtest execution]"
       echo "  [{-c|--no_cppcheck} skip cppcheck execution]"
    ;;
esac
done

# Refetch the repository as it is not reliably done by Jenkins!
echo -e "\nExecuting Jenkins independent refetch:"
cd $WORKSPACE
echo "-----------------------------"
if [ -n "${sha1}" ]; then
	REP=$(find . -maxdepth 3 -type d -name .git -a \( -path "./$DEPS/*" -prune -o -print -quit \) )
	if [ -n "${REP}" ]; then
		REP=$(dirname "${REP}")
		echo "Refetching in ${REP} and checking out ${sha1} :"
		(cd "${REP}" && git fetch origin --depth 1 && git checkout "${sha1}");
	    cd "${REP}" && repo_url_self=$(git config --get remote.origin.url)
	else
		echo "ERROR: Could not find repository to run Jenkins independent refetch."
	fi
else
	echo "SKIPPING: Variable sha1 not set or empty!"
fi
echo "-----------------------------"

# If no packages are defined, we select all packages that are non-dependencies.
# Get all package xmls in the tree, which are non dependencies.
if [ -z "$PACKAGES" ]; then
    all_package_xmls="$(find . -name "package.xml" | grep -v "$DEPS")"
	echo "Auto discovering packages to build."
	for package_xml in ${all_package_xmls}
	do
		# Read the package name from the xml.
	    package="$(echo 'cat //name/text()' | xmllint --shell ${package_xml} | grep -Ev "/|-")"
		PACKAGES="${PACKAGES} $package"
	done
	echo "Found $PACKAGES by autodiscovery."
fi

# If the build job specifies a rosinstall file, we overwrite the build-job config dep list.
if [ -z "$rosinstall_file" ]; then
	echo "No rosinstall file specified, using dependency list from build-job config."
else
	echo "Rosinstall file: $rosinstall_file specified, overwriting specified dependencies."
	DEPENDENCIES=$rosinstall_file
fi

echo "Parameters:"
echo "-----------------------------"
echo "Packages: ${PACKAGES}"
echo "Dependencies: ${DEPENDENCIES}"
echo "Execute integration tests: ${RUN_TESTS}"
echo "Run cppcheck: ${RUN_CPPCHECK}"
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
CATKIN_SIMPLE_URL=git@github.com:catkin/catkin_simple.git
mkdir -p $WORKSPACE/$DEPS && cd $WORKSPACE/$DEPS

if [[ $DEPENDENCIES == *.rosinstall ]]
then
	source /opt/ros/indigo/setup.sh
	cd $WORKSPACE/src
	catkin_init_workspace || true
	wstool init || true
	
	# Make a separate workspace for the deps, so we can exclude them from cppcheck etc.
	mkdir -p $WORKSPACE/$DEPS
	cd $WORKSPACE/$DEPS
	wstool set -t $WORKSPACE/src aslam_install --git git@github.com:ethz-asl/aslam_install.git -y
	wstool set -t $WORKSPACE/src catkin_simple --git ${CATKIN_SIMPLE_URL} -y
	wstool update -t $WORKSPACE/src -j8

    echo "Dependencies specified by rosinstall file.";
	wstool init || true
	# Remove the entry from the provided rosinstall that specifies this repository itself:
	grep -iv $repo_url_self ${WORKSPACE}/${DEPS}/aslam_install/rosinstall/${DEPENDENCIES} > dependencies.rosinstall
	echo "Rosinstall to use:"
	cat dependencies.rosinstall
	wstool merge -t . dependencies.rosinstall
	wstool update -t . -j8
else
	DEPENDENCIES="${DEPENDENCIES} ${CATKIN_SIMPLE_URL}"

	for dependency_w_branch in ${DEPENDENCIES}
	do  
	    cd $WORKSPACE/$DEPS
	    IFS=';' read -ra all_dep_parts <<< "$dependency_w_branch"
	    dependency=${all_dep_parts[0]}
	    branch=${all_dep_parts[1]}
	    if [ -z "$branch" ]; then
	        branch="master"
	    fi
	
		echo Dependency: "$dependency"
		echo Branch: "$branch"
	
	    foldername_w_ext=${dependency##*/}
	    foldername=${foldername_w_ext%.*}
	    if [ -d $foldername ]; then
  	        echo Package "$foldername" exists, running git fetch --depth 1, git reset --hard origin/HEAD and git submodule update --recursive on "$dependency"
  	        cd "$foldername" && git fetch --depth 1 && git checkout origin/${branch} && git submodule update --recursive && cd ..
	    else
	        echo Package "$foldername" does not exist, running git clone "$dependency" --recursive
	        git clone -b ${branch} "$dependency" --recursive --depth 1 --single-branch
	    fi
	done
fi

cd $WORKSPACE

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


