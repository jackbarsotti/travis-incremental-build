#! /bin/bash
# Provide basic information about the current build type
echo
echo "Travis event type: $TRAVIS_EVENT_TYPE"
echo "Current branch: $TRAVIS_BRANCH"
echo
 
# Install sfdx plugins and configure build with sfdx settings
export SFDX_AUTOUPDATE_DISABLE=false
export SFDX_USE_GENERIC_UNIX_KEYCHAIN=true
export SFDX_DOMAIN_RETRY=300
export SFDX_DISABLE_APP_HUB=true
export SFDX_LOG_LEVEL=DEBUG
mkdir sfdx
wget -qO- $URL | tar xJ -C sfdx --strip-components 1
"./sfdx/install"
export PATH=./sfdx/$(pwd):$PATH
sfdx --version
sfdx plugins --core
export UserName=YourUserName
export RepoName=YourRepoName
 
# Authenticate against correct org
if [ "$TRAVIS_BRANCH" == "dev" ]; then
  echo $SFDX_AUTH_URL_DEV>authtravisci.txt;
elif [ "$TRAVIS_BRANCH" == "master" ]; then
  echo $SFDX_AUTH_URL_PROD>authtravisci.txt;
fi;
 
# Set the target environment for force:source:retrieve command
sfdx force:auth:sfdxurl:store -f authtravisci.txt -a targetEnvironment

# Fetch remote branches, stash any changed files before checking out master branch
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git fetch -q
git stash
echo
git checkout master

# Delete the contents of force-app folder before we paste source:retrieve contents into it
rm -rf force-app/main/default/*
echo
echo 'The contents of the force-app directory have been removed.'
echo "Ready to retrieve org metadata to your $TRAVIS_BRANCH branch."
echo

# Retrieve Section: 
echo 'Retrieving files from Salesforce, please wait...'
echo '(Ignore any blank lines printed below during retrieval)'
# Call a function that will echo an empty line every 9 minutes while retrieve is running to prevent build timeouts
function bell() {
  while true; do
    echo -e "\a"
    sleep 540
  done
}
bell &
# Run a source:retrieve to rebuild the contents of the force-app folder
 # If your repo has a /manifest/package.xml file, uncomment line 58 and comment out line 59
 #retrieved_files=$(sudo sfdx force:source:retrieve -u targetEnvironment -x manifest/package.xml) |
retrieved_files=$(sudo sfdx force:source:retrieve -u targetEnvironment -m ApexClass,ApexTrigger) |
while read -r file; do
echo
done
echo
echo "Retrieval complete. Ready to update the remote repository."
echo
echo 'Here are the retrieved contents of your rebuilt force-app directory:'
ls /home/travis/build/$UserName/$RepoName/force-app/main/default
echo
echo "Now adding and committing these changes to your current branch..."

# git add the changes only in the force-app directory
git config --global user.email "travis@travis-ci.org"
git config --global user.name "Travis CI"
git add force-app/.

# git commit -m "auto-build" changes
echo
echo 'Running: git commit -m "auto-build"'
git commit -q -m "auto-build"
echo "New commit made: $(git log -1 --oneline)" 
echo
echo "All metadata files have been retrieved, and the changes have been commited to your current branch."
echo 'Run "git pull" on your local machine to locally rebuild your branch.'
echo
echo "Build complete!"
echo

# git push 
git remote add origin-master https://${GH_TOKEN}@github.com/$UserName/$RepoName.git > /dev/null 2>&1
git push --quiet --set-upstream origin-master master
