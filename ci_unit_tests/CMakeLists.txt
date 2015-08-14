cmake_minimum_required(VERSION 2.8.3)
project(ci_unit_tests)

find_package(catkin_simple REQUIRED)
catkin_simple()

cs_install()
cs_export()

catkin_add_nosetests( 
  test/Test.py
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/test
)
