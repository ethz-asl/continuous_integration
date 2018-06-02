#!/bin/bash -e

source "$CI_MODULES/common_definitions.sh"

DEP_FILE_NAME=dependencies.rosinstall
DEP_WORKSPACE_FILE=.rosinstall

normalIFS="$IFS"
IFS=$'\n' DEPS_FILES=($(find "${WORKSPACE}/src/" -maxdepth 4 -name $DEP_FILE_NAME | grep -Fv "^${WORKSPACE}/$DEPS/"))
IFS="$normalIFS"

if [[ ${#DEPS_FILES[@]} -eq 0 ]]; then
  fatal "Could not find any $DEP_FILE_NAME within ${WORKSPACE}/src/"
fi

CHECKOUT_ASLAM_INSTALL=false
source "$CI_MODULES/prepare_wstool_workspace.sh"

while true; do
  new_packages=()
  for dep_file in "${DEPS_FILES[@]}"; do
    echo "Processing dependency file $dep_file"
    IFS=$'\n' np=($("$CI_MODULES/rosinstall_diff.py" $DEP_WORKSPACE_FILE $dep_file))
    IFS="$normalIFS"
    if [ -n "$np" ] ; then echo "Found new packages: ${np[@]}."; fi
    new_packages+=("${np[@]}")
    eval "$WSTOOL_MERGE_REPLACE $dep_file" # TODO Why is that necessary?
  done
  if [[ ${#new_packages[@]} -eq 0 ]] ; then 
    break
  fi
  echo "Updating new packges '${new_packages[@]}'"
  $WSTOOL_UPDATE_REPLACE "${new_packages[@]}"
  DEPS_FILES=($(find "${new_packages[@]}" -maxdepth 3 -name $DEP_FILE_NAME))
done

unset new_packages

IFS=$'\n' all_superfluous_local_names=($("$CI_MODULES/rosinstall_diff.py" $DEP_WORKSPACE_FILE ${WORKSPACE}/$DEPS/))
IFS="$normalIFS"

if [ -n "$all_superfluous_local_names" ]; then
  echo "Deleting superfluous ${all_superfluous_local_names[@]}"
  rm -irf "${all_superfluous_local_names[@]}"
fi

