#!/bin/sh
#######################################################################
# FILE AUTO GENERATED BY https://github.com/gutro/leo-base-repo-files #
#######################################################################

JOB=0
ERROR=0
ERRORS=""

RUN_ALL="false"
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

removeTags=()
branches=()
prefix="origin/"

function coloredEcho {
  printf "# $1 $2 ${NC}\n"
}

function displayError {
  ERROR=$((ERROR+1))
  ERRORS+="$2\n"
  coloredEcho "$1" "$2"

  if [[ $BRANCH == "master" ]];
  then
    { set +x ;
      separatorEcho ;
      coloredEcho ${RED} "-----------------------------------------" ;
      coloredEcho ${RED} "\`master\` build failed, no build published" ;
      coloredEcho ${RED} "-----------------------------------------" ;
      separatorEcho
      coloredEcho ${RED} ${ERRORS}
      coloredEcho ${RED} "-----------------------------------------" ;
      separatorEcho ;
      set -x ;
    }
    exit 1;
  fi
}

function separatorEcho {
  coloredEcho ${CYAN} "-----------------------------------------"
}

set -e
set -x

function gatherFacts {
  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Gathering facts" ; set -x ; }

  [ -n "$BASE_DIRECTORY" ] || BASE_DIRECTORY=.
  [ -n "$APP_DIRECTORY" ] || APP_DIRECTORY=.
  [ -n "$CHECK_NPM" ] || CHECK_NPM="False"
  SUPPORTS_TAGS=True;

  if [[ -f ".dockerrc" ]]; then . .dockerrc; fi

  COMPONENT=`cat package.json |python -c 'import json,sys;obj=json.load(sys.stdin);print obj.get("name", "").split("/")[-1];'`
  FULL_COMPONENT=`cat package.json |python -c 'import json,sys;obj=json.load(sys.stdin);print obj.get("name", "");'`
  VERSION=`cat package.json |python -c 'import json,sys;obj=json.load(sys.stdin);print obj.get("version", "");'`
  IS_SERVICE=`cat package.json |python -c 'import json,sys;obj=json.load(sys.stdin);print str(obj.get("isService", "False") in ["true", "True", True]);'`
  DEV_DEPENDENCIES_COUNT=`cat package.json |python -c 'import json,sys;obj=json.load(sys.stdin);print len(obj.get("devDependencies", {}));'`
  PROD_DEPENDENCIES_COUNT=`cat package.json |python -c 'import json,sys;obj=json.load(sys.stdin);print len(obj.get("dependencies", {}));'`
  MAINTAINER=`cat package.json |python -c 'import json,sys;obj=json.load(sys.stdin);print obj.get("maintainerTeam", "");'`
  SHORT_NAME=`cat package.json |python -c 'import json,sys;obj=json.load(sys.stdin);print obj.get("shortName", "");'`

  COMMIT=`git rev-parse HEAD`
  GIT_BRANCH=${GIT_BRANCH:-`git rev-parse --abbrev-ref HEAD`}
  BRANCH=`basename $GIT_BRANCH`
  JOB_NAME=${JOB_NAME//_/-};
  GIT_TAG="${JOB_NAME,,}-$BRANCH";
  GIT_TAG_PREPUSH="prepush-$BRANCH"

  # Used for building frontends
  if [[ -n "$APP" && "$APP" != "sport" ]];
  then
    COMPONENT="leo-frontend-${APP}"
    VERSION=`cat apps/$APP/package.json |python -c 'import json,sys;obj=json.load(sys.stdin);print obj.get("version", "");'`
    GIT_TAG="$APP-$BRANCH-$BUILD_NUMBER";
  fi

  NAME="${COMPONENT}_${BRANCH}_${VERSION}-${COMMIT}"

  BRANCH_COMMIT=$(git rev-parse origin/$BRANCH)
  PUBLISH_LATEST="True"

  DOCKER_NPM_IMAGE="gearsofleo/npm"
  DOCKER_IMAGE_NAME="gearsofleo/${COMPONENT}"

  DOCKER_BUILD_COMMIT_PUBLISH="${DOCKER_IMAGE_NAME}:build-${COMMIT}"
  DOCKER_RUNTIME_COMMIT_PUBLISH="${DOCKER_IMAGE_NAME}:${COMMIT}"
  DOCKER_RUNTIME_LATEST_PUBLISH="${DOCKER_IMAGE_NAME}:${BRANCH}-latest"

  export RUNTIME_IMAGE=${DOCKER_RUNTIME_COMMIT_PUBLISH}
  export BUILD_IMAGE=${DOCKER_BUILD_COMMIT_PUBLISH}
}

function createConfigFiles {
  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Create .npmrc file" ; set -x ; }

  { set +x ; echo "//registry.npmjs.org/:_authToken=$NPM_TOKEN" > ./.npmrc ; set -x ; }
  echo "progress=false" >> ./.npmrc
  echo "color=true" >> ./.npmrc

  echo ${COMMIT} > COMMIT
  echo ${NAME} > VERSION
}

function getNpmVariables {
  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Getting NPM definitions" ; set -x ; }

  PKG_NAME=`cat package.json | python -c 'import json,sys;obj=json.load(sys.stdin);print obj.get("name", "");'`
  PUB_VERSION=`npm show ${PKG_NAME} version --loglevel silent; true`
  IS_PRIVATE=`cat package.json | python -c 'import json,sys;obj=json.load(sys.stdin);print obj.get("private", "False");'`

  if [[ -d "client" ]] && [[ -f "client/package.json" ]];
  then
    CLIENT_IS_PRIVATE=`cat client/package.json | python -c 'import json,sys;obj=json.load(sys.stdin);print obj.get("private", "False");'`
    PKG_CLIENT_NAME=`cat client/package.json | python -c 'import json,sys;obj=json.load(sys.stdin);print obj.get("name", "");'`
    PUB_CLIENT_VERSION=`npm show ${PKG_CLIENT_NAME} version --loglevel silent; true`
  fi

  if [[ -d "schema" ]] && [[ -f "schema/package.json" ]];
  then
    SCHEMA_PKG_NAME=`cat schema/package.json | python -c 'import json,sys;obj=json.load(sys.stdin);print obj.get("name", "");'`
  fi
}

function checkIsLatest {
  if [[ "$GIT_COMMIT" != "$BRANCH_COMMIT" ]];
  then
    { set +x ; coloredEcho ${YELLOW} "Commit '$GIT_COMMIT' is not latest in branch '$BRANCH', will not publish as latest" ; set -x ; }
    PUBLISH_LATEST="False"
  fi
}

function verifyJira {
  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Executing JIRA checks" ; set -x ; }

  VALID_BRANCH=`python -c "
import re;

if re.match('^(revert-)?([A-Z]{2,}-[0-9]+)_(.*)$', '$BRANCH'):
   print True;
else:
  print False;
  "`

  if [[ $BRANCH != "master" ]];
  then
    { set +x ; coloredEcho ${BLUE} "Verifying branch contains JIRA ID" ; set -x ; }

    JIRA_ID=`python -c "
import re;
match = re.compile('^([A-Z]{2,}-[0-9]+)_(.*)$');
groups = match.search('$BRANCH');

if groups:
  print groups.group(1);
else:
  print 'False';
    "`
    if [[ $BRANCH == "revert"* ]];
    then
      { set +x ; coloredEcho ${YELLOW} "Branch is performing a revert, ignoring JIRA branch check" ; set -x ; }
    else
      if [[ $VALID_BRANCH == "False" ]];
      then
        { set +x ; displayError ${RED} "ERROR: Branch must include the JIRA ID and be in format of \`PROJECT-ID_my-branch-name\`" ; set -x ; }
      else
        { set +x ; coloredEcho ${GREEN} "Branch contains JIRA ID" ; set -x ; }
      fi

      if [[ $JIRA_ID != "False" ]];
      then
        { set +x ; coloredEcho ${BLUE} "Verifying JIRA ticket \"${JIRA_ID}\" actually exists" ; set -x ; }

        JIRA=$(curl -s -u ${JIRA_AUTH} -X GET -H "Content-Type: application/json" https://gutros.atlassian.net/rest/api/latest/issue/${JIRA_ID}?fields=summary)
        VALID_JIRA=`python -c "
body = $JIRA;

try:
  if 'errorMessages' in body:
    print 'False';
  elif 'fields' in body and 'summary' in body['fields']:
    print 'True';
except SyntaxError:
  print 'True';
except:
  print 'False';
    "`
      else
        VALID_JIRA="False"
      fi

      if [[ $VALID_JIRA == "False" ]];
      then
        { set +x ; displayError ${RED} "ERROR: JIRA ID specified in branch name does not seem to exist!" ; set -x ; }
      else
        { set +x ; coloredEcho ${GREEN} "JIRA ID appears to exist" ; set -x ; }
      fi
    fi
  fi

  if [[ $BRANCH == "master" ]];
  then
    { set +x ; coloredEcho ${BLUE} "Checking if JIRA ID is in commit message" ; set -x ; }

    MESSAGE=`git log --format=%B -n 1 $BRANCH_COMMIT`
    MESSAGE_HAS_JIRA=`echo "$MESSAGE" | python -c "
import re,sys;

message = '';
for line in sys.stdin:
  message = message + line;

match = re.compile('([A-Z]{2,}-[0-9]+)');
groups = match.search(message);

if groups:
  print True;
else:
  print False;
"`

    if [[ $MESSAGE_HAS_JIRA == "False" ]];
    then
      { set +x ; displayError ${RED} "ERROR: JIRA ID needs to be at start of the commit message in \`master\` branch" ; set -x ; }
    else
      { set +x ; coloredEcho ${GREEN} "Found a JIRA ID in commit message" ; set -x ; }
    fi
  fi

  if [[ $GIT_URL == *"http"* ]]; then
    SUPPORTS_TAGS=False;
    { set +x ; coloredEcho ${YELLOW} "WARNING: Job uses HTTP git endpoint, needs to be in SSH format, check with #platform-frontend to change properly!" ; set -x ; }
  fi
}

function verifyPrepush {
  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Verifying pre-push" ; set -x ; }

  if [[ "$SUPPORTS_TAGS" == "True" ]];
  then
    { set +x ; coloredEcho ${BLUE} "Fetching tags" ; set -x ; }
    git fetch --tags

    { set +x ; coloredEcho ${BLUE} "Check if git tag '$GIT_TAG' exists" ; set -x ; }
    HAS_GIT_TAG=$(git ls-remote --tags origin | grep "refs/tags/$GIT_TAG$" || git tag | grep $GIT_TAG || echo "")

    if [[ -z "$APP" && $BRANCH != "master" ]];
    then
      { set +x ; coloredEcho ${BLUE} "Verify that pre-push has been run by checking for the pre-push tag: '$GIT_TAG_PREPUSH'" ; set -x ; }
      PREPUSH_COMMIT_ID=$(git rev-list -n 1 refs/tags/$GIT_TAG_PREPUSH || echo "")

      if [[ "$PREPUSH_COMMIT_ID" != "$COMMIT" ]];
      then
        { set +x ; displayError ${RED} "ERROR: Local pre-push.sh has not been run for this commit!" ; set -x ; }
      else
        { set +x ; coloredEcho ${GREEN} "Pre-push verified" ; set -x ; }
      fi
    fi
  fi
}

function verifyPackage {
  getNpmVariables

  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Executing service and client \`package.json\` checks" ; set -x ; }

  if [[ "$COMPONENT" != "leo-boilerplate-service" ]];
  then
    if [[ -z "$MAINTAINER" ]] || [[ "$MAINTAINER" == "unknown" ]];
    then
      { set +x ; displayError ${RED} "ERROR: maintainerTeam in 'package.json' needs to be updated!" ; set -x ; }
    fi

    if [[ -z "$IS_SERVICE" ]];
    then
      { set +x ; displayError ${RED} "ERROR: isService in 'package.json' needs to be set to either true or false" ; set -x ; }
    fi

    if [[ $IS_SERVICE == "True" && -z "$APP" ]];
    then
      if [[ -z "$SHORT_NAME" ]] || [[ "$SHORT_NAME" == "lbs" ]];
      then
        { set +x ; displayError ${RED} "ERROR: shortName in 'package.json' needs to be updated!" ; set -x ; }
      fi

      if ! grep -q CMD Dockerfile;
      then
        { set +x ; displayError ${RED} "ERROR: CMD missing from Dockerfile, remove and & reinstall node_modules!" ; set -x ; }
      fi
    fi
  fi

  if [[ -n "$PUB_VERSION" ]] && [[ "$VERSION" = "$PUB_VERSION" ]];
  then
    { set +x ; displayError ${RED} "ERROR: Version not updated, version in the root package.json needs to be updated!" ; set -x ; }
  fi
  if [[ -d "client" ]] && [[ -f "client/package.json" ]];
  then
    if [[ -n "$PUB_CLIENT_VERSION" ]] && [[ "$VERSION" = "$PUB_CLIENT_VERSION" ]];
    then
      { set +x ; displayError ${RED} "ERROR: Client version not updated, version in the root package.json needs to be updated!" ; set -x ; }
    fi

    if [[ "$COMPONENT" != "leo-boilerplate-service" ]];
    then
      if [[ "$PKG_CLIENT_NAME" != "@leogears/$COMPONENT-client" ]];
      then
        { set +x ; displayError ${RED} "ERROR: Client name in 'client/package.json' needs to be updated to match the service name! (@leogears/$COMPONENT-client)" ; set -x ; }
      fi
    fi
  fi

  if  [[ $BRANCH == "master" ]];
  then
    ROOT_HAS_CANARY=`npm outdated --json |python -c '
import json,sys;
packages=json.load(sys.stdin);

for packageName, versions in packages.iteritems():
  if "@leogears" in packageName and "-" in versions["wanted"]:
   print True;
   break;
print False;
'`

    if [[ "$ROOT_HAS_CANARY" == "True" ]];
    then
      { set +x ; displayError ${RED} "ERROR: Non-published version of module found in root package.json" ; set -x ; }
    fi

    if [[ -d "client" ]] && [[ -f "client/package.json" ]];
    then
      CLIENT_HAS_CANARY=`cd client && npm outdated --json |python -c '
import json,sys;
packages=json.load(sys.stdin);

for packageName, versions in packages.iteritems():
  if "@leogears" in packageName and "-" in versions["wanted"]:
   print True;
   break;
print False;
'`

      if [[ "$CLIENT_HAS_CANARY" == "True" ]];
      then
        { set +x ; displayError ${RED} "ERROR: Non-published version of module found in client package.json" ; set -x ; }
      fi
    fi
  fi

  if [[ "$ERROR" == 0 ]];
  then
    { set +x ; coloredEcho ${GREEN} "\`package.json\` looks good" ; set -x ; }
  fi
}

function verifyDockerHub {
  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Verify docker hub repository" ; set -x ; }
  python ./dockerhub-api.py ${COMPONENT}
  { set +x ; coloredEcho ${GREEN} "Docker hub repository exists" ; set -x ; }
}

function cleanupContainer {
  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Cleaning up after build and removing \"$1\" container" ; set -x ; }
  docker rm -f $1 || true;
  { set +x ; coloredEcho ${GREEN} "Cleaned up running container \"$1\"" ; set -x ; }
}

function pullDockerBuildImage {
  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Pull down docker build image for ${BUILD_IMAGE}" ; set -x ; }
  docker pull ${BUILD_IMAGE}
  { set +x ; coloredEcho ${GREEN} "Pulled build image" ; set -x ; }
}

function pullDockerRuntimeImage {
  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Pull down docker runtime image for ${RUNTIME_IMAGE}" ; set -x ; }
  docker pull ${RUNTIME_IMAGE}
  { set +x ; coloredEcho ${GREEN} "Pulled runtime image" ; set -x ; }
}

function runRuntimeContainer {
  pullDockerRuntimeImage

  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Starting container from runtime image ${RUNTIME_IMAGE}" ; set -x ; }
  CONTAINER_ID=`docker run -it -d ${RUNTIME_IMAGE} /bin/sh`
}

function runBuildContainer {
  pullDockerBuildImage

  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Starting container from build image ${BUILD_IMAGE}" ; set -x ; }
  CONTAINER_ID=`docker run -e CI=true -it -d ${BUILD_IMAGE} /bin/sh`
}

function executeNpmCommand {
  docker exec -t ${CONTAINER_ID} /bin/sh -c "$1"
}

function buildBuilder {
  verifyDockerHub
  createConfigFiles

  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Build docker build container" ; set -x ; }

  { set +x ; coloredEcho ${BLUE} "Purge previous build" ; set -x ; }
  rm -rf ./build

  { set +x ; coloredEcho ${BLUE} "Building Docker image version: ${BUILD_IMAGE}" ; set -x ; }

  docker build -f ./Dockerfile.build \
    --build-arg CI=$CI \
    --build-arg APP_DIRECTORY=$APP_DIRECTORY \
    --build-arg APP=$APP \
    --build-arg BUILD_NUMBER=$BUILD_NUMBER \
    --build-arg GIT_COMMIT=$GIT_COMMIT \
    --build-arg GIT_BRANCH=$BRANCH \
    -t ${BUILD_IMAGE} $BASE_DIRECTORY

  if [ $? -eq 0 ];
  then
    { set +x ; coloredEcho ${GREEN} "Build image built, publishing" ; set -x ; }
    docker push ${BUILD_IMAGE}
    { set +x ; coloredEcho ${GREEN} "Build image published" ; set -x ; }
  else
    { set +x ; displayError ${RED} "ERROR: Failed building build image" ; set -x ; }
  fi
}

function buildRuntime {
  verifyDockerHub
  runBuildContainer

  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Build docker runtime container" ; set -x ; }

  { set +x ; coloredEcho ${BLUE} "Purge previous build" ; set -x ; }
  rm -rf ./build

  # Prune, copy, and rename node_modules from build container to get around the context ignore
  mkdir ./build
  docker cp ${CONTAINER_ID}:/usr/src/app/${APP_DIRECTORY} ./build/service
  mv ./build/service/node_modules ./build/modules
  cp -rf ./Dockerfile ./build/Dockerfile

  # Ensure we have the needed config files
  ( cd ./build; createConfigFiles )

  if ! (cd ./build && docker build -f ./Dockerfile --build-arg APP=$APP -t ${RUNTIME_IMAGE} .);
  then
    { set +x ; displayError ${RED} "ERROR: Failed building runtime image" ; set -x ; }
  else
    if [[ $BRANCH == "master" ]];
    then
      { set +x ; coloredEcho ${GREEN} "Runtime image built" ; set -x ; }
    else
      publishRuntime
    fi
  fi

  cleanupContainer ${CONTAINER_ID}
}

function publishRuntime {
  checkIsLatest

  { set +x ; coloredEcho ${GREEN} "Runtime image built, publishing" ; set -x ; }

  { set +x ; coloredEcho ${BLUE} "Publishing runtime \`commit\` tag" ; set -x ; }
  docker push ${DOCKER_RUNTIME_COMMIT_PUBLISH}
  { set +x ; coloredEcho ${GREEN} "Runtime image published" ; set -x ; }

  if [[ $PUBLISH_LATEST == "True" ]];
  then
    { set +x ; coloredEcho ${BLUE} "Publishing runtime \`latest\` tag" ; set -x ; }
    docker tag ${RUNTIME_IMAGE} ${DOCKER_RUNTIME_LATEST_PUBLISH}
    docker push ${DOCKER_RUNTIME_LATEST_PUBLISH}
  fi
}

function publishPackage {
  getNpmVariables

  checkIsLatest

  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Publish NPM packages" ; set -x ; }

  if [[ $IS_SERVICE == "True" ]];
  then
    runRuntimeContainer
  else
    runBuildContainer
  fi

  if  [[ $BRANCH == "master" && $FORCE != "true" ]];
  then
    if [[ "$IS_PRIVATE" == "False" ]];
    then

      if [[ $PUBLISH_LATEST == "True" ]];
      then
        { set +x ; coloredEcho ${BLUE} "PUBLISH $PKG_NAME@$VERSION to NPM" ; set -x ; }
        executeNpmCommand "npm publish --tag latest --verbose"

        if [[ $CHECK_NPM == "True" ]];
        then
          { set +x ; coloredEcho ${BLUE} "WAIT FOR NPM TO REPLICATE" ; set -x ; }
          executeNpmCommand "npm i wait-for-package-replication@latest -g --quiet && wait-for-package-replication -p $FULL_COMPONENT -v $VERSION --verbose"
        fi
      else
        { set +x ; coloredEcho ${BLUE} "PUBLISH $PKG_NAME@$VERSION to NPM" ; set -x ; }
        executeNpmCommand "npm publish --tag stable"
      fi
    else
      { set +x ; coloredEcho ${YELLOW} "$PKG_NAME set to 'private', skipping NPM publish" ; set -x ; }
    fi

    if [[ -d "client" ]] && [[ -f "client/package.json" ]];
    then
      if [[ "$CLIENT_IS_PRIVATE" == "False" ]];
      then
        if [[ $PUBLISH_LATEST == "True" ]];
        then
          { set +x ; coloredEcho ${BLUE} "PUBLISH $PKG_CLIENT_NAME@$VERSION latest to NPM" ; set -x ; }
          executeNpmCommand "cd client && npm version $VERSION --no-git-tag-version && npm publish --tag latest"

          if [[ $CHECK_NPM == "True" ]];
          then
            { set +x ; coloredEcho ${BLUE} "WAIT FOR NPM TO REPLICATE" ; set -x ; }
            executeNpmCommand "npm i wait-for-package-replication@latest -g --quiet && wait-for-package-replication -p $PKG_CLIENT_NAME -v $VERSION --verbose"
          fi
        else
          { set +x ; coloredEcho ${BLUE} "PUBLISH $PKG_CLIENT_NAME@$VERSION to NPM" ; set -x ; }
          executeNpmCommand "cd client && npm version $VERSION --no-git-tag-version && npm publish --tag stable"
        fi
      else
        { set +x ; coloredEcho ${YELLOW} "$PKG_CLIENT_NAME set to 'private', skipping NPM publish" ; set -x ; }
      fi
    fi

    if [[ -d "schema" ]] && [[ -f "schema/package.json" ]];
    then
      if [[ $PUBLISH_LATEST == "True" ]];
      then
        { set +x ; coloredEcho ${BLUE} "PUBLISH $SCHEMA_PKG_NAME@$VERSION latest to NPM" ; set -x ; }
        executeNpmCommand "cd schema && node saveSchema && npm version $VERSION --no-git-tag-version && npm publish --tag latest"

        if [[ $CHECK_NPM == "True" ]];
        then
          { set +x ; coloredEcho ${BLUE} "WAIT FOR NPM TO REPLICATE" ; set -x ; }
          executeNpmCommand "npm i wait-for-package-replication@latest -g --quiet && wait-for-package-replication -p $SCHEMA_PKG_NAME -v $VERSION --verbose"
        fi
      else
        { set +x ; coloredEcho ${BLUE} "PUBLISH $SCHEMA_PKG_NAME@$VERSION to NPM" ; set -x ; }
        executeNpmCommand "cd schema && node saveSchema && npm version $VERSION --no-git-tag-version && npm publish --tag stable"
      fi
    fi
  elif [[ $FORCE != "true" ]];
  then
    VERSION="${VERSION}-${BUILD_NUMBER}"

    if [[ "$IS_PRIVATE" == "False" ]];
    then
      { set +x ; coloredEcho ${BLUE} "PUBLISH $PKG_NAME@$VERSION to NPM with $BRANCH tag" ; set -x ; }
      executeNpmCommand "npm version $VERSION --no-git-tag-version && npm publish --tag $BRANCH --verbose"

      if [[ $CHECK_NPM == "True" ]];
      then
        { set +x ; coloredEcho ${BLUE} "WAIT FOR NPM TO REPLICATE" ; set -x ; }
        executeNpmCommand "npm i wait-for-package-replication -g --quiet && wait-for-package-replication -p $FULL_COMPONENT -v $VERSION --verbose"
      fi
    else
      { set +x ; coloredEcho ${YELLOW} "$PKG_NAME set to 'private', skipping NPM publish" ; set -x ; }
    fi

    if [[ -d "client" ]] && [[ -f "client/package.json" ]];
    then
      if [[ "$CLIENT_IS_PRIVATE" == "False" ]];
      then
        { set +x ; coloredEcho ${BLUE} "PUBLISH $PKG_CLIENT_NAME@$VERSION to NPM with $BRANCH tag" ; set -x ; }
        executeNpmCommand "cd client && npm version $VERSION --no-git-tag-version && npm publish --tag $BRANCH"

        if [[ $CHECK_NPM == "True" ]];
        then
          { set +x ; coloredEcho ${BLUE} "WAIT FOR NPM TO REPLICATE" ; set -x ; }
          executeNpmCommand "npm i wait-for-package-replication@latest -g --quiet && wait-for-package-replication -p $PKG_CLIENT_NAME -v $VERSION --verbose"
        fi
      else
        { set +x ; coloredEcho ${YELLOW} "$PKG_CLIENT_NAME set to 'private', skipping NPM publish" ; set -x ; }
      fi
    fi

    if [[ -d "schema" ]] && [[ -f "schema/package.json" ]];
    then
      { set +x ; coloredEcho ${BLUE} "PUBLISH $SCHEMA_PKG_NAME@$VERSION to NPM with $BRANCH tag" ; set -x ; }
      executeNpmCommand "cd schema && node saveSchema && npm version $VERSION --no-git-tag-version && npm publish --tag $BRANCH"

      if [[ $CHECK_NPM == "True" ]];
      then
        { set +x ; coloredEcho ${BLUE} "WAIT FOR NPM TO REPLICATE" ; set -x ; }
        executeNpmCommand "npm i wait-for-package-replication@latest -g --quiet && wait-for-package-replication -p $SCHEMA_PKG_NAME -v $VERSION --verbose"
      fi
    fi
  fi

  cleanupContainer ${CONTAINER_ID}
}

function runTests {
  runBuildContainer

  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Run tests" ; set -x ; }

  if [[ -d "coverage" ]]; then rm -rf coverage; fi
  if [[ -f "test-results.tap" ]]; then rm test-results.tap; fi

  if ! docker exec -t ${CONTAINER_ID} npm run ci;
  then
    { set +x ; displayError ${RED} "ERROR: Unit tests failed to pass" ; set -x ; }
  else
    { set +x ; coloredEcho ${GREEN} "Tests passed" ; set -x ; }
  fi

  docker cp ${CONTAINER_ID}:/usr/src/app/test-results.tap test-results.tap

  # frontends can't do clover coverage
  if [[ -z "$APP" && "$APP" != "sport" ]];
  then
    docker cp ${CONTAINER_ID}:/usr/src/app/coverage coverage
  fi

  cleanupContainer ${CONTAINER_ID}
}

function runLinting {
  runBuildContainer

  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Check linting" ; set -x ; }

  if ! docker exec -t ${CONTAINER_ID} npm run lint;
  then
    { set +x ; displayError ${RED} "ERROR: Linting failed" ; set -x ; }
  else
    { set +x ; coloredEcho ${GREEN} "Linting passed" ; set -x ; }
  fi

  cleanupContainer ${CONTAINER_ID}
}

function runE2eTests {
  if [[ $BRANCH != "master" ]];
  then
    pullDockerRuntimeImage
    pullDockerBuildImage
  fi

  if [[ -f "e2e-test-results.tap" ]]; then rm e2e-test-results.tap; fi

  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Run E2E and verify NGINX, if available" ; set -x ; }

  # Used for building frontends
  if [[ -n "$APP" ]];
  then
    { set +x ; coloredEcho ${BLUE} "Running NGINX config test" ; set -x ; }

    if ! docker run --rm -t $RUNTIME_IMAGE nginx;
    then
      { set +x ; displayError ${RED} "ERROR: NGINX config test failed" ; set -x ; }
    else
      { set +x ; coloredEcho ${GREEN} "NGINX config test passed" ; set -x ; }
    fi
  else
    { set +x ; coloredEcho ${GREEN} "No NGINX config to test" ; set -x ; }
  fi

  if [[ -d "client" ]] && [[ -d "e2e" ]] && [[ -f "e2e/run.sh" ]];
  then
    { set +x ; coloredEcho ${BLUE} "Running E2E tests" ; set -x ; }

    if ! bash -x e2e/run.sh;
    then
      { set +x ; displayError ${RED} "ERROR: E2E tests failed, check TAP results in Jenkins for build" ; set -x ; }
    else
      { set +x ; coloredEcho ${GREEN} "E2E tests passed" ; set -x ; }
    fi
  else
    { set +x ; coloredEcho ${YELLOW} "WARNING: No E2E tests found, create some!" ; set -x ; }
  fi
}

function begin {
  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Executing task(s)" ; set -x ; }

  # Build tasks
  if [[ $EXECUTE_BUILD_BUILDER == "true" || $RUN_ALL == "true" ]];
  then
    buildBuilder
    ((JOB+=1))
  fi

  if [[ $IS_SERVICE == "True" ]] && [[ $EXECUTE_BUILD_RUNTIME == "true" || $RUN_ALL == "true" ]];
  then
    buildRuntime
    ((JOB+=1))
  fi

  # Verify tasks
  if [[ $EXECUTE_CHECK_PACKAGE == "true" || $RUN_ALL == "true" ]];
  then
    verifyPackage
    ((JOB+=1))
  fi

  if [[ $EXECUTE_CHECK_JIRA == "true" || $RUN_ALL == "true" ]];
  then
    verifyJira
    ((JOB+=1))
  fi

  if [[ $EXECUTE_CHECK_PREPUSH == "true" || $RUN_ALL == "true" ]];
  then
    verifyPrepush
    ((JOB+=1))
  fi

  if [[ $IS_SERVICE == "True" ]] && [[ $EXECUTE_RUN_E2E == "true" || $RUN_ALL == "true" ]];
  then
    runE2eTests
    ((JOB+=1))
  fi

  if [[ $EXECUTE_RUN_TESTS == "true" || $RUN_ALL == "true" ]];
  then
    runTests
    ((JOB+=1))
  fi

  if [[ $EXECUTE_RUN_LINT == "true" || $RUN_ALL == "true" ]];
  then
    runLinting
    ((JOB+=1))
  fi

  # Publish
  if [[ $EXECUTE_PUBLISH_NPM == "true" || $RUN_ALL == "true" ]];
  then
    publishPackage
    ((JOB+=1))
  fi

  cleanupContainer ${CONTAINER_ID}
}

# Begin execution
gatherFacts

if [[ $BRANCH == "master" ]];
then
  buildBuilder
  verifyPrepush

  if [[ $FORCE == "true" ]];
  then
    getNpmVariables
  else
    verifyPackage
  fi

  verifyJira
  runLinting
  runTests

  if [[ $IS_SERVICE == "True" ]];
  then
    buildRuntime
    runE2eTests
    publishRuntime
  fi

  publishPackage
else
  begin
  # Backwards compatibility
  if [[ "$JOB" -eq 0 ]];
  then
    RUN_ALL="true"
    begin
  fi
fi

# All done
cleanupContainer ${CONTAINER_ID}

if [[ "$ERROR" -gt 0 ]];
then
  { set +x ;
    separatorEcho ;
    coloredEcho ${RED} "-----------------------------------------" ;
    coloredEcho ${RED} "Errors found, scroll up to find issues" ;
    coloredEcho ${RED} "-----------------------------------------" ;
    separatorEcho
    coloredEcho ${RED} "${ERROR} Error(s): \n${ERRORS}"
    coloredEcho ${RED} "-----------------------------------------" ;
    separatorEcho ;
    set -x ;
  }
  exit 1;
else
  { set +x ;
    separatorEcho ;
    coloredEcho ${GREEN} "-----------------------------------------" ;
    coloredEcho ${GREEN} "No errors detected" ;
    coloredEcho ${GREEN} "-----------------------------------------" ;
    separatorEcho ;
    set -x ;
  }
fi

function getBranches {
  git fetch --tags
  git fetch origin "+refs/tags/*:refs/tags/*"
  git remote update --prune

  set +x
  while read line ; do
    local branchName=${line#${prefix}}
    branches+=("${branchName}")
  done < <(git branch -r | grep -v HEAD)
  set -x
}

function loopOverTags {
  set +x
  for gitTag in $(git tag)
  do
    if [[ ${gitTag} != *"master"* ]];
    then
      local branchExists=`checkExists ${gitTag}`

      if [[ ${branchExists} == false ]];
      then
        removeTags+=("${gitTag}")
      else
        { set +x ; coloredEcho ${BLUE} "Branch exists for ${gitTag}" ; set -x ; }
      fi
    fi
  done

  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Found the following tags that can be deleted:" ; set -x ; }
  printf '%s\n' "${removeTags[@]}"
  { set +x ; separatorEcho ; set -x ; }
  set -x
}

function checkExists {
  local gitTag=$1
  local branchExists=false

  for branch in "${branches}";
  do
    if [[ ${gitTag} == *"${branch}"* ]];
    then
      { set +x ; coloredEcho ${BLUE} "Keeping tag for branch ${branch}" ; set -x ; };
      branchExists=true
      break
    fi
  done

  echo ${branchExists}
}

function removeOldTags {
  set -x
  { set +x ; separatorEcho ; coloredEcho ${YELLOW} "Removing old tags" ; set -x ; }
  for i in "${removeTags[@]}"
  do
    { set +x ; separatorEcho ; coloredEcho ${YELLOW} "Deleting ${i}" ; set -x ; }
    git tag -d $1 || { set +x ; coloredEcho ${YELLOW} "WARNING: Failed to delete git tag" ; set -x ; };
    git push origin :${i} || { set +x ; coloredEcho ${YELLOW} "WARNING: Failed to push git tag" ; set -x ; };
  done
}

if [[ $BRANCH == "master" && "$SUPPORTS_TAGS" == "True" ]];
then
  if [ ! -z "$HAS_GIT_TAG" ];
  then
    { set +x ; coloredEcho ${BLUE} "Removing existing git tag: ${GIT_TAG}" ; set -x ; }
    (git fetch --tags && git tag -d ${GIT_TAG} && git push origin :refs/tags/${GIT_TAG}) || { set +x ; coloredEcho ${YELLOW} "WARNING: Unable to remove git tag: ${GIT_TAG}" ; set -x ; }
  fi

  { set +x ; coloredEcho ${BLUE} "Pushing new git tag" ; set -x ; }
  git tag ${GIT_TAG} -m "$(git log -1 --pretty=format:"%h: %B")"
  git push origin ${GIT_TAG} || { set +x ; coloredEcho ${YELLOW} "WARNING: Failed to push git tag" ; set -x ; }

  { set +x ; separatorEcho ; coloredEcho ${BLUE} "Checking old tags" ; set -x ; }

  set +x
  getBranches
  loopOverTags
  set -x

  if [[ $PRUNE_OLD_TAGS == "true" ]];
  then
    removeOldTags
  fi
fi
