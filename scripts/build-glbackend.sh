#!/bin/bash
GLOBALEAKS_DIR="$(readlink -f `dirname ${BASH_SOURCE[0]}`/..)"
. ${GLOBALEAKS_DIR}/scripts/common_inc.sh

usage()
{
cat << EOF
usage: ./${SCRIPTNAME} options

OPTIONS:
   -h      Show this message
   -v      To build a tagged release
   -n      To build a non signed package
   -y      Assume 'yes' to all questions

EOF
}

SIGN=1
AUTOYES=0
while getopts “hv:ny” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    v)
      TAG=$OPTARG
      ;;
    n)
      SIGN=0
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

auto_setup_env()
{
  cd ${BUILD_DIR}
  if [ -d ${GLBACKEND_TMP} ]; then
    echo "[+] Removing ${GLBACKEND_TMP}"
    rm -rf ${GLBACKEND_TMP}
  fi
  if [ -d ${GLBACKEND_DIR} ]; then
    echo "[+] Copying existent ${GLBACKEND_DIR} in ${GLBACKEND_TMP}"
    cp ${GLBACKEND_DIR} ${GLBACKEND_TMP} -r
  else
    echo "[+] Cloning GLBackend in ${GLBACKEND_TMP}"
    git clone $GLBACKEND_GIT_REPO ${GLBACKEND_TMP}
  fi
}

interactive_setup_env()
{
  cd ${BUILD_DIR}
  if [ -d ${GLBACKEND_TMP} ]; then
    echo "Directory ${GLBACKEND_TMP} already present and need to be removed"
    ANSWER=''
    until [[ $ANSWER = [yn] ]]; do
      read -n1 -p "Do you want to delete ${GLBACKEND_TMP}? (y/n): " ANSWER
      echo
    done
    if [[ $ANSWER != 'y' ]]; then
      echo "Cannot proceed"
      exit
    fi
    rm -rf ${GLBACKEND_TMP}
  fi
  if [ -d ${GLBACKEND_DIR} ]; then
    echo "Directory ${GLBACKEND_DIR} already present. Can be used as package source"
    ANSWER=''
    until [[ $ANSWER = [yn] ]]; do
      read -n1 -p "Do you want to use the existing repository from ${GLBACKEND_DIR} (y/n): " ANSWER
      echo
    done
    if [[ $ANSWER != 'y' ]]; then
      echo "[+] Cloning GLBackend in ${GLBACKEND_TMP}"
      git clone $GLBACKEND_GIT_REPO ${GLBACKEND_TMP}
    else
      echo "[+] Copying existent ${GLBACKEND_DIR} in ${GLBACKEND_TMP}"
      cp ${GLBACKEND_DIR} ${GLBACKEND_TMP} -r
      USING_EXISTENT_DIR=1
    fi
  else
    echo "[+] Cloning GLBackend in ${GLBACKEND_TMP}"
    git clone $GLBACKEND_GIT_REPO ${GLBACKEND_TMP}
  fi
}

build_glbackend()
{
  cd ${GLBACKEND_TMP}

  if test ${USING_EXISTENT_DIR}; then
    echo "Using GLBackend existent directory and respective HEAD"
  else
    if test $TAG; then
      echo "Using a clean cloned GLBackend directory"
      echo "Checking out $TAG (if existent, using master HEAD instead)"
      git checkout $TAG >& /dev/null || git checkout HEAD >& /dev/null
    fi
  fi

  GLBACKEND_REVISION=`git rev-parse HEAD | cut -c 1-8`

  echo "Revision used: ${GLBACKEND_REVISION}"

  if [ "${TRAVIS}" == "true" ]; then
    sudo pip install -r requirements.txt
  fi

  unzip ${GLC_BUILD}/*.zip -d .
  mv glclient-*/* glclient/

  echo "[+] Building GLBackend"
  POSTINST=debian/postinst
  echo "/etc/init.d/globaleaks start" >> $POSTINST
  echo "# generated by your friendly globaleaks build bot :)" >> $POSTINST
  echo "[+] Building .deb"

  if [ $SIGN -eq 1 ]; then
    debuild
  else
    debuild -i -us -uc -b
  fi

}

if [ $AUTOYES -eq 1 ]; then
  auto_setup_env
else
  interactive_setup_env
fi
build_glbackend

echo "[+] All done!"
echo ""
echo "GLBackend build is now present in ${GLOBALEAKS_DIR}"
