#!/usr/bin/env python
import unittest
import sys
import subprocess
import os
import inspect
import re

TestDir = os.getcwd()
sys.path.append(TestDir)

Workspace = TestDir + '/workspace';
RedirectedWorkspace = '/tmp/ci_unit_tests/workspace';

env=os.environ
env.pop('rosinstall_file', None)

xunitPath=None
for arg in sys.argv :
    if arg.startswith('--xunit-file=') :
        xunitPath=os.path.dirname(arg.split('=',2)[1]);

class TestCi(unittest.TestCase):
    def __init__(self, name):
        unittest.TestCase.__init__(self, name)
        # this is necessary because catkin does not support nested workspaces!
        print "Cloning the test workspace into %s" % RedirectedWorkspace
        self._exec(['rm', '-f', RedirectedWorkspace], ignoreResult = True) # remove the old symbolic link, if still there
        self._exec(['mkdir', '-vp', RedirectedWorkspace])
        self._exec(['cp', '-av', Workspace + "/src", RedirectedWorkspace])

    def _exec(self, args, stdout = None, env = None, cwd = None, ignoreResult = False):
        print "Executing " + str(args)
        retCode = subprocess.call(args, stdout=stdout, env = env, cwd=cwd)
        if not ignoreResult:
            self.assertEqual(retCode, 0, "The return code of %s should be zero!" % str(args))
        
    def runTestShellScriptAndAssertEqualOutput(self, script):
        outDir = 'expected/'
        
        outputPath = outDir + script + '.out';
        
        outputFd = os.open(outputPath, os.O_TRUNC | os.O_CREAT | os.O_WRONLY);
        self._exec(['./' + script + ".sh"], stdout=outputFd)
        os.close(outputFd);
        
        pipe = os.popen('git diff '+ outputPath + ' 2>&1')
        c = 0
        for l in pipe:
            print l.strip()
            c += 1
        self.assertEqual(c, 0, "There should be no difference between HEAD and the expected output %s! Either fix the code or commit changed expected output." % outputPath)

    def test_parse_dependency(self):
        self.runTestShellScriptAndAssertEqualOutput('test_parse_dependency')


    def _testRunBuild(self, arguments):
        args = [TestDir + '/../../run_build_impl.sh'];
        args.extend(arguments)
        env['WORKSPACE'] = RedirectedWorkspace # this is necessary because catkin does not support nested workspaces!
        self._exec(args, cwd = RedirectedWorkspace, env = env);

    def _test_dependencies(self, revisions):
        import workspace.src.test_package.testTools as testTools
        for revision in revisions :
            rep = 'continuous_integration';
            if type(revision) in (tuple, list) :
                dependencies, sha1 = revision
            else:
                dependencies = 'git@github.com:ethz-asl/%s.git;%s' % (rep, revision);
                sha1 = testTools.rev_parse('.', ('' if re.match('^[0-9a-f]+$',revision)  else 'origin/') + revision);
            
            env[testTools.CheckEnvVariable] = "self.checkDependency('../../src/dependencies/%s', '%s')" % (rep, sha1);
            self._testRunBuild(['--dependencies=%s' % dependencies,  '--packages=test_package', '-s', '-n'])
            if xunitPath:
                self._exec(['mv', RedirectedWorkspace + '/test_results/test_package/nosetests-TestPackage.py.xml', str(os.path.join(xunitPath, inspect.stack()[1][3] + '.xml'))]);

    def test_simpleBranchName(self):
        self._test_dependencies(['test_dependencies/0']);

    def test_simpleSHA1(self):
        self._test_dependencies(['0295dad96441fd2b9227caa5dbd2edfc5d438718', '0295dad96441']);
        
    def test_simpleGitDescribeLikeRevision(self):
        self._test_dependencies(['notExistingTagOrBranch-32-g0295dad964']);

    def test_localRosInstallFile(self):
        self._test_dependencies([['./test_package/local.rosinstall', '0295dad96441fd2b9227caa5dbd2edfc5d438718']]);

if __name__ == '__main__':
    unittest.main()
