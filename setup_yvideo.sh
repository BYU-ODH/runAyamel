#!/usr/bin/env bash

_command=""

### LOG VARIABLES
log_service=""
log_mode=""

### BUILD VARIABLES
default=""
attach=""
remove=""
build=""
cache=""
update=""
force=""
dl_releases="true"
clean=""
setup_only=""
super_duper_clean=""
project_name="yvideo"
git_dir=${GITDIR:-~/Documents/GitHub}
scriptpath="$(cd "$(dirname "$0")"; pwd -P)"
services=""
dev_compose_dir="compose_files/dev"
production_compose_dir="compose_files/prod"
beta_compose_dir="$production_compose_dir"
test_compose_dir="compose_files/travis"
compose_file_dir=""
mode=""
branchname=""
featurebranch=""
container=""
test_object_name=""

declare -A repos # Associative array! :) used in the compose_dev function
repos=([yvideo]="" [yvideojs]="" [EditorWidgets]="" [subtitle-timeline-editor]="" [TimedText]="" [yvideo-dict-lookup]="" [yvideo-client]="")
yvideo_remote=(https://github.com/BYU-ODH/yvideo)
ylex_remote=(https://github.com/BYU-ODH/yvideo-dict-lookup)
dependencies_remotes=(https://github.com/BYU-ODH/yvideojs
        https://github.com/BYU-ODH/EditorWidgets
        https://github.com/BYU-ODH/subtitle-timeline-editor
        https://github.com/BYU-ODH/TimedText)

### SHARED VARIABLES
exit_code=0

usage () {
    echo 'Optional Params:'
    echo
    echo '          [--default          | -e]    Accept the default repository locations'
    echo "                                       Used for: ${!repos[@]}"
    echo '                                       (default is $GITDIR or ~/Documents/GitHub for everything)'
    echo '                                       Only used with --test and --dev'
    echo '          [--help             | -h]    Show this dialog'
    echo '          [--attach           | -a]    Attach to the yvideo container after starting it'
    echo '                                       The containers will be run in the background unless attach is specified'
    echo '          [--remove           | -r]    Removes all of the containers that start with the project prefix: $mode'
    echo '                                       Containers are removed before anything else is done.'
    echo '          [ -frd |-frb |-frp |-frt]    Removes everything in the docker-compose project using docker-compose down.'
    echo '          [--clean            | -c]    Remove all of the created files in the yvideo-deploy directory.'
    echo '                                       Cleanup is run before any other setup.'
    echo '                                       This option can be used without one of the required params.'
    echo '                                       If specified twice, cleanup will be called before and after setup.'
    echo '          [--setup-only           ]    Will set up all of the specified services but will not run docker-compose.'
    echo "                                       Mainly for development and testing of $project_name"
    echo '          [--build                ]    Used to build specified services.'
    echo '          [--nc                   ]    Container building process will not use cached images.'
    echo '          [--nr                   ]    Static dependency releases will not be downloaded.'
    echo '          [--force            | -f]    Will recreate the containers even if they are up to date.'
    echo '                                       Existing containers will not be updated if this flag is not specified.'
    echo '                                       Passes --force to `docker service update`'
    echo '          [--restart          |-rs]    Restarts the specified service.'
    echo '          [--services=...  |-s=...]    Specify which services to run.'
    echo '                                       Provide a string with the following characters. The letters correspond to services:'
    echo '                                       d -> database'
    echo '                                       s -> server'
    echo '                                       v -> video'
    echo '                                       x -> ylex'
    echo '                                       example: --services=dv # only the database and yvideo will be started'
    echo "          [--tf                   ]    Specify a test object name. Only this object's tests will run"
    echo '          [--feature=<branchname> ]    Will use the provided branch for yvideo instead of the default.'
    echo '                                       This is useful for deploying some branch that has a feature we want to test'
    echo '                                       or for deploying hotfixes.'
    echo '                                       This flag is only used in the production and beta modes.'
    echo
    echo
    echo 'Required Params (One of the following. The last given option will be used if multiple are provided):'
    echo
    echo '          [--production       | -p]    Use the production docker-compose files.'
    echo '          [--beta             | -b]    Use the beta docker-compose files.'
    echo '          [--dev              | -d]    Use the development docker-compose files.'
    echo '          [--test             | -t]    Use the development docker-compose files.'
    echo '                                       Use volumes and run tests locally'
    echo '          [--travis               ]    Use the testing docker-compose files.'
    echo '                                       Travis specific setup'
    echo
    echo
    echo 'Environment Variables:'
    echo
    echo '  YVIDEO_SQL              The folder that contains all of the sql scripts to be run. *Not required'
    echo '                          Files in this folder should be named <DATABASE_NAME>.sql.'
    echo '                          One database will be created per file and will have the same name as the .sql file.'
    echo '  YVIDEO_SQL_DATA         The folder for the mysql data volume. *Required (Except when using --travis)'
    echo '  YVIDEO_CONFIG_PROD      The path to the yvideo application.conf. *Required only for production'
    echo '  YVIDEO_CONFIG_BETA      The path to the yvideo application.conf for the beta service. *Required only for beta'
    echo '  YLEX_CONFIG_PROD        The path to the ylex application.conf. *Required only for production'
    echo '  YLEX_CONFIG_BETA        The path to the ylex application.conf for the beta service. *Required only for beta'
    echo '  YVIDEO_SITES_AVAILABLE  The path to the sites-available folder.'
    echo "  GITDIR                  The path to the yvideo project and all it's dependencies. Used for development. *Not required"
    echo
    echo 'The following are required to enable ssl:'
    echo
    echo '  YVIDEO_SERVER_KEYS       Space separated paths to server keys'
    echo '  YVIDEO_SITE_CERTIFICATES Space separated paths to site certs'
    echo '                           Both of the previous variables are space separated lists of paths to key or cert files.'
    echo '                           The key files will be renamed to key#.key and the cert files will be renamed to cert#.crt'
    echo '                           where the # is the index to the file in the list starting with 0.'
    echo
}

options () {
    if [[ "$1" == "log" ]]; then
        shift
        _command="log"
        log_options $@
    else
        _command="build"
        build_options $@
    fi
}

log_options() {
    for opt in "$@"; do
        if [[ "$opt" =~ ^\-s=.*$ ]] || [[ "$opt" =~ ^\-s=.*$ ]];
        then
            log_service=${opt##*=}

        elif [[ "$opt" == "-t" ]];
        then
            log_mode="test"

        elif [[ "$opt" == "-d" ]];
        then
            log_mode="dev"

        elif [[ "$opt" == "-p" ]];
        then
            log_mode="prod"

        elif [[ "$opt" == "-b" ]];
        then
            log_mode="beta"

        fi
    done
}

build_options () {
    for opt in "$@"; do
        if [[ "$opt" == "--default" ]] || [[ "$opt" == "-e" ]];
        then
            default="true"

        elif [[ "$opt" == "--dev" ]] || [[ "$opt" == "-d" ]];
        then
            compose_file_dir="$dev_compose_dir"
            mode="dev"

        elif [[ "$opt" == "--production" ]] || [[ "$opt" == "-p" ]];
        then
            compose_file_dir="$production_compose_dir"
            mode="prod"
            branchname="master"

        elif [[ "$opt" == "--beta" ]] || [[ "$opt" == "-b" ]];
        then
            compose_file_dir="$beta_compose_dir"
            mode="beta"
            branchname="develop"

        elif [[ "$opt" == "--travis" ]];
        then
            compose_file_dir="$test_compose_dir"
            mode="travis"

        elif [[ "$opt" == "--test" ]] || [[ "$opt" == "-t" ]];
        then
            mode="test"

        elif [[ "$opt" == "--build" ]];
        then
            build=true

        elif [[ "$opt" =~ ^\-\-services=.*$ ]] || [[ "$opt" =~ ^\-s=.*$ ]];
        then
            service_list=${opt##*=}

        elif [[ "$opt" == "--help" ]] || [[ "$opt" == "-h" ]];
        then
            usage && exit 1

        elif [[ "$opt" == "--attach" ]] || [[ "$opt" == "-a" ]];
        then
            attach=true

        elif [[ "$opt" == "--remove" ]] || [[ "$opt" == "-r" ]];
        then
            remove=true

        elif [[ "$opt" == "--restart" ]] || [[ "$opt" == "-rs" ]];
        then
            restart_service=true

        elif [[ "$opt" == "--force" ]] || [[ "$opt" == "-f" ]];
        then
            force="--force"

        elif [[ "$opt" == "--update" ]] || [[ "$opt" == "-u" ]];
        then
            update="true"

        elif [[ "$opt" == "--clean" ]] || [[ "$opt" == "-c" ]];
        then
            if [[ -n "$clean" ]]; then
                super_duper_clean=true
            fi
            clean=true

        elif [[ "$opt" == "--setup-only" ]];
        then
            setup_only=true

        elif [[ "$opt" == "--nc" ]];
        then
            cache="--no-cache"

        elif [[ "$opt" == "--nr" ]];
        then
            dl_releases=""

        elif [[ "$opt" =~ ^\-\-feature=.*$ ]];
        then
            featurebranch=${opt##*=}

        elif [[ "$opt" =~ ^\-\-tf=.*$ ]];
            then
                test_object_name=${opt##*=}

        else
            echo "Argument: [$opt] not recognized."
            exit 1
        fi
    done

    if [[ -z "$mode" ]] && [[ -z "$update" ]] && [[ -z "$remove" ]] && [[ -z "$clean" ]]; then
        echo "[Error]: No mode specified"
        echo
        usage
        exit 1
    fi
}

### LOG FUNCTIONS

log_container () {
    log_mode=${log_mode:-"dev"}
    log_service=${log_service:-"yvideo"}
    container_id=$(get_container_id $log_mode $log_service)
    if [[ $? -eq 0 ]]; then
        # redirects stderr to stdout by default so we can pipe the output
        docker logs $container_id 2>&1
        exit_code=$?
    else
        echo Failed to find container for service: $log_mode"_$log_service"
        exit_code=1
    fi
}

### BUILD FUNCTIONS

## $1 is the string of services letters: dsvx
get_services () {
    ## Gets the names of the files to use in the build and deploy steps
    ## as well as the services that need to be run
    commands=$(python3 scripts/compose_files.py -s ${1:-"dsvx"} -p "$compose_file_dir/")
    ## prevent bash from parsing the echo output
    OLD_IFS=$IFS
    IFS=
    ## The following variables contain the flags for which services are to be built/deployed
    ## The services variables is just the list of services without file extensions or other flags
    ## A default (dsvx) run with "production_stack" as the value of $compose_file_dir will yield the following variables:
    ##      build_flags="-f production_stack/database.yml -f production_stack/server.yml -f production_stack/yvideo.yml -f production_stack/ylex.yml"
    ##      deploy_flags="-c production_stack/database.yml -c production_stack/server.yml -c production_stack/yvideo.yml -c production_stack/ylex.yml"
    ##      services="database server yvideo ylex"
    ## The compose_files.py script outputs three newline separated strings
    ## For this reason we have to use sed to get the line that corresponds to the certain variable
    ## The IFS needs to be changed temporarily in order the allow the (echo | ...) command to be
    ## processed as 3 lines rather than joining them into one line
    build_flags=$(echo $commands | sed -e "1q;d")
    deploy_flags=$(echo  $commands | sed -e "2q;d")
    services=$(echo $commands | sed -e "3q;d")
    IFS=$OLD_IFS
}

remove_services () {
    if [[ -n "$mode" ]]; then
        if [[ -z "$service_list" ]]; then
            docker stack rm $mode
        else
            get_services $service_list
            for s in $services; do
                docker service rm $mode"_"$s
            done
        fi
    else
        echo "Please specify a mode with one of the following:"
        echo "  -p, -b, -d, -t, --travis"
        exit 1
    fi
}

update_services () {
    if [[ -z "$service_list" ]]; then
        echo "Kindly specify a service like so:"
        echo "$scriptpath/setup_yvideo.sh ... -s=[dsvx]"
        exit 1
    fi
    if [[ -n "$mode" ]]; then
        [[ -z "$services" ]] && get_services $service_list
        for s in $services; do
            docker service update $deploy_flags "$mode""_""$s" $force
        done
    else
        echo "Please specify a mode with one of the following:"
        echo "  -p, -b, -d, -t, --travis"
        exit 1
    fi
}

prune_docker () {
    docker system prune -af
}

stop_start_service() {
    if [[ -z "$service" ]]; then
        echo "[ERROR]: No service provided."
        exit 1
    fi
    con="$project_name"_$1"_1"
    echo "Restarting: $con"
    docker stop $con
    docker start $con
}

docker_compose_down () {
    if [[ ! -e "$compose_override_file" ]]; then
        echo "YO!! "$compose_override_file" should exist before you can delete anything from that project"
        echo "If you don't want to create any new containers and whatnot, you can run the following command first:"
        echo "$0 -[d|p|t|b] --setup-only"
        exit 1
    fi
    docker-compose -p $project_name -f docker-compose.yml -f "$compose_override_file" down -v --rmi all
}

compose_dev () {
    # setting up volumes
    # loop over the keys of the repos associative array
    for repo in "${!repos[@]}"; do
        if [[ -z "$default" ]]; then
            read -r -p "Enter path to $repo (default: ${dir_name:-$git_dir}/$repo): " user_dir
        else
            user_dir=""
        fi
        if [[ -z "$user_dir" ]]; then
            user_dir="$git_dir/$repo"
        else
            # expand the path
            if [[ -d "$user_dir" ]]; then
                user_dir="$( cd "$user_dir"; pwd -P )"
                dir_name=$(dirname "$user_dir")
            else
                echo "$user_dir does not exist."
                user_dir="$dir_name/$repo"
            fi
        fi
        echo "Using $user_dir for $repo."
        repos["$repo"]="$user_dir"
    done

    ## export directories which will be used in the build and deploy steps by docker-compose and docker stack deploy
    export yvideo="${repos[yvideo]}"
    export yvideojs="${repos[yvideojs]}"
    export subtitle_timeline_editor="${repos['subtitle-timeline-editor']}"
    export EditorWidgets="${repos[EditorWidgets]}"
    export TimedText="${repos[TimedText]}"
    export yvideo_client="${repos['yvideo-client']}"
    export yvideo_dict_lookup="${repos['yvideo-dict-lookup']}"
}

# used when --travis is specified
compose_test () {

    if [[ -z "$BRANCH" ]] || [[ -z "$TRAVIS_BUILD_DIR" ]]; then
        echo "--travis flag is meant for use on travis CI."
        echo "The BRANCH and TRAVIS_BUILD_DIR env variables need to be exported to this script."
        exit 1
    fi

    if [[ "$TRAVIS_BUILD_DIR" == *yvideo-dict-lookup ]];then
        test_repo="ylex"
        get_services dx
    else
        test_repo="yvideo"
        get_services dv
    fi
    # Need to build from scratch on travis
    build=true

    # Copy in code from travis build dir
    cp -r $TRAVIS_BUILD_DIR docker_contexts/travis/$test_repo
    touch docker_contexts/travis/yvideo_test.sql
}

# does a shallow clone with only 1 commit on the $1 branch for all repositories
# expects a branchname as an argument
# The branch should exist on all yvideo repositories
# clones the repos into the prod folder
# $2 is the service mode: production or beta
compose_production () {
    # Allow deployment of feature branches
    # if --feature=branchname is not present, the default branch will be deployed
    yvideo_target_branch=${featurebranch:-$1}
    # copy the application.conf file into the context of the dockerfile for yvideo
    # Needs to be copied because:
    # The <src> path must be inside the context of the build;
    # you cannot COPY ../something /something, because the first step of a docker build
    # is to send the context directory (and subdirectories) to the docker daemon.
    # https://docs.docker.com/engine/reference/builder/#copy
    if [[ -f "$YVIDEO_CONFIG" ]]; then
        # clone the yvideo master branch into the production folder
        git clone -b "$yvideo_target_branch" --depth 1 "$yvideo_remote" docker_contexts/"$2"/yvideo/$(basename $yvideo_remote) &> /dev/null
        # copy it into the production dockerfile folder
        cp "$YVIDEO_CONFIG" docker_contexts/"$2"/yvideo/application.conf
    else
        echo "[$YVIDEO_CONFIG] does not exist."
        echo "The environment variable YVIDEO_CONFIG_[BETA|PROD] needs to be exported to this script in order to run yvideo in production mode."
        exit 1
    fi

    # copy the application.conf file into the context of the dockerfile for ylex
    if [[ -f "$YLEX_CONFIG" ]]; then
        # clone the ylex branch into the ylex folder
        git clone -b "$1" --depth 1 "$ylex_remote" docker_contexts/"$2"/ylex/$(basename $ylex_remote) &> /dev/null
        # copy the application.conf file into the ylex dockerfile folder
        cp "$YLEX_CONFIG" docker_contexts/"$2"/ylex/application.conf
    else
        echo "[$YLEX_CONFIG] does not exist."
        echo "The environment variable YLEX_CONFIG_[BETA|PROD] needs to be exported to this script in order to run yvideo in production mode."
        exit 1
    fi
}

cleanup () {
    # remove all untracked files except for deploy.log
    git clean -xdff -e deploy.log
}

extract_client() {
    if [[ -f "$1" ]]; then
        rm -rf yvideo-client $2/yvideo-client
        mkdir yvideo-client
        tar xf $1 -C yvideo-client
        mv yvideo-client $2/
    fi
}

configure_server () {
    # The directory that contains the dockerfile we want to use
    server_context=$(if [[ "$mode" == "dev" ]]; then echo docker_contexts/server/dev; else echo docker_contexts/server; fi)

    # The sites-available should be a folder that contains the apache conf for the sites that will
    # be running on this server.
    # The conf files can contain any apache configuration and they will be included by the httpd.conf file
    # assuming that it imports the folder that we create here.
    # The ideal contents of the sites files is two VirtualHost directives. One that runs on port 80 that redirects to
    # the one that runs on port 443 with ssl enabled.
    if [[ -d "$YVIDEO_SITES_AVAILABLE" ]] && [[ $(ls -1 $YVIDEO_SITES_AVAILABLE | wc -l) -ne 0 ]]; then
        export SITES_FOLDER_NAME=${YVIDEO_SITES_AVAILABLE##*/}
        cp -r $YVIDEO_SITES_AVAILABLE $server_context/
    elif [[ "$mode" != "travis" ]]; then
        echo "[WARNING] - No httpd site config loaded. Make sure that the"
        echo "            YVIDEO_SITES_AVAILABLE environment variable contains the path"
        echo "            to a directory that contains the virtual host configurations for"
        echo "            the sites you want to run on the httpd server."
        echo
    fi

    if [[ "$mode" == "dev" ]]; then
        echo "Skipping releases download / ssl setup for dev mode."
        return
    fi

    # the dependencies go inside here
    mkdir -p $server_context/static/css $server_context/static/js

    # clone the dependencies. We are keeping this here to preserve compatibility with the
    # old sites' frontends. This should be removed once we are exclusively using the yvideo-client front-end
    for repo in "${dependencies_remotes[@]}"; do
        git clone -b $branchname --depth 1 "$repo" $server_context/static/$(basename $repo) &> /dev/null
    done

    ## Download releases for static file dependencies
    if [[ -n "$dl_releases" ]]; then
        python_environment_name="env"
        if [[ ! -d "$python_environment_name" ]]; then
            if [[ -z "$(which virtualenv)" ]]; then
                echo "Virtualenv not installed. Skipping release download"
                return
            fi
            echo "creating virtual environment"
            virtualenv -p python3 $python_environment_name
        fi
        . "$python_environment_name/bin/activate"
        # load requirements file
        python_requirements="scripts/requirements.txt"
        pip install -qr $python_requirements
        # download the dependency releases into the server folder using the download_release.py script
        # it requires the requests package which we install here in a virtualenv
        echo "Downloading $branchname releases..."
        token=$([[ -n $YVIDEO_GITHUB_ACCESS_TOKEN ]] && echo "--access_token $YVIDEO_GITHUB_ACCESS_TOKEN")
        is_prod=$([[ "$branchname" == "master" ]] && echo "--production")
        releases=$(python scripts/download_release.py $is_prod $token)
        if [[ -z "$releases" ]]; then
            echo "[WARNING]: No releases found."
        else
            for release in $releases; do
                echo "Extracting: $release"
                if [[ "$release" == *yvideo-client* ]]; then
                    ## the yvideo-client repository has loose files, unlike the other dependencies
                    ## which contain only two folders each: css and js.
                    ## So in this case we have to extract into another folder to keep
                    ## track of all the files in the archive.
                    ## These files are moved to the server_context in the extract_client function
                    extract_client $release $server_context/static
                else
                    ## All of the dependencies contain two folders: css and js which will be
                    ## copied into the server_context after they have all been extracted
                    tar xf $release
                fi
            done
            mv css/* $server_context/static/css
            mv js/* $server_context/static/js
        fi
        deactivate
    fi
}

configure_database () {
    # Check if data volume env var is defined and the path exists if we need it
    if [[ ! -d "$YVIDEO_SQL_DATA" ]]; then
        # We don't use database volumes for testing on travis
        if [[ "$mode" != "travis" ]]; then
            echo "[${YVIDEO_SQL_DATA:-Environment Variable YVIDEO_SQL_DATA}] does not exist."
            echo "The environment variable YVIDEO_SQL_DATA needs to be exported to this script."
            echo "And it needs to contain the path to a directory."
            exit 1
        fi
    fi

    # check if the docker secrets exist
    # only issues a warning
    # TODO stop the build if at least one of these is not set
    # We can't know which one of these they plan to use. However it is necessary to set one in order
    # to connect to the mysql service
    docker secret inspect mysql_root_password &>/dev/null
    [[ $? -ne 0 ]] && echo "[WARNING] - MYSQL ROOT PASSWORD SECRET NOT SET"

    docker secret inspect mysql_password &>/dev/null
    [[ $? -ne 0 ]] && echo "[WARNING] - MYSQL PASSWORD SECRET NOT SET"

    # Special case for when running from within travis
    if [[ "$mode" == "travis" ]]; then
        # copy the travis sql files from the test folder
        cp docker_contexts/travis/*.sql docker_contexts/database
    elif [[ -d "$YVIDEO_SQL" ]]; then
        # YVIDEO_SQL is a folder that contains the sql files to load into the database
        # copy it into the database dockerfile folder
        cp "$YVIDEO_SQL/"*.sql docker_contexts/database
    else
        echo "[$YVIDEO_SQL] does not exist."
        echo "No new databases will be created."
    fi
}

setup () {
    if [[ -z "$compose_file_dir" ]]; then
        echo "Please specify a directory with docker-compose config files using one of the following:"
        echo "  -p, -b, -d, -t, --travis"
        exit 1
    fi

    ## save the service names into $service among other things
    get_services $service_list

    ## compose_dev exports environment variables necessary for the server, ylex and yvideo services.
    if [[ "$mode" == "dev" ]] && [[ "$services" =~ server|ylex|yvideo ]]; then
        compose_dev
    fi

    if [[ "$services" == *yvideo* ]] || [[ "$services" == *ylex* ]]; then
        if [[ "$mode" == "prod" ]]; then
            YVIDEO_CONFIG="$YVIDEO_CONFIG_PROD"
            YLEX_CONFIG="$YLEX_CONFIG_PROD"
            compose_production $branchname $mode
        elif [[ "$mode" == "beta" ]]; then
            YVIDEO_CONFIG="$YVIDEO_CONFIG_BETA"
            YLEX_CONFIG="$YLEX_CONFIG_BETA"
            compose_production $branchname $mode
        elif [[ "$mode" == "travis" ]]; then
            [[ "$services" != *database* ]] && configure_database $compose_file_dir
            compose_test
        fi
    fi

    if [[ "$services" == *server* ]]; then
        configure_server $compose_file_dir
    fi

    if [[ "$services" == *database* ]]; then
        configure_database $compose_file_dir
    fi
}

# Params $1 = mode, $2 = service name
# Returns a live container id if one exists
# needs to be rewritten if we scale the services to more than one container
get_container_id () {
    _mode=$1
    _service=$2
    service_containers=$(docker service ps -q "$_mode"_$_service -f "desired-state=running" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "$_mode"_"$_service not found"
        exit 1
    fi
    OLD_IFS=$IFS
    IFS=
    for container in $service_containers; do
        yvideo_container_id=$(docker inspect --format '{{.Status.ContainerStatus.ContainerID}}' $container)
        [[ $? -eq 0 ]] && break
        yvideo_container_id=""
    done
    IFS=$OLD_IFS
    echo $yvideo_container_id
    exit 0
}

run_tests_locally () {
    yvideo_container_id=$(get_container_id "dev" "yvideo")
    if [[ "$yvideo_container_id" != "" ]]; then
        if [[ -n "$test_object_name" ]]; then
            test_command="testOnly $test_object_name"
        else
            test_command="test"
        fi
        # test command needs to be escaped, otherwise, sbt won't get the test_object_name if it is passed in
        docker exec $yvideo_container_id sbt "$test_command"
        exit $?
    else
        echo "Running yvideo container not found."
        exit 1
    fi
}

run_docker_compose () {
    if [[ -n $build ]]; then
        export mode=$mode
        docker-compose $build_flags build $cache
        exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
            echo "[ERROR] - Build Failed with error Code $exit_code"
            exit $exit_code
        fi
    fi
}

start_services () {
    export mode=$mode
    docker stack deploy $deploy_flags $mode
    exit_code=$?
    [[ -n "$attach" ]] && [[ -n "$container" ]] && docker attach --sig-proxy=false "$container"
}

run_travis_tests () {
    # travis test mode without docker swarm
    docker-compose $build_flags up -d
    exit_code=$?
}

cd "$scriptpath"
options "$@"
if [[ "$_command" == "build" ]]; then
    [[ -n "$update" ]] && update_services && exit
    [[ -n "$remove" ]] && remove_services && exit
    [[ -n "$clean" ]] && cleanup
    [[ -n "$compose_file_dir" ]] && setup && [[ -z "$setup_only" ]] && run_docker_compose
    [[ "$mode" == "test" ]] && run_tests_locally

    if [[ -n "$compose_file_dir" ]] && [[ "$mode" == "travis" ]]; then
        run_travis_tests
    elif [[ -n "$compose_file_dir" ]]; then
        start_services
    fi

    [[ -n "$super_duper_clean" ]] && cleanup

elif [[ "$_command" == "log" ]]; then
    log_container
fi
# use the docker command exit code rather than whatever the last line may output
# Travis uses this as a way to detect whether the build failed
exit $exit_code

