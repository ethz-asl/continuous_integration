#!/usr/bin/env python
import unittest
import sys
import os
import subprocess

import testTools

def sha1Equal(a, b):
    a = a.strip();
    b = b.strip();
    return len(a) >= 5 and len(a) >= 5 and b.startswith(a) or a.startswith(b)

class TestPackage(unittest.TestCase):
    def checkDependency(self, folder, sha1):
        print "Checking dependency revision: folder=%s, sha1=%s." %(folder, sha1)
        actualSha1 = testTools.rev_parse(folder, 'HEAD');
        self.assertTrue(sha1Equal(actualSha1, sha1), "Dependency folder %s is not checked out with revision %s. Instead it is %s" % (folder, sha1, actualSha1))

    def test_external_check(self):
        toEval = os.environ[testTools.CheckEnvVariable];
        print "ToEval:" + toEval;
        eval(toEval)

if __name__ == '__main__':
    unittest.main()
