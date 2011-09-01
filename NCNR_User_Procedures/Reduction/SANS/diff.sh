while read line
do
	orig=$line
	diff=$HOME/hg/HANARO_SANS/HANARO_$orig
	if [ -e $diff ]
	then
		echo ":::: $orig ::::"
		diff $orig $diff
	fi
done < _list
