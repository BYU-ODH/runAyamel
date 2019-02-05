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
    bash setup_yvideo.sh $YVIDEO_VERSION --remove --services=v
    if [[ $? -ne 0 ]]; then
        printf "$(date)::yvideo_deploy.sh::WARNING::Failed to stop service yvideo\n" >> deploy.log
    fi
    sleep 30
    bash setup_yvideo.sh $YVIDEO_VERSION --build --nc
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

yvideo_deploy $0

