#!/usr/bin/env python
import unittest
import sys
import os
import subprocess

import testTools

class TestPackage(unittest.TestCase):
    def checkDependency(self, folder, sha1):
        print "Checking dependency revision: folder=%s, sha1=%s." %(folder, sha1)
        self.assertEqual(testTools.rev_parse(folder, 'HEAD'), sha1, "Dependency folder %s is not checked out with revision %s" % (folder, sha1))

    def test_external_check(self):
        toEval = os.environ['TEST_DEPENDENCIES'];
        print "ToEval:" + toEval;
        eval(toEval)

if __name__ == '__main__':
    unittest.main()
