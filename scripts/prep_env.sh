#/bin/bash

scriptpath="$(cd "$(dirname "$0")"; pwd -P)"
repos_folder=${GITDIR:-$(dirname "$scriptpath")/..}
distro="$(lsb_release -si 2>/dev/null)"
docker_location="$(which docker 2>/dev/null)"
dcompose_location="$(which docker-compose 2>/dev/null)"

# clones all of the code for the project
clone_repos () {
    if [[ -n "$1" ]]; then
        branch="$1"
        github="$(ssh -o StrictHostKeyChecking=no git@github.com 2>&1 | grep 'Permission denied (publickey).')"
        if [[ -n "$github" ]]; then
            prefix="https://github.com/"
        else
            prefix="git@github.com:"
        fi
        echo "Cloning repos into $repos_folder"
        for reponame in yvideo yvideo-client yvideo-dict-lookup yvideojs subtitle-timeline-editor TimedText EditorWidgets; do
            remote="$prefix""BYU-ODH/""$reponame"
            cd $repos_folder
            if [[ -d "$reponame" ]]; then
                echo "$reponame has already been cloned."
            else
                git clone "$remote" &>/dev/null
            fi
            cd "$reponame"
            if [[ -n $(git ls-remote --heads "$remote" "$branch") ]]; then
                git checkout "$branch" &>/dev/null
            else
                echo "Branch $branch does not exist for repository: $reponame"
            fi
        done
    else
        echo "No branchname was specified, skipping cloning repositories."
    fi
}

# installs docker and docker-compose
install_docker () {
    if [[ -z "$docker_location" ]]; then
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
            sudo dnf install -y docker-ce
            sudo systemctl start docker
        fi
        sudo curl -L "https://github.com/docker/compose/releases/download/1.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

clone_repos "$1"
install_docker

