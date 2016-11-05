#!/usr/bin/env python

import unittest
from os import environ
import os.path
from subprocess import call

class TestPublicArtifact(unittest.TestCase):
    def test_public_artifact(self):
        artifactDir = '../../public_artifacts';
        if not os.path.exists(artifactDir): os.mkdir(artifactDir);
        ret = call(["convert", "-font", "helvetica", "-fill", "green", '-pointsize', '30', "-draw", 'text 20,225 "Job %s artifact"' % environ['BUILD_NUMBER'], 'jenkins.png', os.path.join(artifactDir, 'jenkins-artifact.png')]);
        self.assertEqual(ret, 0)

if __name__ == '__main__':
    unittest.main()
