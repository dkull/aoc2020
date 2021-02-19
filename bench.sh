echo "# Advent Of Code 2020 in Zig"
echo "(Learning Zig as I go)"

for dir in ./*     # list directories in the form "/tmp/dirname/"
do
	if [[ -f "./$dir" ]]; then
		continue;
	fi;
	echo "# ${dir##*/}"   # print everything after the final "/"
	cd $dir > /dev/null
	zig build -Drelease-fast 2>/dev/null
	timeout 5s ./zig-cache/bin/* 2>&1 | grep "all done" | tail -n 2
	cd - > /dev/null
done

