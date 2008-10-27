comment=${1:-""}
ddd="$(date +%Y%m%d%H%M)"
pref=`basename $PWD`
fff=$pref$ddd$comment.tgz
echo "creating" $fff
SRCDIR="lib/"
tar zcvf $fff $SRCDIR dsl/ out/ NOTES *TODO CHANGES ISSUES CHANGELOG *.txt Rakefile
ls -l $fff
mailbackup.sh $fff
mv $fff ../
