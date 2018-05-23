#!/bin/bash

NAME_ROOT=electrum-mac
PYTHON_VERSION=3.5.4

# These settings probably don't need any change
export WINEPREFIX=/opt/wine64
export PYTHONDONTWRITEBYTECODE=1
export PYTHONHASHSEED=22

PYHOME=c:/python$PYTHON_VERSION
PYTHON="wine $PYHOME/python.exe -OO -B"


# Let's begin!
cd `dirname $0`
set -e

mkdir -p tmp
cd tmp

if [ -d ./electrum-mac ]; then
  rm ./electrum-mac -rf
fi

git clone https://github.com/pooler/electrum-mac -b master

pushd electrum-mac
if [ ! -z "$1" ]; then
    git checkout $1
fi

# Load electrum-icons and electrum-locale for this release
git submodule init
git submodule update

pushd ./contrib/deterministic-build/electrum-mac-locale
for i in ./locale/*; do
    dir=$i/LC_MESSAGES
    mkdir -p $dir
    msgfmt --output-file=$dir/electrum.mo $i/electrum.po || true
done
popd

VERSION=`git describe --tags --dirty`
echo "Last commit: $VERSION"
find -exec touch -d '2000-11-11T11:11:11+00:00' {} +
popd

rm -rf $WINEPREFIX/drive_c/electrum-mac
cp -r electrum-mac $WINEPREFIX/drive_c/electrum-mac
cp electrum-mac/LICENCE .
cp -r ./electrum-mac/contrib/deterministic-build/electrum-mac-locale/locale $WINEPREFIX/drive_c/electrum-mac/lib/
cp ./electrum-mac/contrib/deterministic-build/electrum-mac-icons/icons_rc.py $WINEPREFIX/drive_c/electrum-mac/gui/qt/

# Install frozen dependencies
$PYTHON -m pip install -r ../../deterministic-build/requirements.txt

$PYTHON -m pip install -r ../../deterministic-build/requirements-hw.txt

pushd $WINEPREFIX/drive_c/electrum-mac
$PYTHON setup.py install
popd

cd ..

rm -rf dist/

# build standalone and portable versions
wine "C:/python$PYTHON_VERSION/scripts/pyinstaller.exe" --noconfirm --ascii --name $NAME_ROOT-$VERSION -w deterministic.spec

# set timestamps in dist, in order to make the installer reproducible
pushd dist
find -exec touch -d '2000-11-11T11:11:11+00:00' {} +
popd

# build NSIS installer
# $VERSION could be passed to the electrum.nsi script, but this would require some rewriting in the script itself.
wine "$WINEPREFIX/drive_c/Program Files (x86)/NSIS/makensis.exe" /DPRODUCT_VERSION=$VERSION electrum.nsi

cd dist
mv electrum-mac-setup.exe $NAME_ROOT-$VERSION-setup.exe
cd ..

echo "Done."
md5sum dist/electrum*exe
