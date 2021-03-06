#!/bin/bash
set -o pipefail
IFS=$'\n\t'

DOCKER_SOCKET=/var/run/docker.sock

if [ ! -e "${DOCKER_SOCKET}" ]; then
  echo "Docker socket missing at ${DOCKER_SOCKET}"
  exit 1
fi

if [ -n "${OUTPUT_IMAGE}" ]; then
  TAG="${OUTPUT_REGISTRY}/${OUTPUT_IMAGE}"
fi

if [[ "${SOURCE_REPOSITORY}" != "git://"* ]] && [[ "${SOURCE_REPOSITORY}" != "git@"* ]]; then
  URL="${SOURCE_REPOSITORY}"
  if [[ "${URL}" != "http://"* ]] && [[ "${URL}" != "https://"* ]]; then
    URL="https://${URL}"
  fi
  
  curl --head --silent --fail --location --max-time 16 $URL > /dev/null
  if [ $? != 0 ]; then
    echo "Could not access source url: ${SOURCE_REPOSITORY}"
    exit 1
  fi
fi


BUILD_DIR=$(mktemp --directory)
cp /tmp/Dockerfile ${BUILD_DIR}
pushd "${BUILD_DIR}"
wget -r -nd -l 1 -A.war ${SOURCE_REPOSITORY}/war > /dev/null
curl -O --noproxy '*' http://btln000532.corp.ads:8080/trust/TrustKeystore-Non-Prod.jks

mkdir ${SOURCE_CONTEXT_DIR}
pushd ${SOURCE_CONTEXT_DIR}
wget -r -nd -l 1 -A.xml ${SOURCE_REPOSITORY}/conf > /dev/null

#  git clone --recursive "${SOURCE_REPOSITORY}" "${BUILD_DIR}"
if [ $? != 0 ]; then
  echo "Error trying to fetch application from: ${SOURCE_REPOSITORY}"
  exit 1
fi
  
#  git checkout "${SOURCE_REF}"
#  if [ $? != 0 ]; then
#    echo "Error trying to checkout branch: ${SOURCE_REF}"
#    exit 1
#  fi
popd
popd

#Merge the push/pull secrets into a single config.json file
mkdir -p /root/.docker
#echo "{ \"auths\": " > /root/.docker/config.json
#cat /var/run/secrets/openshift.io/pull/.dockercfg >> /root/.docker/config.json
#echo "," > /root/.docker/config.json
#cat /var/run/secrets/openshift.io/push/.dockercfg >> /root/.docker/config.json
#echo "}" >> /root/.docker/config.json

if [[ -d /var/run/secrets/openshift.io/pull ]] && [[ ! -e /root/.docker/config.json ]]; then
#  cp /var/run/secrets/openshift.io/pull/.dockercfg /root/.docker/config.json
  echo "{ \"auths\": " > /root/.docker/config.json
  cat /var/run/secrets/openshift.io/pull/.dockercfg >> /root/.docker/config.json
  echo "}" >> /root/.docker/config.json
fi

docker build --rm --build-arg appCtx=${SOURCE_CONTEXT_DIR} -t "${TAG}" "${BUILD_DIR}"

if [[ -d /var/run/secrets/openshift.io/push ]] ; then
#  cp /var/run/secrets/openshift.io/push/.dockercfg /root/.docker/config.json
  echo "{ \"auths\": " > /root/.docker/config.json
  cat /var/run/secrets/openshift.io/push/.dockercfg >> /root/.docker/config.json
  echo "}" >> /root/.docker/config.json
fi

if [ -n "${OUTPUT_IMAGE}" ] || [ -s "/root/.docker/config.json" ]; then
  docker push "${TAG}"
fi
