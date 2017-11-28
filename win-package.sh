#/bin/bash

./package.sh $1
cd $1
rm -r $1-distribution
mkdir $1-distribution
cp ~/love-win/*.dll $1-distribution/
cp ~/love-win/license.txt $1-distribution/
cat ~/love-win/love.exe ./$1.love > $1-distribution/$1.exe

