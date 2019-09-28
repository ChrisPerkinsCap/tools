#!/bin/bash

## SET IN THE ENVIRONMENT OR PASSED IN AS ARGS ##

# JNLP GROUP #
#JENKINS_URL:="${JENKINS_URL}"
#JENKINS_PORT:="${JENKINS_PORT}"
#JENKINS_TUNNEL:="${JENKINS_TUNNEL}"
#JENKINS_AGENT_NAME:="${JENKINS_AGENT_NAME}"
#JENKINS_AGENT_WORKDIR:="${JENKINS_AGENT_WORKDIR}"
#JENKINS_AGENT_SECRET:="${JENKINS_AGENT_SECRET}"

# SSH GROUP #
#JENKINS_MASTER_PUBKEY:="${JENKINS_MASTER_PUBKEY}"

## SET IN THE ENVIRONMENT ##
#VERSION:="${VERSION}"
#user:="${user}"
#group:="${group}"
#uid:="${uid}"
#gid:="${gid}"
#JENKINS_AGENT_HOME:="/home/jenkins"
#AGENT_WORKDIR:="${JENKINS_WORKDIR}"
#JENKINS_AGENT_DOCKER_SECRET_NAME:="${JENKINS_AGENT_DOCKER_SECRET_NAME}"
#JENKINS_AGENT_DOCKER_SECRET_FILE:="/run/secrets/${JENKINS_AGENT_DOCKER_SECRET_NAME}"
#JNLP_PROTOCOL_OPTS:="${JENKINS_PROTOCOL_OPTS}"
#JAVA_HOME:="${JAVA_HOME}"
#JAVA_BIN:="${JAVA_BIN}"

## Create an array that holds the order of precedance of the arguments in the exec command
declare -a commands_order

commands_order=("java_bin" "java_opts" "jnlp_protocol" "java_class_path" "jenkins_tunnel" "jenkins_url" "jenkins_agent_workdir" "jenkins_agent_secret" "jenkins_agent_name")

## declare an Associative Array
declare -A commands

commands=("java_opts"="${JAVA_OPTS}" "jnlp_protocol" "java_class_path"="-cp /usr/share/jenkins/agent.jar hudson.remoting.jnlp.Main -headless")


help() {
    JNLP_TAGS="
    | SHORT TAGS  |        EXTENDED TAGS        |                 EXAMPLE ANTICIPATED ARGUMENT VALUE               |
    -----------------------------------------------------------------------------------------------------------------
    |     -U      |  --jenkinsUrl               |                    https://jenkins-master.com                    |
    |     -P      |  --jenkinsPort              |                               8080                               |
    |     -T      |  --jenkinsTunnel            |                     http://tunnel-server:52080                   |
    |     -N      |  --jenkinsAgentName         |                           jnlp-agent-1                           |
    |     -D      |  --jenkinsAgentWorkdir      |                        /home/jenkins/agent                       |
    |     -S      |  --dockerAgentSecret        | ztPMsfV58steE7RqiVHaGpzyf3FcMan4G2gNGdYQWMyv8tPFfbMc2kWXWqXWU3z5 |
    |     -J      |  --dockerAgentSecretName    |                       01-06-19-jnlp-agent-1                      |
    |     -j      |  --dockerAgentSecretFile    |               /run/secrets/01-06-19-jnlp-agent-1                 |
    |     -K      |  --jenkinsMasterPubkey      |        ssh-rsa AAAAB3Nza < CUT > gwcdqIRmX jenkins@master        |
    |     -H      |  --help                     |                           NONE REQUIRED                          |
    -----------------------------------------------------------------------------------------------------------------

     EXAMPLE FOR JNLP ONLY
     -U https://jenkins-master.com, -P 8080, -N jnlp-agent-1, -D /home/jenkins/agent, -S ztPMsfV58steE7RqiVHaGpzyf3FcMan4G2gNGdYQWMyv8tPFfbMc2kWXWqXWU3z5

     EXAMPLE FOR JNLP WITH DOCKER SECRET NAME
     -U https://jenkins-master.com, -P 8080, -N jnlp-agent-1, -D /home/jenkins/agent, -J 01-06-19-jnlp-agent-1

     EXAMPLE FOR JNLP WITH DOCKER SECRET FILE
     -U https://jenkins-master.com, -P 8080, -N jnlp-agent-1, -D /home/jenkins/agent, -j /run/secrets/01-06-19-jnlp-agent-1"

     echo -e "${JNLP_TAGS}"
}

## AUXILIARY FUNCTIONS ##
error_out() {

  echo -e "
  ####################      ERROR - $2 ####################

  $1

  ####################      ERROR      ####################" 1>&2

  sleep 3
}

var_is_empty() {

  error_msg="${1}"
  error_code="${2}"
  arg="${3}"

  if [[ -z ${arg} ]]
  then
    error_out "${error_msg}" "${error_code}"

  fi
}

## Add command to array
add_cmd_to_array() {

  if [[ -n "${2}" ]]
  then
    commands["${1}"]="${4} ${2}"
  elif [[ -n "${3}" ]]
  then
    commands["${1}"]="${4} ${3}"
  fi
}

env_var_arg_no_match() {

  error_msg="${1}"
  error_code="${2}"
  arg="${3}"
  env_var="${4}"

  if [[ -n ${arg} ]] && [[ -n ${env_var} ]] && [[ ${arg} != "${env_var}" ]]
  then
    error_out "${error_msg}" "${error_code}"

    exit "$2"
  fi
}

write_key() {
  mkdir -p "${JENKINS_AGENT_HOME}/.ssh"
  echo "$1" > "${JENKINS_AGENT_HOME}/.ssh/authorized_keys"
  chown -Rf "${user}":"${group}" "${JENKINS_AGENT_HOME}/.ssh"
  chmod 0700 -R "${JENKINS_AGENT_HOME}/.ssh"
}

## COMMANDLINE ARG SETTERS ##

## U | --jenkinsUrl
set_jenkins_url() {

  no_arg_msg="You have not supplied an agent URL when one was expected.
  Please ensure you pass the url of the Jenkins Master as an argument to -U or --jenkinsUrl
  Alternatively you can set set the 'JENKINS_URL' Environment variable in the container."

  if [[ -z "$1" ]] && [[ -z "$JENKINS_URL" ]]
  then
    error_out "${no_arg_msg}" 10
    exit 10
  fi

  no_match_msg="You have provided a url for the Jenkins Master in the start up command and in an
  Environment variable and they do not match. Please supply only one Jenkins Master url"

  env_var_arg_no_match "$no_match_msg" 15 "$1" "$JENKINS_URL"

  add_cmd_to_array  "jenkins_url" "$1" "$JENKINS_URL" "-url"
}

## P | --jenkinsPort
set_jenkins_port() {

  no_arg_msg="You have not supplied a port for the Jenkins Master when one was expected. 
  Please ensure you pass the port number of the Jenkins Master as an argument to -P or --jenkinsPort 
  Alternatively you can set set the 'JENKINS_PORT' Environment variable in the container."

  if [[ -z "$1" ]] && [[ -z "$JENKINS_PORT" ]]
  then
    error_out "${no_arg_msg}" 20
    exit 20
  fi

  no_match_msg="You have provided a port number for the Jenkins Master in the start up command and in an 
  environment variable and they do not match. Please supply only one Jenkins Master port number"

  env_var_arg_no_match "$no_match_msg" 25 "$1" "$JENKINS_PORT"

  add_cmd_to_array  "jenkins_port" "$1" "$JENKINS_PORT"
}
## P | --jenkinsTunnel
set_jenkins_tunnel() {

  no_arg_msg="You have not supplied a tunnel for the Jenkins Master when one was expected. 
  Please ensure you pass the host url and port number of the tunnel to the Jenkins Master as an
  argument to -P or --jenkinsTunnel. Alternatively you can set set the 'JENKINS_TUNNEL' 
  environment variable in the container."

  if [[ -z "$1" ]] && [[ -z "$JENKINS_TUNNEL" ]]
  then
    error_out "${no_arg_msg}" 20
    exit 20
  fi

  no_match_msg="You have provided a tunnel for the Jenkins Master in the start up command and in an
  environment variable and they do not match. Please supply only one tunnel to the Jenkins Master"

  env_var_arg_no_match "$no_match_msg" 25 "$1" "$JENKINS_TUNNEL"

  add_cmd_to_array  "jenkins_tunnel" "$1" "$JENKINS_TUNNEL" "-tunnel"
}
## N | --jenkinsAgentName
set_jenkins_agent_name() {

  no_arg_msg="You have not supplied an agent name when one was expected. Please ensure you pass the name of the agent
  defined on the Jenkins Master as an argument to -N or --jenkinsAgentName Alternatively you can set set the
  'JENKINS_AGENT_NAME' Environment variable in the container."

  if [[ -z "$1" ]] && [[ -z "$JENKINS_AGENT_NAME" ]]
  then
    error_out "${no_arg_msg}" 30
    exit 30
  fi

  no_match_msg="You have provided an agent name for the Jenkins Master in the start up command and in an 
  environment variable and they do not match. Please supply only one Jenkins agent name"

  env_var_arg_no_match "$no_match_msg" 35 "$1" "$JENKINS_AGENT_NAME"

  add_cmd_to_array  "jenkins_agent_name" "$1" "$JENKINS_AGENT_NAME"
}
## D | --jenkinsAgentWorkdir
set_jenkins_agent_workdir() {

  no_arg_msg="You have not supplied an agent work directory when one was expected. 
  Please ensure you pass the agent working directory defined on the Jenkins Master as an argument to -D or --jenkinsAgentWorkdir 
  Alternatively you can set set the 'JENKINS_AGENT_WORKDIR' Environment variable in the container."

  if [[ -z "$1" ]] && [[ -z "$JENKINS_AGENT_WORKDIR" ]]
  then
    error_out "${no_arg_msg}" 40
    exit 40
  fi

  no_match_msg="You have provided an agent working directory for the Jenkins Master in the start up command and in an 
  environment variable and they do not match. Please supply only one Jenkins agent working directory"

  env_var_arg_no_match "$no_match_msg" 45 "$1" "$JENKINS_AGENT_WORKDIR"

  add_cmd_to_array  "jenkins_agent_workdir" "$1" "$JENKINS_AGENT_WORKDIR" "-workDir"
}
## S | --JenkinsAgentSecret
set_jenkins_agent_secret() {

  no_arg_msg="You have not supplied a JNLP agent secret when one was expected. Please ensure you pass the agent
  secret defined on the Jenkins Master as an argument to -S or --jenkinsAgentSecret Alternatively you can set set the
  'JENKINS_AGENT_SECRET' Environment variable in the container."

  if [[ -z "$1" ]] && [[ -z "$JENKINS_AGENT_SECRET" ]]
  then
    error_out "${no_arg_msg}" 50
    exit 50
  fi

  no_match_msg="You have provided an agent secret for the Jenkins Master in the start up command and in an 
  environment variable and they do not match. Please supply only one Jenkins agent secret"

  env_var_arg_no_match "$no_match_msg" 55 "$1" "$JENKINS_AGENT_SECRET"

  add_cmd_to_array  "jenkins_agent_secret" "$1" "$JENKINS_AGENT_SECRET"
}
## J | --dockerAgentSecretName
set_jenkins_agent_docker_secret_name() {

  no_arg_msg="You have not supplied an agent docker secret when one was expected. Please ensure you pass the agent
  docker secret, defined on the SWARM the agent runs in, as an argument to -J or --dockerAgentSecretName Alternatively
  you can set set the 'JENKINS_AGENT_DOCKER_SECRET_NAME' Environment variable in the container."

  if [[ -z "$1" ]] && [[ -z "$JENKINS_AGENT_DOCKER_SECRET_NAME" ]]
  then
    error_out "${no_arg_msg}" 60
    exit 60
  fi

  no_match_msg="You have provided an agent secret for the Jenkins Master in the start up command and in an 
  environment variable and they do not match. Please supply only one Jenkins agent secret"

  env_var_arg_no_match "$no_match_msg" 65 "$1" "$JENKINS_AGENT_DOCKER_SECRET_NAME"

  add_cmd_to_array  "jenkins_agent_docker_secret_name" "$1" "$JENKINS_AGENT_DOCKER_SECRET_NAME"
}
## j | --dockerAgentSecretFile
set_jenkins_agent_docker_secret_file() {

  no_arg_msg="You have not supplied an agent docker secret file url when one was expected. Please ensure you pass the
  agent docker secret file url, defined on the SWARM the agent runs in, as an argument to -j or --dockerAgentSecretFile
  Alternatively you can set set the 'JENKINS_AGENT_DOCKER_SECRET' Environment variable in the container."

  if [[ -z "$1" ]] && [[ -z "$JENKINS_AGENT_DOCKER_SECRET_FILE" ]] && [[ -z $JENKINS_AGENT_DOCKER_SECRET_NAME ]]
  then
    error_out "${no_arg_msg}" 70
    exit 70
  fi

  no_match_msg="You have provided an agent secret for the Jenkins Master in the start up command and in an 
  environment variable and they do not match. Please supply only one Jenkins agent secret"

  env_var_arg_no_match "$no_match_msg" 75 "$1" "$JENKINS_AGENT_DOCKER_SECRET_FILE"

  if [[ -z "$1" ]] && [[ -z "$JENKINS_AGENT_DOCKER_SECRET_FILE" ]] && [[ -n $JENKINS_AGENT_DOCKER_SECRET_NAME ]]
  then
    JENKINS_AGENT_DOCKER_SECRET_FILE="/run/secrets/${JENKINS_AGENT_DOCKER_SECRET_NAME}"
  fi

  add_cmd_to_array  "jenkins_agent_docker_secret_file" "$1" "$JENKINS_AGENT_DOCKER_SECRET_FILE"
}
## K | --jenkinsMasterPubkey
set_jenkins_master_pubkey() {

  no_arg_msg="You have not supplied a Jenkins Master public key when one was expected. Please ensure you pass the
  Jenkins Master Public Key as an argument to -K or --jenkinsMasterPubkey. Alternatively you can set set the
  'JENKINS_MASTER_PUBKEY' Environment variable in the container."

  if [[ -z "$1" ]] && [[ -z "$JENKINS_MASTER_PUBKEY" ]]
  then
    error_out "${no_arg_msg}" 80
    exit 80
  fi

  no_match_msg="You have provided the agent with a Jenkins Master Public Key in the start up command and in an 
  environment variable and they do not match. Please supply only one Jenkins Master Public Key"

  env_var_arg_no_match "$no_match_msg" 85 "$1" "$JENKINS_MASTER_PUBKEY"

  if [[ -n "$1" ]]; then JENKINS_MASTER_PUBKEY=$1; fi

  if [[ $JENKINS_MASTER_PUBKEY == ssh-* ]]; then
    write_key "${JENKINS_MASTER_PUBKEY}"
  fi

  add_cmd_to_array  "jenkins_master_pubkey" "$JENKINS_MASTER_PUBKEY" ""

  # ensure variables passed to docker container are also exposed to ssh sessions
  env | grep _ >> /etc/environment

  ssh-keygen -A
  exec /usr/sbin/sshd -D -e "${@}"
}


## ENVIRONMENT VARIABLE SETTERS ##

set_jnlp() {

  if [ -z "$JNLP_PROTOCOL_OPTS" ]
  then

    msg="Warning: JnlpProtocol3 is disabled by default, set JNLP_PROTOCOL_OPTS ENVIRONMENT VARIABLE as follows
    to enable or disable it:

    JNLP_PROTOCOL_OPTS= -Dorg.jenkinsci.remoting.engine.JnlpProtocol3.disabled=false

    JNLP_PROTOCOL_OPTS=\"-Dorg.jenkinsci.remoting.engine.JnlpProtocol3.disabled=true\""

    echo -e "${msg}" 1>&2

  elif [ -n "$JNLP_PROTOCOL_OPTS" ]
  then
    msg="The JNLP 3 Protocol is enabled."

    echo -e "${msg}" 1>&2
  fi

  add_cmd_to_array  "jnlp_protocol" "$JNLP_PROTOCOL_OPTS" ""
}

set_java_home() {

  if [ -z "$JAVA_HOME" ]
  then
    error_msg="JAVA_HOME is not set. Please ensure that a Java JDK or JRE is installed and that the JAVA_HOME 
    environment variable is set to its' installation directory."

    var_is_empty "$error_msg" 100 "$JAVA_HOME"

  elif [ -n "$JAVA_HOME" ]
  then

    JAVA_BIN="$JAVA_HOME/bin/java"

    add_cmd_to_array  "java_bin" "$JAVA_BIN" ""

    msg="JAVA_BIN is set to: ${JAVA_BIN}."

    echo -e "${msg}" 1>&2
  fi
}

parse_command_line_args() {
    while (( "$#" )); do
      case "$1" in
        -U | --jenkinsUrl)
          set_jenkins_url "$2"
          shift 2
          ;;
        -P | --jenkinsPort)
          set_jenkins_port "$2"
          shift 2
          ;;
        -T | --jenkinsTunnel)
          set_jenkins_tunnel "$2"
          shift 2
          ;;
        -N | --jenkinsAgentName)
          set_jenkins_agent_name "$2"
          shift 2
          ;;
        -D | --jenkinsAgentWorkdir)
          set_jenkins_agent_workdir "$2"
          shift 2
          ;;
        -S | --JenkinsAgentSecret)
          set_jenkins_agent_secret "$2"
          shift 2
          ;;
        -J | --dockerAgentSecretName)
          set_jenkins_agent_docker_secret_name "$2"
          shift 2
          ;;
        -j | --dockerAgentSecretFile)
          set_jenkins_agent_docker_secret_file "$2"
          shift 2
          ;;
        -K | --jenkinsMasterPubkey)
          set_jenkins_master_pubkey "$2"
          shift 2
          ;;
        -H | --help)
          help
          shift 2
          ;;
        --) # end argument parsing
          shift
          break
          ;;
        *) # unsupported flags
          command="$1 "
          command+="$2 "
          exec "${command}"
          PARAMS="$PARAMS $1"
          shift
          exit 1
          ;;
      esac
    done
    # set positional arguments in their proper place
    eval set -- "$PARAMS"

    echo "I'm parsing!"
}

command=""

build_command() {

  ${ordered_list} = ${1}

  while [[ ${#commands[@]} -gt 0 ]]
  do
    for i in "${ordered_list[@]}"
    do
      if
    done
  done


}

if [[ -z "$JAVA_HOME" ]] || [[ -z "$JAVA_OPTS" ]] || [[ -z "$JNLP_PROTOCOL_OPTS" ]] || [[ -z "$JENKINS_URL" ]] ||
     [[ -z "$JENKINS_AGENT_WORKDIR" ]] || [[ -z "$JENKINS_AGENT_SECRET" ]] || [[ -z "$JENKINS_AGENT_NAME" ]]
then

  parse_command_line_args "$@"

elif [[ -n "$JAVA_HOME" ]] && [[ -n "$JAVA_OPTS" ]] && [[ -n "$JNLP_PROTOCOL_OPTS" ]] && [[ -n "$JENKINS_URL" ]] &&
     [[ -n "$JENKINS_AGENT_WORKDIR" ]] && [[ -n "$JENKINS_AGENT_SECRET" ]] && [[ -n "$JENKINS_AGENT_NAME" ]]
then

  echo "$JAVA_BIN" "$JAVA_OPTS" "$JNLP_PROTOCOL_OPTS" -cp /usr/share/jenkins/agent.jar hudson.remoting.jnlp.Main -headless \
                      "$JENKINS_TUNNEL" "$JENKINS_URL" "$JENKINS_AGENT_WORKDIR" "$JENKINS_AGENT_SECRET" "$JENKINS_AGENT_NAME" "$@"

  exec "$JAVA_BIN" "$JAVA_OPTS" "$JNLP_PROTOCOL_OPTS" -cp /usr/share/jenkins/agent.jar hudson.remoting.jnlp.Main -headless \
                      "$JENKINS_TUNNEL" "$JENKINS_URL" "$JENKINS_AGENT_WORKDIR" "$JENKINS_AGENT_SECRET" "$JENKINS_AGENT_NAME" "$@"
#  exit "$?"
fi
