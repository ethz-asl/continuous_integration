#!/usr/bin/env python

import commands

CheckEnvVariable = 'TEST_DEPENDENCIES'

def rev_parse(folder, revision):
  return commands.getstatusoutput('git -C %s rev-parse %s' % (folder, revision))[1].strip();
