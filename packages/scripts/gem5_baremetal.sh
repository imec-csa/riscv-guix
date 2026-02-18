d=`dirname $0`
t="${TMPDIR:-/tmp}/trace-$$"
mkfifo $t
onexit () { rm -f $t; }
trap onexit 0 1 2 3 9 15
gem5.opt --debug-flags=Exec $d/gem5_baremetal.py $@ > $t & pid=$!
cat $t|awk -vPID=$pid '$6=="@write_tohost+4" && $8=="sw" { r=strtonum(gensub(/D=/,"","g",$14))-1; if (0) print $0,r; system("kill " PID);exit r }'
# { print }'
