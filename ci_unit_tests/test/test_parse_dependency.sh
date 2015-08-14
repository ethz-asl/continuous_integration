#!/bin/bash -e

for dependency_w_branch in "git@test.test/simple" "git@test.test/simpleWithBranch;test_branch" "git@test.test/just_sha1;b66dda2" "git@test.test/withGitDescirbeLikeRevision;fix/moveRawAccess-429-gb66dda2"; do
  echo -e "********** Testing : $dependency_w_branch ************"

  echo "DependencySpec: $dependency_w_branch"
  
  source ../../modules/parse_dependency.sh

  echo "depth_args: $depth_args"
  echo "clone_args: $clone_args"
done
