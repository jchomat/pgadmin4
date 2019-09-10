#!/usr/bin/env bash

set -x

export MACOSX_DEPLOYMENT_TARGET=10.10

DIR=$(pwd)
BUILD_DIR=${DIR}/mac-build
if  [ -d ${BUILD_DIR} ]; then
    rm -rf ${BUILD_DIR}
fi
mkdir -p ${BUILD_DIR}

function fastcp() {
  SRC_DIR=${1}
  PARENT_DIR=$(dirname ${SRC_DIR})
  SRC_FOLDER=$(basename ${SRC_DIR})
  DEST_DIR=${2}

  tar \
    --exclude=node_modules \
    --exclude=out \
    --exclude=dist \
    --exclude=venv \
    --exclude=__pycache__ \
    --exclude=regression \
    --exclude='pgadmin/static/js/generated/.cache' \
    --exclude='.cache' \
    -C ${PARENT_DIR} \
    -cf - ${SRC_FOLDER} | tar -C ${DEST_DIR} -xf -
}

echo "## Copying Electron Folder to the temporary directory..."
fastcp ${DIR}/electron ${BUILD_DIR}

pushd ${BUILD_DIR}/electron > /dev/null
  echo "## Copying pgAdmin folder to the temporary directory..."
  fastcp ${DIR}/web ${BUILD_DIR}/electron

  echo "## Creating Virtual Environment..."
  python3 -m venv --copies ./venv

  # Hack: Copies all python installation files to the virtual environment
  # This was done because virtualenv does not copy all of the files
  # Looks like it assumes that they are not needed or that they should be installed in the system
  echo "  ## Copy all python libraries to the newly created virtual environment"
  PYTHON_LIB_PATH=`dirname $(python -c "import logging;print(logging.__file__)")`/../
  cp -r ${PYTHON_LIB_PATH}* venv/lib/python3.6/

  source ./venv/bin/activate

  echo "## Installs all the dependencies of pgAdmin"
  pip install --no-cache-dir --no-binary psycopg2 -r ${DIR}/requirements.txt

  echo "## Building the Javascript of the application..."
  pushd web > /dev/null
    yarn bundle-app-js
  popd > /dev/null

  echo "## Creating the dmg file..."
  yarn install
  yarn dist:darwin

  python ${DIR}/pkg/mac/dmg-license.py "${BUILD_DIR}/electron/dist/mac/*.dmg"  "${DIR}/pkg/mac/licence.rtf" -c bz2
popd > /dev/null

mkdir -p ${DIR}/dist
cp -f ${BUILD_DIR}/electron/dist/mac/*.dmg ${DIR}/dist/