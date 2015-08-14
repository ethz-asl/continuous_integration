IFS=';' read -ra all_dep_parts <<< "$dependency_w_branch"
dependency=${all_dep_parts[0]}
branch=${all_dep_parts[1]}

if [ -z "$branch" ]; then
  branch="master"
fi

commit=""
if [[ "$branch" =~ ^(.*)(-[0-9]{1,}-g([a-f0-9]{4,}))$ ]]; then
  commit=${BASH_REMATCH[3]}
elif [[ "$branch" =~ ^([a-f0-9]{4,})$ ]]; then
  commit=${BASH_REMATCH[1]}
fi
if [ -n "$commit" ]; then
  # we have to fetch everything as fetching specific commits is not allowed and we don't know the branch!
  branch=""
  depth=""
  clone_args=""
  revision=$commit
else
  # we can fetch a single branch's head!
  depth=1
  clone_args="-b $branch --single-branch"
  revision=origin/$branch
fi

echo "Dependency: $dependency"
echo "Revision: $revision"

if [ -n "$depth" ] ; then
  echo "Depth: $depth"
  depth_args="--depth $depth"
else
  depth_args=""
fi

foldername_w_ext=${dependency##*/}
foldername=${foldername_w_ext%.*}
echo "Foldername: $foldername"
