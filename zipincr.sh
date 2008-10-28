#prev=`ls -t *.tgz | head -1`
ddd="$(date +%Y%m%d%H%M)"
file=frmincr$ddd.tgz
#tar zcvf  $file --newer=$prev *.rb
prev=`ls -t ../*.tgz | head -1`
echo "last was: $prev"
echo "Enter comment. ^D to finish"
echo -n "Enter subject:"
read subject
echo "Enter text:"
oldtext=`cat CHANGELOG`
mv CHANGELOG CHANGELOG.tmp
IFS=$'~'
text=`rlwrap cat`
fddd=$(date +"**%Y-%m-%d %H:%M**")
echo "$fddd" > CHANGELOG
echo "## $subject ##" >> CHANGELOG
echo "" >> CHANGELOG
echo $text >> CHANGELOG
echo "" >> CHANGELOG
echo $file >> CHANGELOG
echo "* * *"  >> CHANGELOG
echo $oldtext >> CHANGELOG
#tar  zcf  $file --atime-preserve --newer="$prev" *.rb CHANGELOG
SRCDIR="lib/"
#tar zcvf $file --newer-mtime="`date -r $prev`" $SRCDIR/*.rb $SRCDIR/*.dsl CHANGELOG TODO
tar zcvf $file --newer-mtime="`date -r $prev`" $SRCDIR dsl/ out/ CHANGELOG TODO
tar ztvf  $file 
ls -l $file
mailbackup.sh $file
mv $file ..
mv CHANGELOG.tmp ..
