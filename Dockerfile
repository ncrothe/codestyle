#######################################################################
# FILE AUTO GENERATED BY https://github.com/gutro/leo-base-repo-files #
#######################################################################

# Following https://github.com/nodejs/docker-node/blob/master/docs/BestPractices.md
FROM node:8.5

# Copy over NPM config
COPY .npmrc /root/.npmrc

WORKDIR /usr/src/app/

# Copy built application modules
COPY ./modules/ ./node_modules/

# Copy application files
COPY ./service ./

# Ready to go
CMD [ "node", "service/start.js" ]
