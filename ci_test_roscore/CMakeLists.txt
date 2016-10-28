cmake_minimum_required(VERSION 2.8.3)
project(ci_test_roscore)

find_package(catkin_simple REQUIRED)
catkin_simple()

catkin_add_nosetests(test/roscore-test.py)

cs_install()
cs_export()
