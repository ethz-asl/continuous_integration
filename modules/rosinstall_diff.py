#!/usr/bin/env python

from __future__ import print_function

import sys
import yaml
from os.path import isdir, samefile

import re

dotGitSuffix = re.compile(".git$")


def normalizeGithubUrls(uri):
  return dotGitSuffix.sub("", uri)


def readRosinstallFile(fileName):
  with open(fileName) as f:
    # use safe_load instead load
    data = yaml.safe_load(f)
    return data if data is not None else []


class Entry():
  def __init__(self, entry):
    keys = entry.keys()
    assert len(keys) == 1
    self.vcs = keys[0]
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
        else:  # local file?
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

  def compare_ssh_vs_https(self, other):
    if isinstance(other, self.__class__):
      normalized_self_uri = normalizeGithubUrls(self.uri)
      normalized_other_uri = normalizeGithubUrls(other.uri)
      are_same = normalized_self_uri.split("github.com")[1][1:] == normalized_other_uri.split("github.com")[1][1:]
      ssh_entry = ""
      https_entry = ""
      if self.uri.split("github.com")[0] == "git@" and other.uri.split("github.com")[0] == "https://":
        ssh_entry = self.uri
        https_entry = other.uri
      elif other.uri.split("github.com")[0] == "git@" and self.uri.split("github.com")[0] == "https://":
        ssh_entry = other.uri
        https_entry = self.uri
      else:
        print("ERROR: One of the entries of {} is not a valid github repo. Local repos are not supported here. First uri: {}, \nsecond uri: {}".format(self.local_name, self.uri, other.uri))
        return sys.exit(-1)
      return ssh_entry, https_entry, are_same
    else:
      return NotImplemented


if __name__ == "__main__":
  baseFile = sys.argv[1]
  updateFile = sys.argv[2]

  baseRosinstallData = readRosinstallFile(baseFile) if baseFile != "NONE" else []
  baseEntries = [Entry(e) for e in baseRosinstallData]
  baseMap = {e.getId(): e for e in baseEntries}

  errorCout = 0
  if updateFile[-1] == "/":
    from os import listdir
    from os.path import join
    if not isdir(updateFile):
      print("ERROR : %s is no directory)" % (updateFile), file=sys.stderr)
      sys.exit(3)

    for f in listdir(updateFile):
      if f and f[0] != '.' and isdir(join(updateFile, f)) and f not in baseMap:
        print(f)
  else:
    updateFileData = readRosinstallFile(updateFile) if updateFile != "LOCAL" else []
    updateEntries = [Entry(e) for e in updateFileData]

    for ue in updateEntries:
      if ue.getId() in baseMap:
        old = baseMap[ue.getId()]
        if not old == ue:
          ssh_entry, https_entry, same_but_ssh_vs_https = old.compare_ssh_vs_https(ue)
          if same_but_ssh_vs_https:
            print("WARNING: {} : {} differs from former {} : {} (using {})".format(updateFile, ue, baseFile, old, old))
          else:
            print("ERROR : %s : %s differs from former %s : %s (different versions / URIs for the same local-name are not supported)" % (updateFile, ue, baseFile, old), file = sys.stderr)
            errorCout += 1
      else:
        print(ue.getId())

  if errorCout:
    sys.exit(-1)
