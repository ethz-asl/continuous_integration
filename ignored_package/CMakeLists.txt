cmake_minimum_required(VERSION 2.8.3)
project(ignored_test_pkg)

find_package(catkin_simple REQUIRED)
catkin_simple(ALL_DEPS_REQUIRED)

non_existing_cmake_method_to_check_that_this_package_is_correctly_ignored()

cs_install()
cs_export()
