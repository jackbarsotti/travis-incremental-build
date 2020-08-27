#! /bin/bash
# Provide basic information about the current build type
echo 
echo "Travis event type: $TRAVIS_EVENT_TYPE"
if [ "$TRAVIS_EVENT_TYPE" == "pull_request" ]; then
  echo "Travis pull request branch: $TRAVIS_PULL_REQUEST_BRANCH"
fi;
echo

# Install sfdx plugins and configure build with sfdx settings
export SFDX_AUTOUPDATE_DISABLE=false
export SFDX_USE_GENERIC_UNIX_KEYCHAIN=true
export SFDX_DOMAIN_RETRY=300
export SFDX_DISABLE_APP_HUB=true
export SFDX_LOG_LEVEL=DEBUG
echo 'mkdir sfdx...'
mkdir sfdx
wget -qO- $URL | tar xJ -C sfdx --strip-components 1
"./sfdx/install"
export PATH=./sfdx/$(pwd):$PATH
sfdx --version
sfdx plugins --core

# Create temporary diff folder (deploy directory) to paste files into later for incremental deployment
sudo mkdir -p /Users/UserName/RepoName/force-app/main/default/diff

# Pull our local branches so they exist locally
# We are on a detached head, so we keep track of where Travis puts us
echo
echo 'Running: export build_head=$(git rev-parse HEAD)'
export build_head=$(git rev-parse HEAD)
echo "Build head: $build_head"

# Overwrite remote.origin.fetch to fetch the remote branches (overrides Travis's --depth clone)
git config --replace-all remote.origin.fetch +refs/heads/*:refs/remotes/origin/*
echo
echo 'Running a git fetch...'
git fetch -q
echo 'Remote: Enumerating, counting, compressing objects...'
echo 'Fetching remote branches from github...'
echo 'Done.'

# Create variables for frequently-referenced file paths and branches
export BRANCH=$TRAVIS_BRANCH
export branch=$TRAVIS_BRANCH
echo "Travis branch: $TRAVIS_BRANCH" 
echo
export userPath=/Users/UserName/RepoName/force-app/main/default
export diffPath=/diff/force-app/main/default
# For a full build, deploy directory should be "- export DEPLOYDIR=force-app/main/default":
export DEPLOYDIR=/Users/UserName/RepoName/force-app/main/default/diff
export classPath=force-app/main/default/classes
export triggerPath=force-app/main/default/triggers

# Ensure that "inexact rename detection" error isn't skipped due to too many files
git config --global diff.renameLimit 9999999

# Git Diff Section:
# Duplicate this if-statement (lines 63-106) per branch that you need to run a deployment build from. This example has only one, dev.
# Run a git diff for the incremental build depending on checked-out branch 

# dev branch:
if [ "$BRANCH" == "dev" ]; then
  echo 'Preparing for an incremental deployment to org...'
  for branch in $(git branch -r|grep -v HEAD); do
    #create tracking branch:
    git checkout -qf ${branch#origin/}
  done;
  git checkout LEX
  echo
  echo 'Running a git diff, please wait...'
  # Run a git diff only for files with the U, M, or A status (can be seen with git diff --name-status):
  git diff --diff-filter=UMA --name-only master force-app/ |
  while read -r file; do
    # Copy the files from git diff into the deploy directory:
    sudo cp --parents "$file" $DEPLOYDIR 2>/dev/null
    # For any changed class, trigger, page file, it's associated meta data file is copied to the deploy directory (and vice versa):
    if [[ $file == *.cls ]]; then
      find $classPath -samefile "$file-meta.xml" -exec sudo cp --parents -t $DEPLOYDIR {} \;
    elif [[ $file == *.cls-meta.xml ]]; then
      parsedfile=${file%.cls-meta.xml}
      find $classPath -samefile "$parsedfile.cls" -exec sudo cp --parents -t $DEPLOYDIR {} \;
    elif [[ $file == *Test.cls ]]; then
      find $classPath -samefile "$file-meta.xml" -exec sudo cp --parents -t $DEPLOYDIR {} \;
    elif [[ $file == *Test.cls-meta.xml ]]; then
      parsedfile=${file%.cls-meta.xml}
      find $classPath -samefile "$parsedfile.cls" -exec sudo cp --parents -t $DEPLOYDIR {} \;
    elif [[ $file == *.trigger ]]; then
      find $triggerPath -samefile "$file-meta.xml" -exec sudo cp --parents -t $DEPLOYDIR {} \;
    elif [[ $file == *.trigger-meta.xml ]]; then
      parsedfile=${file%.trigger-meta.xml}
      find $triggerPath -samefile "$parsedfile.trigger" -exec sudo cp --parents -t $DEPLOYDIR {} \;
    elif [[ $file == *.page ]]; then
      find force-app/main/default/pages -samefile "$file-meta.xml" -exec sudo cp --parents -t $DEPLOYDIR {} \;
    elif [[ $file == *.page-meta.xml ]]; then
      parsedfile=${file%.page-meta.xml}
      find force-app/main/default/pages -samefile "$parsedfile.page" -exec sudo cp --parents -t $DEPLOYDIR {} \;
    fi
  done 
  echo 'Complete.'
  echo
  echo 'Deployment directory includes:'
  echo
  ls $DEPLOYDIR/force-app/main/default
  echo
fi;

# File Parse Section:
# Make temporary folder for our <className>Test.cls files that will be parsed
sudo mkdir -p /Users/UserName/RepoName/force-app/main/default/unparsedTests
export unparsedTestsDir=/Users/UserName/RepoName/force-app/main/default/unparsedTests
# Search the local "classes" folder for <className>Test.cls files
export classTests=$(find $classPath -name "*Test.cls")
# Parse the <className>Test.cls filenames to remove each file's path and ".cls" ending, result: <className>Test
# Exports as a string that will be called in the deploy command in script phase IF branch is LEX
export parsedList=''
for testfiles in $classTests; do
  sudo cp "$testfiles"* $unparsedTestsDir;
  export parsed=$(find $unparsedTestsDir -name "*Test.cls");
  export parsed=${parsed##*/};
  export parsed=${parsed%.cls*};
  export parsedList="${parsedList}${parsed},";
done; 

# Finally, go back to the HEAD from earlier
git config advice.detachedHead false
echo 
echo 'Running: git checkout $build_head'
git checkout $build_head

# Salesforce Authentication Section
# If you duplicated the above git diff section (lines 63-106) for other branches in your repo, do the same below (for lines 133-144)
if [ "$BRANCH" == "dev" ]; then
  # Automatically authenticate against current branch's corresponding SalesForce org:
  echo $SFDX_AUTH_URL_LEX>authtravisci.txt;
  # Only validate, not deploy, when a pull request is being created:
  if [ "$TRAVIS_EVENT_TYPE" == "pull_request" ]; then
    # Create deployment variable for "sfdx:force:source:deploy RunSpecifiedTests -r <variable>":
    export TESTLEVEL="RunSpecifiedTests -r $parsedList -c";
  else
    # When a pull request is MERGED, deploy it:
    export TESTLEVEL="RunSpecifiedTests -r $parsedList";
  fi;
fi;
# Store our auth-url for our targetEnvironment alias for deployment
sfdx force:auth:sfdxurl:store -f authtravisci.txt -a targetEnvironment

# Deployment Section:
# Run apex tests and deploy apex classes/triggers
sudo sfdx force:org:display -u targetEnvironment
echo
echo 'Running force:source:deploy. Large deployments could take 25 minutes or more to finish.'
echo 'Please wait...'
echo '(Ignore any blank lines printed below "Job ID" line during deployment)'
# Echo one empty line per 9 minute interval that deployment takes to prevent Travis build timeouts at 10 minutes 
function bell() {
  while true; do
    echo -e "\a"
    sleep 540
  done
}
bell &
# Deploy to Salesforce
sudo sfdx force:source:deploy -w 45 -p $DEPLOYDIR -l $TESTLEVEL -u targetEnvironment
echo
echo 'Build complete. Check ORG deployment status page for details.'
