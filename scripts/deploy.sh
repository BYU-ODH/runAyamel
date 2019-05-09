#!/usr/bin/env bash

set -e

yvideo_deploy_initialize() {
    cd $(dirname $1)
    cd $(git rev-parse --show-toplevel)
    source ${YVIDEO_DEPLOY_ENVIRONMENT:-/var/yvideo/yvideo-conf/yvideo_env}

    git checkout -- .
    git checkout master
    git pull

    if [[ "$HOSTNAME" == *beta* ]]; then
        YVIDEO_VERSION="--beta"
    else
        YVIDEO_VERSION="--production"
    fi
}

yvideo_deploy_restart_services() {
    set +e
    # remove the entire stack
    bash setup_yvideo.sh $YVIDEO_VERSION --remove
    if [[ $? -ne 0 ]]; then
        printf "$(date)::yvideo_deploy.sh::WARNING::Failed to stop service yvideo\n" >> deploy.log
    fi
    sleep 30
    # restart the entire stack
    bash setup_yvideo.sh $YVIDEO_VERSION --build --nc --clean $deploy_feature_branch
    ecode=$?
    set -e
    if [[ $ecode -ne 0 ]]; then
        printf "$(date)::yvideo_deploy.sh::ERROR::Failed to deploy yvideo\n" >> deploy.log
        exit 1
    else
        printf "$(date)::yvideo_deploy.sh::SUCCESS::yvideo successfully deployed\n" >> deploy.log
    fi
}

yvideo_deploy() {
    yvideo_deploy_initialize $1
    yvideo_deploy_restart_services
}

## Set the branch to be deployed to a certain branch
if [[ $# -gt 0 ]]; then
    res=$(git ls-remote --heads https://github.com/BYU-ODH/yvideo "$1" | wc -l)
    if [[ $res -eq 1 ]]; then
        deploy_feature_branch="--feature=$1"
    else
        deploy_feature_branch=""
    fi
fi

yvideo_deploy $0

