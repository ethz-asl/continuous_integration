cmake_minimum_required(VERSION 2.8.3)
project(test_package)

find_package(catkin REQUIRED)
catkin_package()

catkin_add_nosetests( 
  TestPackage.py
  WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/
)
