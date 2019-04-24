#!/usr/bin/env python

from __future__ import print_function

import sys
import yaml
from os.path import isdir, samefile
from operator import __eq__

import re

dotGitSuffix = re.compile(".git$")
githubSshUri = re.compile(r"^git@github.com:")

def normalizeGithubUrls(uri):
  return githubSshUri.sub("https://github.com/", dotGitSuffix.sub("", uri))

def readRosinstallFile(fileName):
  with open(fileName) as f:
    # use safe_load instead load
    data = yaml.safe_load(f)
    return data if data is not None else []

class Entry():
  def __init__(self, entry):
    keys = entry.keys()
    assert len(keys) == 1
    self.vcs = keys[0];
    props = entry[self.vcs]
    self.local_name = props['local-name']
    self.version = props['version'] if props.has_key('version') else None
    self.uri = props['uri']
    
  def __eq__(self, other):
    if isinstance(other, self.__class__):
      if self.uri != other.uri:
        if "github.com" in self.uri and "github.com" in other.uri:
          if normalizeGithubUrls(self.uri) == normalizeGithubUrls(other.uri):
            return self.version == other.version
        if ":" in self.uri + other.uri:
          return False
        else : # local file?
          if not samefile(self.uri, other.uri):
            return False
      return self.local_name == other.local_name and self.version == other.version
    else:
      return NotImplemented

  def __ne__(self, other):
      return not self.__eq__(other)

  def getId(self):
    return self.local_name

  def __str__(self):
    return self.local_name + "(%s, %s)" % (self.uri, self.version)


if __name__ == "__main__":
  baseFile = sys.argv[1]
  updateFile = sys.argv[2]
  
  baseRosinstallData = readRosinstallFile(baseFile) if baseFile != "NONE" else []
  baseEntries = [Entry(e) for e in baseRosinstallData]
  baseMap={ e.getId() : e for e in baseEntries }
  
  errorCout = 0
  if updateFile[-1] == "/":
    from os import listdir
    from os.path import isdir, join
    if not isdir(updateFile):
      print ("ERROR : %s is no directory)" % (updateFile), file = sys.stderr)
      sys.exit(3)
  
    for f in listdir(updateFile):
      if f and f[0] != '.' and isdir(join(updateFile, f)) and not baseMap.has_key(f):
        print(f)
  else:
    updateFileData = readRosinstallFile(updateFile) if updateFile != "LOCAL" else []
    updateEntries = [Entry(e) for e in updateFileData]
    
    for ue in updateEntries:
      if baseMap.has_key(ue.getId()):
        old = baseMap[ue.getId()]
        if not old == ue:
          print ("ERROR : %s : %s differs from former %s : %s (different versions / URIs for the same local-name are not supported)" % (updateFile, ue, baseFile, old), file = sys.stderr)
          errorCout+=1
      else:
        print(ue.getId())
  
  if errorCout:
    sys.exit(-1)
