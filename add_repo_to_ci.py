#!/usr/bin/env python
import getpass
from github import Github, GithubException, BadCredentialsException
import sys, traceback

# Define organization and team-id to which all repositories should be added.
organization_name = "ethz-asl"
ci_team_id = 594582

while True:
  github_username = raw_input("Github username: ")
  github_password = getpass.getpass()
  try:
    g = Github(github_username, github_password)
    status = g.get_api_status()
    print 'API status: ', status.status 
    user_info = g.get_user(github_username)
    print 'Logged in as: ', user_info.name 
    break;
  except Exception:
    print 'Github error: Bad credentials.'

try:
  ethzasl_org = g.get_organization(organization_name)
except Exception:
  print "Github error: the organization: ", organization_name, \
        " does not exist or you are missing permission."
  sys.exit(0)

try:
  ci_team = ethzasl_org.get_team(ci_team_id)
except Exception:
  print "Github error: The team ", ci_team_id, " is unknown or ", \
        "you are missing permission."
  sys.exit(0)

print "We have ", ethzasl_org.owned_private_repos, \
      " repositories to check."
for repo in ethzasl_org.get_repos():
  check_message = "Checking: ", repo.name, " "
  if not ci_team.has_in_repos(repo):
    ci_team.add_to_repos(repo)
    print check_message, "added."
  else:
    print check_message, "exists."

print "done."
