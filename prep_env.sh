#/bin/bash

set -e

scriptpath="$(cd "$(dirname "$0")"; pwd -P)"
repos_folder=$(dirname "$scriptpath")
distro="$(lsb_release -si 2>/dev/null)"
docker_location="$(which docker 2>/dev/null)" && :
dcompose_location="$(which docker-compose 2>/dev/null)" && :
branch=""

get_branch () {
    if [[ -n "$1" ]]; then
        branch="$1"
    else
        branch="master"
    fi
}

# clones all of the code for the project
clone_repos () {
    github="$(ssh -o StrictHostKeyChecking=no git@github.com 2>&1 | grep 'Permission denied (publickey).')" && :
    if [[ -n "$github" ]]; then
        prefix="https://github.com/"
    else
        prefix="git@github.com:"
    fi
    for reponame in yvideo yvideo-dict-lookup yvideojs subtitle-timeline-editor TimedText EditorWidgets; do
        remote="$prefix""BYU-ODH/""$reponame"
        cd $(dirname $scriptpath)
        git clone "$remote"
        cd "$reponame"
        if [[ -n $(git ls-remote --heads "$remote" "$branch") ]]; then
            git checkout "$branch"
        fi
    done
}

# installs docker and docker-compose
install_docker () {
    if [[ -z "$docker_loction" ]]; then
        # install docker
        if [[ "$distro" = "Ubuntu" ]]; then
            sudo apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl software-properties-common

            curl -silent -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
            has=$(sudo apt-key fingerprint 0EBFCD88)

            if [[ -z $has ]]; then
                echo "Error adding key. exiting"
                exit 1
            fi

            sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

            sudo apt-get update
            sudo apt-get install docker-ce

        elif [[ "$distro" = "Fedora" ]]; then
            sudo dnf remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine
            sudo dnf -y install dnf-plugins-core
            sudo dnf config-manager \
                --add-repo \
                https://download.docker.com/linux/fedora/docker-ce.repo
            sudo dnf install docker-ce
            sudo systemctl start docker
        fi
    fi

    if [[ -z "$docker_location" ]]; then
        # install docker-compose
        sudo curl -L "https://github.com/docker/compose/releases/download/1.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

get_branch "$1"
clone_repos
install_docker

