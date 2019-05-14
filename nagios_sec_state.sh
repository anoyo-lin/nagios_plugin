#!/bin/bash
#set -x
TMP='/usr/lib/nagios/plugins/ss_xml_md5'
USER='redacted'
PASSWD='redacted'
URI='redacted'
PROXY='redacted'

PROGNAME=`basename $0`
VERSION="Version 1.0,"
AUTHOR="2019, Lin, Gene"

ST_OK=0
ST_WR=1
ST_CR=2
ST_UK=3

print_version() {
    echo "$VERSION $AUTHOR"
}

print_help() {
    print_version $PROGNAME $VERSION
    echo ""
    echo ""
    echo "$PROGNAME"
    exit $ST_UK
}

while test -n "$1"; do
    case "$1" in
        -help|-h)
            print_help
            exit $ST_UK
            ;;
        --version|-v)
            print_version $PROGNAME $VERSION
            exit $ST_UK
            ;;
        *)
            echo "Unknown argument: $1"
            print_help
            exit $ST_UK
            ;;
        esac
    shift
done

main() {
	if  [ ! -f $TMP ]; then
		mkdir -p /usr/lib/nagios/plugins/
		curl -u "$USER:$PASSWD" -x $PROXY $URI|md5sum > $TMP
		exit $ST_OK
	else
		new_md5=$(curl -u "$USER:$PASSWD" -x $PROXY $URI|md5sum)
		if [[ "$(cat $TMP)" == "$new_md5" ]]; then
			echo "no_change"
			exit $ST_OK
		else
			echo "change"
			mv $TMP $TMP.$(date +%Y%m%d%H%M%S)
			echo $new_md5 > $TMP
			exit $ST_CR
		fi
	fi
}

main 
