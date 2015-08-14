#!/usr/bin/env python
import unittest
import sys
import subprocess
import os
import inspect
import re

TestDir = os.getcwd()
Workspace = TestDir + '/workspace';
sys.path.append(TestDir)

env=os.environ

xunitPath=None
for arg in sys.argv :
    if arg.startswith('--xunit-file=') :
        xunitPath=os.path.dirname(arg.split('=',2)[1]);

class TestCi(unittest.TestCase):
    def _exec(self, args, stdout = None, env = None, cwd = None):
        retCode = subprocess.call(args, stdout=stdout, env = env, cwd=cwd)
        self.assertEqual(retCode, 0, "The return code of %s should be zero!" % str(args))
        

    def _testRunBuild(self, arguments):
        args = ['../../../run_build_impl.sh'];
        args.extend(arguments)
        env['WORKSPACE'] = Workspace
        self._exec(args, cwd = Workspace, env = env);

    def _test_dependencies(self, revisions):
        import workspace.src.test_package.testTools as testTools
        for revision in revisions :
            rep = 'continuous_integration';
            dependencies = 'git@github.com:ethz-asl/%s.git;%s' % (rep, revision);
            
            sha1 = testTools.rev_parse('.', ('' if re.match('^[0-9a-f]+$',revision)  else 'origin/') + revision);
            
            env[testTools.CheckEnvVariable] = "self.checkDependency('../../src/dependencies/%s', '%s')" % (rep, sha1);
            self._testRunBuild(['--dependencies=%s' % dependencies,  '--packages=test_package', '-s', '-n'])
            if xunitPath:
                print 'xunitPath', xunitPath
                self._exec(['mv', Workspace + '/test_results/test_package/nosetests-TestPackage.py.xml', str(os.path.join(xunitPath, inspect.stack()[1][3] + '.xml'))]);

    def test_simpleBranchName(self):
        self._test_dependencies(['test_dependencies/0']);

if __name__ == '__main__':
    unittest.main()
