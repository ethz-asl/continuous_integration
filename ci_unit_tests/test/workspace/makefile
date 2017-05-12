ARCHIVE=../test_repos.tar.bzip2
extract_test_repos:
	-tar --keep-newer-files -xjf $(ARCHIVE)  2>&1 | grep -Fv 'is newer or same age'

update_test_repos:
	tar -cvjf $(ARCHIVE) test_repos
