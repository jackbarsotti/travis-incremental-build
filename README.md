# travis-incremental-build

Concept:

This build is a continuous integration pipeline to validate, test, and move code in an automated fashion. It allows you to use a customizable git-branch-to-salesforce-org pairing concept to make changes to files in your local repository and incrementally deploy those changes to the correct salesforce org. It also configures endpoints to automatically query code from Salesforce and update branches through commits on a scheduled basis.

Prerequisites:

This build configuration requires the following:
  - Install Git on your machine
  - Basic understanding of git commits and git branching
    - See basic git tutorial or in-depth git tutorial
  - Familiarity with Linux Command Line Basics 
  - Travis CI account 
    - Link account with GitHub (skip section creating .travis.yml file)
    - Install Travis CI CLI
      - If you’re using macOS, you might need to run the installation commands preceded by sudo (sudo gem install travis --no-document) 
  - Salesforce account (Create 2 orgs for this build ex: development and production orgs)
    - Install and understand basic Salesforce CLI commands
  - Visual Studio Code app
    - Salesforce CLI Integration
    - Salesforce Package.xml Generator Extension for VS Code

Once you’ve completed the prerequisites above, it’s time to get started with creating your build! This example clones the sfdx-travisci repository from GitHub, but adjust this approach as needed. 

Setup the GitHub Repository:
  - Open the sfdx-travisci repository on GitHub
  - Clone or fork the repo

Activate the Repo in Travis CI:
  - Make a Travis CI account and link it to GitHub. Travis will take you through the process quickly.
  - Login to Travis CI
  - Click the profile picture to go to settings
  - Find your repo under "Legacy Services Integration" and make sure your repo is turned on

Travis + Salesforce Authentication:
  - Open VS Code
  - Checkout each branch that you plan to authorize. You should start on master to authorize a production org.
  - Run: CMD + Shift + P, Authorize an Org, choose org type
  - Repeat steps 2-3 to authorize one org for each Salesforce sandbox or org (for this ex: authorize a Prod org/sandbox)

Display Org Aliases and Login URLs:
  - List org alias 
    - Enter command: sfdx force:alias:list
  - Display verbose Org info to find the sfdx auth url for your prod org
    - Enter command: sfdx force:org:display -u <ProdAliasHere> --verbose 
    - Find the “Sfdx Auth Url”
    - Copy and paste the url into a note or text document
    - IF you want to repeat this process for more branches with corresponding orgs:
      - Checkout the next branch
      - Repeat this section for each remaining org
  
Set Up Travis + Salesforce Authentication:
  - Go back to Travis and open your repo, click More options > Settings
  - Under “Environment Variables”, we will add one secure environment variable per org to authenticate against Salesforce
  - In the “Name” textbox, enter SFDX_AUTH_URL_PROD
  - In the “Value” textbox, paste the Sfdx Auth Url for your production org (you stored this value earlier)
  - If you forgot what this value is, run: sfdx force:org:display -u <YourAliasHere> --verbose
  - Leave the “Branch” textbox set to “All Branches”
  - Leave the checkbox “Display Value In Build Log box” unchecked
  - Click add
  - Repeat the above steps for each org, and change the variable name for each org accordingly
  
Configure the Travis Build Files:
  - .travis.yml file:
    - Go back to VS Code, and file > open the sfdx-travisci repo from your local machine
    - In the left-hand menu, open the .travis.yml file
    - Note: if you’re repo doesn’t yet have this file, cd into your repo and run: 
      - touch .travis.yml
    - Delete the contents of the file, and paste the contents of the travisyml.txt file into .travis.yml. You can find the .txt file within this repo
    - Now, the .yml file includes references to two shell scripts (deploy.sh and retrieve.sh), which we now need to create
  - Configure Shell Script Files:
    - From VS Code, make sure your current directory is sfdx-travisci
    - Create two shell script files using the commands:
      - touch deploy.sh
      - touch retrieve.sh
    - Open each file
    - Paste the contents of the deploy.sh file from this repo into deploy.sh
    - Paste the contents of the retrieve.sh file from this repo into retrieve.sh
    - You will need to comb through both shell scripts and find the following variables:
      - “UserName” (line 25 in deploy.sh, line 20 in retrieve.sh)
      - “RepoName” (line 26 in deploy.sh, line 21 in retrieve.sh)
    - You need to make one more change to your retrieve.sh script. Find lines 57-59 of retrieve.sh. Follow the instructions on these lines, and make any necessary adjustments
    - Insert your username and repo name into their corresponding variables (UserName and RepoName). These variables will be called throughout the script.
    - Save changes

Prepare for Build Kick-off:
  - Create Branch for Each Org
    - You should have already created necessary branches when you authorized an org. If not, create a new branch from the default master branch:
      - git checkout -b yourBranch
    - Go back to this step and authorize a Salesforce org for each branch before continuing.
  - Make Changes and Deploy to Salesforce
    - For this tutorial, we're sticking with two branches: master and dev, and we'll be making changes to the dev branch and deploying them to our dev org. In real life, you're likely to have multiple branches - at least one for each stage of the production lifecycle (development, quality assurance, staging, and production).
    - You should be checked out on your dev branch
    - NOTE: If you haven't cloned the sfdx-travisci repo, your repo needs to have a force-app/main/default directory and include .class and .class-meta.xml files within the default folder to continue.
    - Add some comments to a few of your repo's .class files under the force-app/main/default directory:, save changes
    - git add . 
    - git commit -m “first commit”
    - git push
    - Head over to Travis CI and watch the build run!
    - Login to your Salesforce org and check the deployment status
    - Congratulations, the incremental deployment build is complete!

Schedule Daily Query from Salesforce:

Now that the deployment half of our build is configured, we are going to schedule a Travis cron job to automatically query all metadata from our prod and dev orgs to rebuild the master branch.

  - Create GitHub Token
    - We need to add an environment variable to allow us to push to GitHub automatically:
    - Login to GitHub
    - Navigate to Settings > Developer Settings > Personal access tokens > Generate new token
    - Check the “public repo” scope
    - Click Generate Token
    - Copy to clipboard
  - Create Travis Environment Variable
    - Go back to Travis
    - Scroll to “Environment Variables” 
    - In the “Name” textbox, enter GH_TOKEN
    - In the “Value” textbox, paste the new GitHub token you just created
    - Leave the “Branch” textbox set to “All Branches”
    - Leave the checkbox “Display Value In Build Log box” unchecked
    - Click add
  - Configure Cron Jobs
    - Navigate to the Travis CI settings
    - Scroll down until you see “Cron Jobs”
    - Add a daily cron job set to “Always run” for master (prod) branch and dev (development) branch
      - NOTE: These cron jobs can only run correctly if you’ve walked through my Salesforce Authentication tutorial first

Congratulations, now every 24 hours your prod branch will be automatically rebuilt with any new changes from the master and dev Salesforce orgs!




