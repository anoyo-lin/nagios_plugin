#!/bin/bash
#set -x
TMP='/usr/lib/nagios/plugins/mongo_query_tmp'

mongo_cmd() {
    query=$1
	# must use absolute PATH
    echo $(/opt/app/mongodb/bin/mongo --quiet --eval "$query")
    }

diff_func() {
    new=$1
    category=$2
    tmp=$3
    if [[ $(sed -n "s/$category:\([0-9]*\)/\1/p" $tmp) != "" ]]; then
        diff=$(expr $new - $(sed -n "s/$category:\([0-9]*\)/\1/p" $tmp))
        sed -i "s/\($category:\)[0-9]*/\1$new/" $tmp
        echo $diff
    else
        echo "$category:0" >> $tmp
        diff_func $1 $2 $3
    fi
}

write_new_return_diff() {
    category=$1
    case "$category" in
        faults )
            echo $(diff_func $(mongo_cmd 'db.serverStatus()["extra_info"]["page_faults"]') $category "$TMP")
            ;;
        dirty )
            echo $(diff_func $(mongo_cmd 'db.serverStatus()["wiredTiger"]["cache"]["tracked dirty bytes in the cache"]') $category "$TMP")
            ;;
        evicted )
            echo $(diff_func $(mongo_cmd 'db.serverStatus()["wiredTiger"]["cache"]["unmodified pages evicted"] + db.serverStatus()["wiredTiger"]["cache"]["modified pages evicted"]') $category "$TMP")
            ;;
        currently )
            echo $(diff_func $(mongo_cmd 'db.serverStatus()["wiredTiger"]["cache"]["bytes currently in the cache"]') $category "$TMP")
            ;;
        maximum )
            echo $(diff_func $(mongo_cmd 'db.serverStatus()["wiredTiger"]["cache"]["maximum bytes configured"]') $category "$TMP")
            ;;
            * )
            echo -1
            ;;
        esac
}

get_new() {
    category=$1
    echo $(sed -n "s/$category:\([0-9]\)/\1/p" "$TMP")
}

output_msg() {
    echo "Faults: $(write_new_return_diff faults);$(get_new faults), Dirty: $(write_new_return_diff dirty);$(get_new dirty), Evicted: $(write_new_return_diff evicted);$(get_new evicted), Currently: $(write_new_return_diff currently);$(get_new currently), Maximum: $(write_new_return_diff maximum);$(get_new maximum)"
}
output_perfdata() {
	echo "'faults'=$(write_new_return_diff faults) 'dirty'=$(get_new dirty) 'evicted'=$(write_new_return_diff evicted) 'currently'=$(write_new_return_diff currently) 'maximum'=$(write_new_return_diff maximum)"
}

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
    echo "$PROGNAME [-w 10] [-c 20]"
    echo ""
    echo "Options:"
    echo "  -w/--warning)"
    echo "     Defines a warning level for a mongodb which is explained"
    echo "     below. Default is: off"
    echo "  -c/--critical)"
    echo "     Defines a critical level for a mongodb which is explained"
    echo "     below. Default is: off"
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
        --warning|-w)
            warning=$2
            shift
            ;;
        --critical|-c)
            critical=$2
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            print_help
            exit $ST_UK
            ;;
        esac
    shift
done

get_wcdiff() {
    if [ ! -z "$warning" -a ! -z "$critical" ]
    then
        wclvls=1
        if [ ${warning} -gt ${critical} ]
        then
            wcdiff=1
        fi
    elif [ ! -z "$warning" -a -z "$critical" ]
    then
        wcdiff=2
    elif [ -z "$warning" -a ! -z "$critical" ]
    then
        wcdiff=3
    fi
}

val_wcdiff() {
    if [ "$wcdiff" = 1 ]
    then
        echo "Please adjust your warning/critical thresholds. The warning \
must be lower than the critical level!"
        exit $ST_UK
    elif [ "$wcdiff" = 2 ]
    then
        echo "Please also set a critical value when you want to use \
warning/critical thresholds!"
        exit $ST_UK
    elif [ "$wcdiff" = 3 ]
    then
        echo "Please also set a warning value when you want to use \
warning/critical thresholds!"
        exit $ST_UK
    fi
}
if [ -n "$warning" -a -n "$critical" ]
then
	if [[ $(bc <<< "($(get_new dirty)+$(get_new evicted))/$(get_new maximum) >= $critical/100") == 1 ]]; then
		echo "CRITICAL - $(output_msg) | $(output_perfdata)"
		exit $ST_CR
	elif [[ $(bc <<< "($(get_new dirty)+$(get_new evicted))/$(get_new maximum) >= $warning/100") == 1 ]]; then
		echo "WARNING - $(output_msg) | $(output_perfdata)"
		exit $ST_WR
	else 
		echo "OK - $(output_msg) | $(output_perfdata)"
		exit $ST_OK
	fi
else 
	echo "OK - $(output_msg) | $(output_perfdata)"
	exit $ST_OK
fi
	