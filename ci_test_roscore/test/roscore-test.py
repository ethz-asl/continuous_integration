#!/usr/bin/env python
PKG = 'ci_test_roscore'

import rosgraph
import socket
import sys
import unittest

## A sample python unit test
class TestRoscore(unittest.TestCase):
    def test_if_roscore_available(self):
        try:
            rosgraph.Master('/rostopic').getPid()
        except socket.error:
            self.assertFalse(True, "Unable to contact roscore.")

if __name__ == '__main__':
    import rostest
    rostest.rosrun(PKG, 'test_roscore', TestRoscore)
