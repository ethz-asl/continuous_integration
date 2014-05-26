cmake_minimum_required(VERSION 2.8.3)
project(ci_test_pkg)

find_package(catkin_simple REQUIRED)
catkin_simple()

add_definitions(-DGTEST_USE_OWN_TR1_TUPLE=0)
catkin_add_gtest(${PROJECT_NAME}_tests test/test.cc)
SET(CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS "${CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS} -lpthread")

cs_install()
cs_export()
