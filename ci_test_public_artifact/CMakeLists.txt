cmake_minimum_required(VERSION 2.8.3)
project(ci_test_public_artifact)

find_package(catkin_simple REQUIRED)
catkin_simple()

catkin_add_nosetests(test/test.py
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/test
)

cs_install()
cs_export()
