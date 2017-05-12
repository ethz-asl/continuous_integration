# Make a separate workspace for the deps, so we can exclude them from cppcheck etc.
echo "Dependencies specified by rosinstall file.";
rm -f $WORKSPACE/$DEPS/.rosinstall || true # start fresh workspace so reduce double updates
wstool init $WORKSPACE/$DEPS || true


if $CHECKOUT_ASLAM_INSTALL; then
  # We need aslam_install for its rosinstall/ folder ...
  echo "- git: {local-name: aslam_install, uri: 'git@github.com:ethz-asl/aslam_install.git'}" | $WSTOOL_MERGE_REPLACE -
  # therefore we must update fore once already.
  $WSTOOL_UPDATE_REPLACE
fi

truncate -s 0 dependencies.rosinstall

# Make sure catkin_simple is onboard unless ! CHECKOUT_CATKIN_SIMPLE :
if $CHECKOUT_CATKIN_SIMPLE; then
  echo "- git: {local-name: catkin_simple, uri: '${CATKIN_SIMPLE_URL}'}" >> dependencies.rosinstall
fi
