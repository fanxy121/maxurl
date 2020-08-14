#!/bin/bash

cd "$(dirname "$(readlink -f "$0")")"

get_userscript_version() {
    cat $1 | grep '@version *[0-9.]* *$' | sed 's/.*@version *\([0-9.]*\) *$/\1/g'
}

USERVERSION=`get_userscript_version userscript.user.js`
MANIFESTVERSION=`cat manifest.json | grep '"version": *"[0-9.]*", *$' | sed 's/.*"version": *"\([0-9.]*\)", *$/\1/g'`

if [ -z "$USERVERSION" -o -z "$MANIFESTVERSION" ]; then
    echo Broken version regex
    exit 1
fi

if [ "$USERVERSION" != "$MANIFESTVERSION" ]; then
    echo 'Conflicting versions (userscript and manifest)'
    exit 1
fi

if [ -f ./gen_minified.js ]; then
    node ./gen_minified.js
    MINVERSION=`get_userscript_version userscript_min.user.js`

    if [ "$MINVERSION" != "$USERVERSION" ]; then
        echo 'Conflicting versions (userscript and minified)'
        exit 1
    fi
else
    echo "Warning: gen_minified.js not available, skipping OpenUserJS minified version of the userscript"
fi

if [ -d site ]; then
    echo "Updating website files"
    cp site/style.css extension/options.css
    cp userscript_smaller.user.js site/
else
    echo "Warning: website is not available, skipping website build"
fi

echo
echo Creating extension readme file

cat << EOF > EXTENSION_README.txt
The only machine-generated part of this extension is in 3rd-party libraries.
To build them, run ./lib/build_libs.sh
To build the extension, run ./package_extension.sh

Below are the versions of the programs used to generate this extension:

---

EOF

separator() {
    echo >> "$1"
    echo "---" >> "$1"
    echo >> "$1"
}

unzip -v >> EXTENSION_README.txt
separator EXTENSION_README.txt
zip -v >> EXTENSION_README.txt
separator EXTENSION_README.txt
dos2unix --version >> EXTENSION_README.txt
separator EXTENSION_README.txt
unix2dos --version >> EXTENSION_README.txt
separator EXTENSION_README.txt
wget --version >> EXTENSION_README.txt
separator EXTENSION_README.txt
patch --version >> EXTENSION_README.txt
separator EXTENSION_README.txt
sed --version >> EXTENSION_README.txt
separator EXTENSION_README.txt

echo
echo Building Firefox extension

BASEFILES="LICENSE.txt manifest.json userscript.user.js lib/testcookie_slowaes.js lib/cryptojs_aes.js lib/hls.js lib/dash.all.debug.js resources/logo_40.png resources/logo_48.png resources/logo_96.png resources/disabled_40.png resources/disabled_48.png resources/disabled_96.png extension"
SOURCEFILES="lib/aes1.patch lib/aes_shim.js lib/cryptojs_aes_shim.js lib/dash_shim.js lib/hls_shim.js lib/build_libs.sh EXTENSION_README.txt package_extension.sh"

zipcmd() {
    echo
    echo "Building extension package: $1"
    echo

    zip -r "$1" $BASEFILES -x "*~"
}

zipsourcecmd() {
    echo
    echo "Building source package: $1"
    echo

    zip -r "$1" $BASEFILES $SOURCEFILES -x "*~"
}

rm extension.xpi
zipcmd extension.xpi

getzipfiles() {
    unzip -l "$1" | awk '{print $4}' | awk 'BEGIN{x=0;y=0} /^----$/{x=1} {if (x==1) {x=2} else if (x==2) {print}}' | sed '/^ *$/d' | sort
}

FILES=$(getzipfiles extension.xpi)
echo "$FILES" > files.txt

cat <<EOF > files1.txt
extension/
extension/background.js
extension/options.css
extension/options.html
extension/popup.html
extension/popup.js
#-EXTENSION_README.txt
#-lib/aes1.patch
#-lib/aes_shim.js
#-lib/build_libs.sh
lib/cryptojs_aes.js
#-lib/cryptojs_aes_shim.js
lib/dash.all.debug.js
#-lib/dash_shim.js
lib/hls.js
#-lib/hls_shim.js
lib/testcookie_slowaes.js
LICENSE.txt
manifest.json
#-package_extension.sh
resources/disabled_40.png
resources/disabled_48.png
resources/disabled_96.png
resources/logo_40.png
resources/logo_48.png
resources/logo_96.png
userscript.user.js
EOF

sed 's/^#-//g' files1.txt > files1_source.txt
sed -i '/^#-/d' files1.txt

diffzipfiles() {
    cat $1 $2 | sort | uniq -u
}

DIFF="$(diffzipfiles files.txt files1.txt)"
if [ ! -z "$DIFF" ]; then
    echo
    echo 'Wrong files for firefox extension'
    exit 1
fi

rm extension_source.zip
zipsourcecmd extension_source.zip

FILES=$(getzipfiles extension_source.zip)
echo "$FILES" > files.txt

DIFF="$(diffzipfiles files.txt files1_source.txt)"
if [ ! -z "$DIFF" ]; then
    echo
    echo 'Wrong files for source package'
    exit 1
fi

rm files.txt
rm files1.txt
rm files1_source.txt


if [ -f ./maxurl.pem ]; then
    echo
    echo Building chrome extension
    # This is based on http://web.archive.org/web/20180114090616/https://developer.chrome.com/extensions/crx#scripts

    name=maxurl
    crx="$name.crx"
    pub="$name.pub"
    sig="$name.sig"
    zip="$name.zip"
    key="$name.pem"

    rm $zip $pub $sig
    zipcmd $zip

    # signature
    openssl sha1 -sha1 -binary -sign "$key" < "$zip" > "$sig"

    # public key
    openssl rsa -pubout -outform DER < "$key" > "$pub" 2>/dev/null

    byte_swap () {
    # Take "abcdefgh" and return it as "ghefcdab"
    echo "${1:6:2}${1:4:2}${1:2:2}${1:0:2}"
    }

    crmagic_hex="4372 3234" # Cr24
    version_hex="0200 0000" # 2
    pub_len_hex=$(byte_swap $(printf '%08x\n' $(ls -l "$pub" | awk '{print $5}')))
    sig_len_hex=$(byte_swap $(printf '%08x\n' $(ls -l "$sig" | awk '{print $5}')))
    (
    echo "$crmagic_hex $version_hex $pub_len_hex $sig_len_hex" | xxd -r -p
    cat "$pub" "$sig" "$zip"
    ) > "$crx"
else
    echo "Warning: skipping chrome extension build"
fi

echo
echo "Release checklist:"
echo
echo ' * Ensure xx00+ count is updated (userscript - greasyfork/oujs, reddit post, mozilla/opera, website)'
echo ' * Update greasyfork, oujs, firefox, opera, changelog.txt'
echo ' * git tag v'$USERVERSION
echo ' * Update userscript.user.js for site (but check about.js for site count before)'
echo ' * Update CHANGELOG.txt and Discord changelog'
