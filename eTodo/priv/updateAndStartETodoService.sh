#!/bin/sh
cd ..
cd ..
svn update ePort
svn update eLog
svn update eTodo
cd ePort/src
erl -make
cd ..
cd ..
cd eLog/src
erl -make
cd ..
cd ..
cd eTodo/src
erl -make
cd ..
cd ebin
erl -boot start_sasl -smp -pa ../../eLog/ebin -pa ../../ePort/ebin -pa ../../eTodo/ebin -run startETodo noGui $@



