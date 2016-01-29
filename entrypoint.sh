#!/bin/bash
# Set default settings, pull repository, build
# app, etc., _if_ we are not given a different
# command.  If so, execute that command instead.
set -e

# Default values
: ${APP_DIR:="/var/www"}
: ${SRC_DIR:="/src/app"}
: ${BRANCH:="master"}
: ${PORT:="80"}
: ${RELEASE:="latest"}

export PORT

# If we were given arguments, run them instead
if [ $? -gt 1 ]; then
   exec "$@"
fi

# If we are provided a GITHUB_DEPLOY_KEY (path), then
# change it to the new, generic DEPLOY_KEY
if [ -n "${GITHUB_DEPLOY_KEY}" ]; then
   DEPLOY_KEY=$GITHUB_DEPLOY_KEY
fi

# If we are given a DEPLOY_KEY, copy it into /root/.ssh and
# setup a github rule to use it
if [ -n "${DEPLOY_KEY}" ]; then
   if [ ! -f /root/.ssh/deploy_key ]; then
      mkdir -p /root/.ssh
      cp ${DEPLOY_KEY} /root/.ssh/deploy_key
      cat << ENDHERE >> /root/.ssh/config
Host *
  IdentityFile /root/.ssh/deploy_key
  StrictHostKeyChecking no
ENDHERE
   fi
fi

# Make sure critical directories exist
mkdir -p $SRC_DIR

# getrepo pulls the supplied git repository into $SRC_DIR
function getrepo {
   if [ -e ${SRC_DIR}/.git ]; then
      pushd ${SRC_DIR}
      echo "Updating existing local repository..."
      git fetch
      popd
   else
      echo "Cloning ${REPO}..."
      git clone ${REPO} ${SRC_DIR}
   fi

   cd ${SRC_DIR}

   echo "Switching to branch/tag ${BRANCH}..."
   git checkout ${BRANCH}

   echo "Forcing clean..."
   git reset --hard origin/${BRANCH}
   git clean -d -f
}

if [ -n "${REPO}" ]; then
   getrepo
fi

# See if we have a valid meteor source
METEOR_DIR=$(find ${SRC_DIR} -type d -name .meteor -print |head -n1)
if [ -n "${METEOR_DIR}" ]; then
   echo "Meteor source found in ${METEOR_DIR}"
   cd ${METEOR_DIR}/..

   # Download Meteor installer
   echo "Downloading Meteor install script..."
   curl ${CURL_OPTS} -o /tmp/meteor.sh https://install.meteor.com/

   # Install Meteor tool
   echo "Installing Meteor ${RELEASE}..."
   if [ "$RELEASE" != "latest" ]; then
     sed -i "s/^RELEASE=.*/RELEASE=${RELEASE}/" /tmp/meteor.sh
   fi
   chmod +x /tmp/meteor.sh
   /tmp/meteor.sh
   rm /tmp/meteor.sh

# Install NPM modules
if [ -e ${METEOR_DIR} ]; then
   echo "Installing NPM prerequisites..."
   pushd ${METEOR_DIR}
   npm install
   popd
else
   echo "Unable to locate server directory in ${BUNDLE_DIR}; hold on: we're likely to fail"
fi

# Run meteor
cd ${METEOR_DIR}
echo "Starting Meteor Application..."
exec meteor
