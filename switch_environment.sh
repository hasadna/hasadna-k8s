#!/usr/bin/env bash

# this script can run using source - to enable keeping the environment variables and shell completion
#
# please pay attention not to call exit in this script - as it might exit from the user's shell
#
# thanks for your understanding and cooperation

! which kubectl >/dev/null && echo "attempting automatic installation of kubectl" && gcloud --quiet components install kubectl
! which helm >/dev/null && echo "attempting automatic installation of helm" && bash apps_travis_script.sh install_helm
! which dotenv >/dev/null && echo "attempting automatic installation of python-dotenv" && sudo pip install 'python-dotenv[cli]'
! which jq >/dev/null && echo "attempting automatic installation of jq" && sudo apt-get update && sudo apt-get install -y jq

if which dotenv >/dev/null && which helm >/dev/null && which kubectl >/dev/null && which jq >/dev/null; then
  if [ "${1}" == "" ]; then
      echo "source switch_environment.sh <ENVIRONMENT_NAME> [environment_label]"
  else
  	ENVIRONMENT_NAME="${1}"
  	export K8S_ENVIRONMENT_LABEL="${2}"
  	[ -f .env ] && eval `dotenv -f ".env" list`
  	if [ ! -f "environments/${ENVIRONMENT_NAME}/.env" ]; then
  	  if [ "${KUBECONFIG}" == "" ]; then
        echo "Missing KUBECONFIG env var, example usage:"
        echo "  export KUBECONFIG=/path/to/.kubeconfig"
        echo "  source switch_environment.sh ${ENVIRONMENT_NAME} ${K8S_ENVIRONMENT_LABEL}"
      else
        echo "Switching to ${ENVIRONMENT_NAME} ${K8S_ENVIRONMENT_LABEL} environment"
        rm -f .env
        ! echo "CLOUDSDK_CORE_PROJECT=
CLOUDSDK_CONTAINER_CLUSTER=
CLOUDSDK_COMPUTE_ZONE=
K8S_NAMESPACE=${ENVIRONMENT_NAME}
K8S_HELM_RELEASE_NAME=${ENVIRONMENT_NAME}
K8S_OVERRIDE_HELM_RELEASE_NAME=
K8S_ENVIRONMENT_NAME=${ENVIRONMENT_NAME}
K8S_ENVIRONMENT_CONTEXT=
K8S_DEFAULT_ENVIRONMENT_LABEL=" > .env && echo "Failed to create .env file"
        source connect.sh
      fi
  	else
  		echo "Switching to ${ENVIRONMENT_NAME} ${K8S_ENVIRONMENT_LABEL} environment"
  		rm -f .env
  		if ! ln -s "`pwd`/environments/${ENVIRONMENT_NAME}/.env" ".env"; then
  			echo "Failed to symlink .env file"
  		else
  			source connect.sh
  		fi
  	fi
  fi
else
  echo "Failed to install dependencies, please try to install manually"
fi
