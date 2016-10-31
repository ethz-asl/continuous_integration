# test for grep BUG 
if ! echo "ab" | grep -qxf <(echo -e "a\nab"); then
  echo "Your grep ($(grep -V | head -1)) has a bug when using "-xf":" >&2
  echo "It is probably this BUG http://stackoverflow.com/questions/16819432/reading-grep-patterns-from-a-file-with-x-exact-line-match-does-pattern." >&2 
  echo -e "Possible solutions:\n\t1. brew install homebrew/dupes/grep and make sure that the installed ggrep gets found as grep.\n\t2. upgrade the Mac OSX beyond 1.8 (not tested)" >&2
fi
