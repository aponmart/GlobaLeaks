#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/common_inc.sh

usage()
{
cat << EOF
usage: ./${SCRIPTNAME} options

OPTIONS:
   -h      Show this message
   -v      To build a tagged release
   -y      To assume yes to all queries

EOF
}

while getopts “yhv:” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    v)
      TAG=$OPTARG
      ;;
    y)
      AUTOYES=1
      ;;
    ?)
      usage
      exit
      ;;
    esac
done

auto_env_setup()
{
  cd ${BUILD_DIR}
  if [ -d ${GLCLIENT_TMP} ]; then
    echo "[+] detected and removing ${GLCLIENT_TMP}"
    rm -rf ${GLCLIENT_TMP} 
  fi
  if [ -d ${GLCLIENT_DIR} ]; then
    echo "[+] detected source repository in ${GLCLIENT_DIR}"
    cp ${GLCLIENT_DIR} ${GLCLIENT_TMP} -r
  else
    echo "[+] Cloning GLClient in ${GLCLIENT_TMP}"
    git clone $GLCLIENT_GIT_REPO ${GLCLIENT_TMP}
  fi
}

interactive_env_setup()
{
  cd ${BUILD_DIR}
  if [ -d ${GLCLIENT_TMP} ]; then
    echo "Directory ${GLCLIENT_TMP} already present and need to be removed"
    read -n1 -p "Do you want to delete ${GLCLIENT_TMP}? (y/n): "
    echo
    if [[ $REPLY != [yY] ]]; then
      echo "Cannot proceed"
      exit
    fi
    rm -rf ${GLCLIENT_TMP} 
  fi
  if [ -d ${GLCLIENT_DIR} ]; then
    echo "Directory ${GLCLIENT_DIR} already present. "
    read -n1 -p "Do you want to use the existent ${GLCLIENT_DIR}? (y/n): "
    echo
    if [[ $REPLY != [yY] ]]; then
      echo "[+] Cloning GLClient in ${GLCLIENT_TMP}"
      git clone $GLCLIENT_GIT_REPO ${GLCLIENT_TMP}
    else
      echo "[+] Copying existent ${GLCLIENT_DIR} in ${GLCLIENT_TMP}"
      cp ${GLCLIENT_DIR} ${GLCLIENT_TMP} -r
    fi
  else
    echo "[+] Cloning GLClient in ${GLCLIENT_TMP}"
    git clone $GLCLIENT_GIT_REPO ${GLCLIENT_TMP}
  fi
}

build_glclient()
{
  cd ${GLCLIENT_TMP}
  
  if test $TAG; then
    git checkout $TAG
    GLCLIENT_REVISION=$TAG
  else
    GLCLIENT_REVISION=`git rev-parse HEAD | cut -c 1-8`
  fi

  if [ -f ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.tar.gz ]; then
    echo "${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.tar.gz already present"
    exit
  fi

  if [ -f ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.zip ]; then
    echo "${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.zip already present"
    exit
  fi

  echo "[+] Building GLClient"
  npm install -d
  grunt build --force

  mkdir -p ${GLC_BUILD}

  echo "[+] Creating compressed archives"
  mv build glclient-${GLCLIENT_REVISION}
  tar czf ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.tar.gz glclient-${GLCLIENT_REVISION}/
  md5sum ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.tar.gz > ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.tar.gz.md5.txt
  sha1sum ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.tar.gz > ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.tar.gz.sha1.txt
  shasum -a 224 ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.tar.gz > ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.tar.gz.sha224.txt

  zip -r ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.zip glclient-${GLCLIENT_REVISION}/
  md5sum ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.zip > ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.zip.md5.txt
  sha1sum ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.zip > ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.zip.sha1.txt
  shasum -a 224 ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.zip > ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.zip.sha224.txt
}

if [ $AUTOYES ]; then
  auto_env_setup
else
  interactive_env_setup
fi
build_glclient

echo "[+] All done!"
echo ""
echo "GLClient build is now present in ${GLC_BUILD}"
echo "GLClient hash: "
cat ${GLC_BUILD}/glclient-${GLCLIENT_REVISION}.zip.sha224.txt
