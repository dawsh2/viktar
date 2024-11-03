#!/bin/bash

# R Jesse Chaney
# 

SUM=sum
PROG=viktar
CLASS=cs333
POINTS=0
TOTAL_POINTS=365
CLEANUP=1
WARNINGS=0
FILE_HOST=babbage
DIFF=diff
#DIFF_OPTIONS="-B -w -i"
DIFF_OPTIONS="-w"
FAIL_COUNT=0
LAB=Lab3
VERBOSE=0
CORE_COUNT=0
VALGRIND=valgrind
NOLEAKS="All heap blocks were freed -- no leaks are possible"
LEAKS_FOUND=0

TO=10s
TOS="-s QUIT --kill-after=60 --preserve-status"

SDIR=${PWD}
JDIR=~rchaney/Classes/${CLASS}/Labs/${LAB}
#JDIR=~rchaney/Classes/${CLASS}/Labs/src/viktar

SPROG=${SDIR}/${PROG}
JPROG=${JDIR}/${PROG}

signalCaught()
{
    echo "++++ caught signal while running script ++++"
}

signalCtrlC()
{
    echo "Caught Control-C"
    echo "You will neeed to clean up some files"
    exit
}

signalSegFault()
{
    echo "+++++++ Caught Segmentation Fault from your program! OUCH!  ++++++++"
}

coreDumpMessage()
{
    if [ $1 -eq 139 ]
    then
        echo "      >>> core dump during $2 testing"
        ((CORE_COUNT++))
    elif [ $1 -eq 137 ]
    then
        echo "      >>> core dump during $2 testing"
        ((CORE_COUNT++))
    elif [ $1 -eq 134 ]
    then
        echo "      >>> abort during $2 testing"
        ((CORE_COUNT++))
    elif [ $1 -eq 124 ]
    then
        echo "      >>> timeout during $2 testing"
    #else
        #echo "$1 is a okay"
    fi
    sync
}

altBuild()
{
    # g VIKTAR_FILE *.h | awk '{print $4;}' | sed -e "s/\"//g" -e 's/^.//' -e "s/<\|>//g" -e 's/\\n//'
    IS_CS333=$(id -Gn | grep cs333-rjc)
    if [ -z "${IS_CS333}" ]
    then
        #echo "Cannot do altBuild"
        return
    fi
    echo "Performing altBuild"
    
    rm -f ${PROG}.h
    ln -s ${JDIR}/${PROG}_ALT.h ./${PROG}.h

    rm -f ./J${PROG} ./J${PROG}.c
    ln -s ${JDIR}/${PROG}.c ./J${PROG}.c
    gcc -g -DVIKTAR_CRC -I . -o ./J${PROG} J${PROG}.c -lz
    #rm -f ./J${PROG}.c

    if [ ! -x J${PROG} ]
    then
        echo ">>> Alt-Build failed."
        echo ">>> Macro resistance??"
        exit 2
    else
        JPROG=./J${PROG}
        echo "*** Alt-Build success! ***"
    fi

    rm -f ${PROG} ${PROG}.o
    make clean
    make

#    exit 0
}

chmodAndTimeStampFiles()
{
    chmod a+r Constitution.txt Iliad.txt jargon.txt words.txt ?-s.txt
	chmod g+wr,o+r,u-w text-*.txt
	chmod a+rx *.bin
	chmod g+w random-333.bin
	chmod a-x zeroes-1M.bin
	chmod o-r zeroes-1M.bin
	chmod og-rw,g-x,o+r zeroes-4M.bin
	chmod g-r random-2M.bin
	chmod a+rx zero-sized-file.bin
	touch -t 200110111213.14 text-5k.txt
	touch -t 197009011023.44 text-75k.txt
	touch -t 199912122358.59 words.txt
	touch -t 197805082150.59 Constitution.txt Iliad.txt
	touch -t 202112110217.44 jargon.txt
	touch -t 201202030405.06 zer*.bin
	touch -t 198012050303.06 ran*.bin
	touch -t 199507080910.36 [01]-s.txt
	touch -t 199608040311.36 [23]-s.txt
	touch -t 199706070809.36 [45]-s.txt
	touch -t 196003030303.03 6-s.txt
	touch -t 195701011532.57 zeroes-4M.bin
}

copyTestFiles()
{
    if [ ${VERBOSE} -eq 1 ]
    then
	    echo ""
	    echo "  Copying test files into current directory"
    fi
    
    #rm -f ${PROG}.h
    #ln -s ${JDIR}/${PROG}.h .
    
    rm -f Constitution.txt Iliad.txt jargon.txt text-*k.txt words.txt
    rm -f random-*.bin
    rm -f zeroes-?M.bin zero-sized-file.bin
    rm -f [0-9]-s.txt 

    cp ${JDIR}/*.txt .
    cp ${JDIR}/random-*.bin .
    cp ${JDIR}/zer* .
    cp ${JDIR}/*.viktar .
    cp ${JDIR}/[0-6]-s.txt .

    chmodAndTimeStampFiles
    
	rm -f corruptTest?.viktar goodTest?.viktar
	${JPROG} -C tag -c [3-6]-s.txt -fgoodTest1.viktar
	${JPROG} -C hz -c [3-6]-s.txt  -fgoodTest2.viktar
	${JPROG} -C dz -c [3-6]-s.txt  -fgoodTest3.viktar
	${JPROG} -C tag -c [3-6]-s.txt -fcorruptTest1.viktar
	${JPROG} -C hn  -c [3-6]-s.txt -fcorruptTest2.viktar
	${JPROG} -C hu  -c [3-6]-s.txt -fcorruptTest3.viktar
	${JPROG} -C hg  -c [3-6]-s.txt -fcorruptTest4.viktar
	${JPROG} -C hz  -c [3-6]-s.txt -fcorruptTest5.viktar
	${JPROG} -C dc  -c [3-6]-s.txt -fcorruptTest6.viktar
	${JPROG} -C dz  -c [3-6]-s.txt -fcorruptTest7.viktar
	${JPROG} -C dz  -C hz -c [3-6]-s.txt -fcorruptTest8.viktar
	${JPROG} -C dz  -C dc -C hz -C hn -C hu -C hg -c [3-6]-s.txt -fcorruptTest9.viktar

    # # Create the files to test the CRC values
    # ${JPROG} -c [56]-s.txt > corrupt.viktar
    # sed -e "s/6-s/7-s/" -e "s/^666/707/" < corrupt.viktar > corruptTest1.viktar
    # sed -e "s/6-s/8-s/" -e "s/^q/a/" < corrupt.viktar > corruptTest2.viktar
    # rm -f corrupt.viktar
    # chmod a+r corruptTest?.viktar

    # ${JPROG} -c [0-6]-s.txt > corrupt.viktar
    # sed -e "s/viktar/itAR/" -e "s/VIKTAR/vikar/" < corrupt.viktar > badTag.viktar
    # rm -f corrupt.viktar
    # chmod a+r badTag.viktar

    chmodAndTimeStampFiles
    
    ${JPROG} -c -f simple_text.viktar [0-6]-s.txt
    ${JPROG} -c -f long_name.viktar random-333-with-a-long-name.bin
    ${JPROG} -c -f bin_files.viktar random-24M.bin random-2M.bin zeroes-1M.bin random-333.bin zeroes-4M.bin

    chmodAndTimeStampFiles
    
    if [ ${VERBOSE} -eq 1 ]
    then
	    echo "    Test files copied. Permissions and dates set."
    fi
    sync ; sync ; sync
}

build()
{
    BuildFailed=0

    echo -e "\nBuilding ..."

    rm -f ${PROG}.h
    ln -s ${JDIR}/${PROG}.h .

    #make all > /dev/null
    make clean all 2> WARN.err > WARN.out
    NUM_BYTES=$(wc -c < WARN.err)
    if [ ${NUM_BYTES} -eq 0 ]
    then
        echo "    You have no compiler warnings messages. Good job."
    else
        echo ">>> You have compiler warnings messages. That is -20 percent!"
        WARNINGS=1
    fi

    if [ ! -x ${PROG} ]
    then
        BuildFailed=1
    fi
}

testCreateTextFiles()
{
    local TEST_FAIL=0

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -TtxVc -f test01_S.viktar Constitution.txt 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    
    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -TtxV Constitution.txt Iliad.txt -f test02_S.viktar jargon.txt words.txt -c 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} [0-6]-s.txt -cf test03_S.viktar text-*k.txt 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    ${JPROG} -TtxVc -f test01_J.viktar Constitution.txt
    chmodAndTimeStampFiles
    ${JPROG} -TtxV Constitution.txt Iliad.txt -f test02_J.viktar jargon.txt words.txt -c
    chmodAndTimeStampFiles
    ${JPROG} [0-6]-s.txt -cf test03_J.viktar text-*k.txt 

    echo "Testing with plain text files ..."
    SSUM=$(${SUM} test01_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test01_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED single archive member test, with Constitution.txt"
        echo ">>> Fix this before trying more create tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed single archive member test, with Constitution.txt\n\tPOINTS=${POINTS}"

    SSUM=$(${SUM} test02_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test02_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED 4 archive members test, with Constitution.txt Iliad.txt jargon.txt words.txt"
        echo ">>> Fix this before trying more create tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 4 archive members test, with Constitution.txt Iliad.txt jargon.txt words.txt\n\tPOINTS=${POINTS}"

    SSUM=$(${SUM} test03_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test03_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED many archive members test, with [0-6]-s.txt text-*k.txt"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed many archive members test, with [0-6]-s.txt text-*k.txt\n\tPOINTS=${POINTS}"

    echo "** Text files with named archive passed."
    echo "   Moving to sending archive to stdout."
    
    # testing stdout

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -x -c Constitution.txt > test04_S.viktar 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -x Constitution.txt Iliad.txt jargon.txt words.txt -c > test05_S.viktar 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} [0-6]-s.txt -c text-*k.txt > test06_S.viktar 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    ${JPROG} -c Constitution.txt > test04_J.viktar
    chmodAndTimeStampFiles
    ${JPROG} Constitution.txt Iliad.txt jargon.txt words.txt -c > test05_J.viktar
    ${JPROG} [0-6]-s.txt -c text-*k.txt > test06_J.viktar

    SSUM=$(${SUM} test04_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test04_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED single archive member to stdout test, with Constitution.txt"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed single archive member test to stdout, with Constitution.txt\n\tPOINTS=${POINTS}"

    SSUM=$(${SUM} test05_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test05_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED 4 archive members to stdout test, with Constitution.txt Iliad.txt jargon.txt words.txt"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 4 archive members test to stdout, with Constitution.txt Iliad.txt jargon.txt words.txt\n\tPOINTS=${POINTS}"

    SSUM=$(${SUM} test06_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test06_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED many archive members to stdout test, with [0-6]-s.txt text-*k.txt"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed many archive members test to stdout, with [0-6]-s.txt text-*k.txt\n\tPOINTS=${POINTS}"

    echo "** Text files with archive to stdout passed."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testCreateBinFiles()
{
    local TEST_FAIL=0

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cf test07_S.viktar random-333.bin 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} random-333.bin -c random-24M.bin -f test08_S.viktar random-2M.bin 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} zeroes-?M.bin random-333.bin random-24M.bin random-2M.bin zero-sized-file.bin -f test09_S.viktar -c 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    ${JPROG} -cf test07_J.viktar random-333.bin
    chmodAndTimeStampFiles
    ${JPROG} random-333.bin -c random-24M.bin -f test08_J.viktar random-2M.bin
    chmodAndTimeStampFiles
    ${JPROG} zeroes-?M.bin random-333.bin random-24M.bin random-2M.bin zero-sized-file.bin -f test09_J.viktar -c

    echo "Testing with binary files ..."
    SSUM=$(${SUM} test07_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test07_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED single archive member random test, with random-333.bin"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed single archive member random test, with random-333.bin\n\tPOINTS=${POINTS}"

    JSUM=$(${SUM} test08_J.viktar | awk '{print $1;}')
    SSUM=$(${SUM} test08_S.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED 3 archive member random test, with random-333.bin random-24M.bin random-2M.bin"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 3 archive member random test, with random-333.bin random-24M.bin random-2M.bin\n\tPOINTS=${POINTS}"

    SSUM=$(${SUM} test09_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test09_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED 3 archive member random test, with "
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 5 archive member random test, with\n\t\t zeroes-?M.bin random-333.bin random-24M.bin random-2M.bin zero-sized-file.bin\n\tPOINTS=${POINTS}"

    echo "   Binary files with named archive passed."
    echo "   Moving to sending archive to stdout."

    # testing stdout
    
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -c random-333.bin > test10_S.viktar 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} random-333.bin random-24M.bin -c random-2M.bin > test11_S.viktar 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} random-333.bin zeroes-?M.bin random-24M.bin random-2M.bin zero-sized-file.bin -c > test12_S.viktar 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    ${JPROG} -c random-333.bin > test10_J.viktar
    chmodAndTimeStampFiles
    ${JPROG} random-333.bin random-24M.bin -c random-2M.bin > test11_J.viktar
    chmodAndTimeStampFiles
    ${JPROG} random-333.bin zeroes-?M.bin random-24M.bin random-2M.bin zero-sized-file.bin -c > test12_J.viktar

    SSUM=$(${SUM} test10_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test10_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED single archive member random to stdout, with random-333.bin"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed single archive member random test to stdout, with random-333.bin\n\tPOINTS=${POINTS}"

    SSUM=$(${SUM} test11_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test11_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED 3 archive member random to stdout, with random-333.bin random-24M.bin random-2M.bin"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 3 archive member random test to stdout, with random-333.bin random-24M.bin random-2M.bin\n\tPOINTS=${POINTS}"

    SSUM=$(${SUM} test12_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test12_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED 3 archive member random to stdout, with random-*.bin"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=15))
    echo -e "\tPassed 5 archive member random test to stdout, with\n\t\t zeroes-?M.bin random-333.bin random-24M.bin random-2M.bin zero-sized-file.bin\n\tPOINTS=${POINTS}"
    
    echo "** Binary files to stdout passed."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testLongName()
{
    local TEST_FAIL=0

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -cf test13_S.viktar random-333-with-a-long-name.bin 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -c random-333-with-a-long-name.bin random-24M.bin random-2M.bin -f test14_S.viktar 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -c random-24M.bin -f test15_S.viktar random-333-with-a-long-name.bin 2> /dev/null " ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    chmodAndTimeStampFiles
    ${JPROG} -c -f test13_J.viktar random-333-with-a-long-name.bin
    chmodAndTimeStampFiles
    ${JPROG} -c -f test14_J.viktar random-333-with-a-long-name.bin random-24M.bin random-2M.bin
    chmodAndTimeStampFiles
    ${JPROG} -c -f test15_J.viktar random-24M.bin random-333-with-a-long-name.bin

    echo "Testing with over-long file name ..."
    SSUM=$(${SUM} test13_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test13_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED long name file, 1 member"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed single over-long file, with random-333-with-a-long-name.bin\n\tPOINTS=${POINTS}"

    JSUM=$(${SUM} test14_J.viktar | awk '{print $1;}')
    SSUM=$(${SUM} test14_S.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED long name member with 2 other members"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 3 over-long file, with random-24M.bin random-333-with-a-long-name.bin random-2M.bin\n\tPOINTS=${POINTS}"

    SSUM=$(${SUM} test15_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test15_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED long name member with 1 other member"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed 2 over-long file, with random-333-with-a-long-name.bin random-24M.bin\n\tPOINTS=${POINTS}"

    echo "** Long name file passed."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testBigArchive()
{
    local TEST_FAIL=0

    # must use bash due to file spec
    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -c -f test16_S.viktar *.{txt,bin} > /dev/null 2>&1" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    chmodAndTimeStampFiles
    ${JPROG} -c -f test16_J.viktar *.{txt,bin}

    echo "Testing with BIG archive file ..."
    SSUM=$(${SUM} test16_S.viktar | awk '{print $1;}')
    JSUM=$(${SUM} test16_J.viktar | awk '{print $1;}')
    if [ ${JSUM} -ne ${SSUM} ]
    then
        echo ">>> FAILED big archive with *.{txt,bin}"
        echo ">>> Fix this before trying more tests"
        return
    fi
    ((POINTS+=10))
    echo -e "\tPassed big archive, with *.{txt,bin}\n\tPOINTS=${POINTS}"

    echo "** Big archive file passed."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testExtractTextFiles()
{
    echo "Testing extract from archive file text files..."
    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -c *.txt -f testX01_S.viktar > /dev/null 2>&1" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with text files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    chmodAndTimeStampFiles
    ${JPROG} -c *.txt -f testX01_J.viktar > /dev/null 2>&1

    chmodAndTimeStampFiles
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -c *.bin -f testX02_S.viktar > /dev/null 2>&1" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    chmodAndTimeStampFiles
    ${JPROG} -c *.bin -f testX02_J.viktar > /dev/null 2>&1

    rm -f *.txt
    ${SPROG} -xf testX01_S.viktar
    ls -lAuq *.txt > testX01_S.out
    stat --printf="\tfile name: %n\n\t\tmode:  %A\n\t\tuser:  %U\n\t\tgroup: %G\n\t\tsize:  %s\n\t\tmtime: %y\n\t\tatime: %x\n" *.txt > testX01_S.sout

    rm -f *.txt
    ${JPROG} -xf testX01_J.viktar
    ls -lAuq *.txt > testX01_J.out
    stat --printf="\tfile name: %n\n\t\tmode:  %A\n\t\tuser:  %U\n\t\tgroup: %G\n\t\tsize:  %s\n\t\tmtime: %y\n\t\tatime: %x\n" *.txt > testX01_J.sout

    ${DIFF} ${DIFF_OPTIONS} testX01_J.sout testX01_S.sout > /dev/null 2> /dev/null
    if [ $? -ne 0 ]
    then
        echo ">>> FAILED extract with text files"
        echo ">>> Fix this before trying more tests"
        echo ">>> "
        echo "      try this: ${DIFF} ${DIFF_OPTIONS} -y testX01_J.sout testX01_S.sout"
        return
    fi
    ((POINTS+=15))
    echo -e "\tPassed extract with text files\n\tPOINTS=${POINTS}"

    rm -f *.bin
    ${SPROG} -xf testX02_S.viktar
    ls -lAuq *.bin > testX02_S.out
    stat --printf="\tfile name: %n\n\t\tmode:  %A\n\t\tuser:  %U\n\t\tgroup: %G\n\t\tsize:  %s\n\t\tmtime: %y\n\t\tatime: %x\n" *.bin > testX02_S.sout

    rm -f *.bin
    ${JPROG} -xf testX02_J.viktar
    ls -lAuq *.bin > testX02_J.out
    stat --printf="\tfile name: %n\n\t\tmode:  %A\n\t\tuser:  %U\n\t\tgroup: %G\n\t\tsize:  %s\n\t\tmtime: %y\n\t\tatime: %x\n" *.bin > testX02_J.sout

    ${DIFF} ${DIFF_OPTIONS} testX02_J.sout testX02_S.sout > /dev/null 2> /dev/null
    if [ $? -ne 0 ]
    then
        echo ">>> FAILED extract with binary files"
        echo ">>> Fix this before trying more tests"
        echo ">>> "
        echo "      try this: ${DIFF} ${DIFF_OPTIONS} -y testX02_J.sout testX02_S.sout"
        return
    fi
    ((POINTS+=15))
    echo -e "\tPassed extract with binary files\n\tPOINTS=${POINTS}"

    echo "** Extract from archive file passed."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testSmallTOC()
{
    echo "Testing short toc ..."
    
    #{ timeout ${TOS} ${TO} bash -c "exec ${SPROG} -vtf simple_text.viktar 2> test01_S.err | sed -e s+\"++g > test01_S.out" ; }
    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -vtf simple_text.viktar 2> test01_S.err > test01_S.out" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    sed -e s+\"++g test01_S.out > JUNK ; mv JUNK test01_S.out
    ${JPROG} -vtf simple_text.viktar 2> test01_J.err | sed -e s+\"++g > test01_J.out

    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -v -v -v -f long_name.viktar -v -v -t -v -v > test02_S.out 2> test02_S.err" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    sed -e s+\"++g test02_S.out > JUNK ; mv JUNK test02_S.out
    ${JPROG} -tf long_name.viktar | sed -e s+\"++g > test02_J.out 2> test02_J.err

    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -v -v -vv -t -vv -f bin_files.viktar -vv -v > test03_S.out 2> test03_S.err" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    sed -e s+\"++g test03_S.out > JUNK ; mv JUNK test03_S.out
    ${JPROG} -tf bin_files.viktar | sed -e s+\"++g > test03_J.out 2> test03_J.err

    ${DIFF} ${DIFF_OPTIONS} test01_S.out test01_J.out > /dev/null
    if [ $? -eq 0 ]
    then
        ((POINTS+=5))
        echo -e "\tshort toc on simple_text.viktar is good"
    else
        echo ">>> short toc on simple_text.viktar is sad"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y test01_S.out test01_J.out"
    fi

    ${DIFF} ${DIFF_OPTIONS} test02_S.out test02_J.out > /dev/null
    if [ $? -eq 0 ]
    then
        ((POINTS+=2))
        echo -e "\tshort toc on long_name.viktar is good"
    else
        echo ">>> short toc on long_name.viktar is sad"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y test02_S.out test02_J.out"
    fi

    ${DIFF} ${DIFF_OPTIONS} test01_S.out test01_J.out > /dev/null
    if [ $? -eq 0 ]
    then
        ((POINTS+=2))
        echo -e "\tshort toc on bin_files.viktar is good"
    else
        echo ">>> short toc on bin_files.viktar is sad"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y test03_S.out test03_J.out"
    fi

    if [ -s test01_S.err ]
    then
        ((POINTS+=2))
        echo -e "\tverbose output good"
    else
        echo "  verbose output is sad"
    fi

    echo "** Short toc done..."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testBigTOC()
{
    echo "Testing long TOC ..."

    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -v -v -v -v -f simple_text.viktar -T > test04_S.out 2> test04_S.err" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    sed -e s+\"++g test04_S.out > JUNK ; mv JUNK test04_S.out
    ${JPROG} -Tf simple_text.viktar | sed -e s+\"++g > test04_J.out 2> test04_J.err

    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -T -v -v -v -v -f long_name.viktar > test05_S.out 2> test05_S.err" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    sed -e s+\"++g test05_S.out > JUNK ; mv JUNK test05_S.out
    ${JPROG} -Tf long_name.viktar | sed -e s+\"++g > test05_J.out 2> test05_J.err

    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -Tf bin_files.viktar -v -v -v -v > test06_S.out 2> test06_S.err" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing create archive with binary files"
    if [ ${CORE_DUMP} -ne 0 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    sed -e s+\"++g test06_S.out > JUNK ; mv JUNK test06_S.out
    ${JPROG} -Tf bin_files.viktar | sed -e s+\"++g > test06_J.out 2> test06_J.err
    
    ${DIFF} ${DIFF_OPTIONS} test04_S.out test04_J.out > /dev/null
    if [ $? -eq 0 ]
    then
        ((POINTS+=3))
        echo -e "\tlong toc on simple_text.viktar is good"
    else
        echo ">>> long toc on simple_text.viktar is sad"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y test04_S.out test04_J.out"
    fi

    ${DIFF} ${DIFF_OPTIONS} test05_S.out test05_J.out > /dev/null
    if [ $? -eq 0 ]
    then
        ((POINTS+=3))
        echo -e "\tlong toc on long_name.viktar is good"
    else
        echo ">>> long toc on long_name.viktar is sad"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y test05_S.out test05_J.out"
    fi

    ${DIFF} ${DIFF_OPTIONS} test06_S.out test06_J.out > /dev/null
    if [ $? -eq 0 ]
    then
        ((POINTS+=3))
        echo -e "\tlong toc on bin_files.viktar is good"
    else
        echo ">>> long toc on bin_files.viktar is sad"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y test06_S.out test06_J.out"
    fi

    echo "** Long toc done..."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testHelp()
{
    echo "Testing help text ..."

    ${SPROG} -h 2>&1 | grep -v viktar > test07_S.out
    ${JPROG} -h 2>&1 | grep -v viktar > test07_J.out

    ${DIFF} ${DIFF_OPTIONS} test07_S.out test07_J.out > /dev/null
    if [ $? -eq 0 ]
    then
        ((POINTS+=10))
        echo -e "\thelp text is good"
    else
        echo ">>> help text needs help"
        CLEANUP=0
        echo "    try this: ${DIFF} ${DIFF_OPTIONS} -y test07_S.out test07_J.out"
    fi

    echo "** Help text done..."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testBadFile()
{
    echo "Testing bad viktar file tag..."
    BAD_TAG_FILE=goodTest1.viktar

    ${JPROG} -t -f ${BAD_TAG_FILE} > badTag1.jout 2> badTag1.jerr
    ${JPROG} -t < ${BAD_TAG_FILE} > badTag2.jout 2> badTag2.jerr

    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -t -f ${BAD_TAG_FILE} > badTag1.sout 2> badTag1.serr" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing bad viktar file tag 1"

    if [ ${CORE_DUMP} -ne 0 -a ${CORE_DUMP} -ne 1 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi

    if [ ${CORE_DUMP} -ne 1 ]
    then
        echo ">>> A bad viktar tag in a file should have an exit value of 1 not ${CORE_DUMP}"
        echo ">>> Continuing - missing 5 points"
    else
        ((POINTS+=10))
        echo -e "\tbad tag test 1.1 is good \n\tPOINTS=${POINTS}"
    fi

    ${DIFF} ${DIFF_OPTIONS} badTag1.jerr badTag1.serr > /dev/null 2> /dev/null
    if [ $? -ne 0 ]
    then
        echo ">>> FAILED bad tag in archive file"
        echo ">>> "
        echo "Your output:"
        cat badTag1.serr
        echo "Jesse output:"
        cat badTag1.jerr
        echo ">>> Continuing - missing 5 points"
        CLEANUP=0
    else
        ((POINTS+=10))
        echo -e "\tbad tag test 1.2 is good \n\tPOINTS=${POINTS}"
    fi
    if [ -s badTag1.sout ]
    then
        echo ">>> The output file should be empty"
        echo ">>> Continuing - missing 5 points"
        CLEANUP=0
    else
        ((POINTS+=10))
        echo -e "\tbad tag test 1.3 is good\n\tPOINTS=${POINTS}"
    fi

    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -t < ${BAD_TAG_FILE} > badTag2.sout 2> badTag2.serr" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing bad viktar file tag 2"
    if [ ${CORE_DUMP} -ne 0 -a ${CORE_DUMP} -ne 1 ]
    then
        echo ">>> Segmentation faults are not okay <<<"
        echo ">>> Testing ends here"
        echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
        exit 1
    fi
    if [ ${CORE_DUMP} -ne 1 ]
    then
        echo ">>> A bad viktar tag in a file should have an exit value of 1 not ${CORE_DUMP}"
        echo ">>> Continuing - missing 5 points"
        CLEANUP=0
    else
        ((POINTS+=10))
        echo -e "\tbad tag test 2.1 is good \n\tPOINTS=${POINTS}"
    fi

    ${DIFF} ${DIFF_OPTIONS} badTag2.jerr badTag2.serr > /dev/null 2> /dev/null
    if [ $? -ne 0 ]
    then
        echo ">>> FAILED bad tag in archive file"
        echo ">>> "
        echo "Your output:"
        cat badTag2.serr
        echo "Jesse output:"
        cat badTag2.jerr
        echo ">>> Continuing - missing 5 points"
        CLEANUP=0
    else
        ((POINTS+=10))
        echo -e "\tbad tag test 2.2 is good\n\tPOINTS=${POINTS}"
    fi
    if [ -s badTag2.sout ]
    then
        echo ">>> The output file should be empty"
        echo ">>> Continuing - missing 5 points"
        CLEANUP=0
    else
        ((POINTS+=10))
        echo -e "\tbad tag test 2.3 is good\n\tPOINTS=${POINTS}"
    fi

    echo "** Done with Testing bad viktar file tag."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testCRCErrors()
{
    echo "Testing bad md5..."

    rm -f [3-6]-s.txt

    CORRUPT_FILE1=goodTest3.viktar
    CORRUPT_FILE2=corruptTest3.viktar

    ${JPROG} -x -f ${CORRUPT_FILE1} > corruptTest1.jout 2> corruptTest1.jerr
    ${JPROG} -x < ${CORRUPT_FILE2} > corruptTest2.jout 2> corruptTest2.jerr

    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -x -f ${CORRUPT_FILE1} > corruptTest1.sout 2> corruptTest1.serr" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing extract from corrupt md5 file 1"
    if [ ${CORE_DUMP} -eq 0 ]
    then
        ((POINTS+=10))
        echo -e "\tNice... Exit value from bad md5 is 0"
    else
        echo "Exit value from a bad md5 should be 0"
        echo ">>> Continuing - missing 10 points"
        CLEANUP=0
    fi

    ${DIFF} ${DIFF_OPTIONS} corruptTest1.jerr corruptTest1.serr > /dev/null 2> /dev/null
    if [ $? -ne 0 ]
    then
        echo ">>> FAILED bad md5 in archive file 1"
        echo ">>> "
        echo "Your output:"
        cat corruptTest1.serr
        echo "Jesse output:"
        cat corruptTest1.jerr
        echo ">>> Continuing - missing 10 points"
        CLEANUP=0
    else
        ((POINTS+=10))
        echo -e "\tbad md5 test 1.1 is good\n\tPOINTS=${POINTS}"
    fi
    if [ ! -e 5-s.txt ]
    then
        echo ">>> You did not extract the corrupt file"
        echo ">>> Continuing - missing 20 points"
        CLEANUP=0
    else
        ((POINTS+=10))
        echo -e "\tbad md5 test 1.2 is good\n\tPOINTS=${POINTS}"
    fi

    { timeout ${TOS} ${TO} bash -c "exec ${SPROG} -x < ${CORRUPT_FILE2} > corruptTest2.sout 2> corruptTest2.serr" ; }
    CORE_DUMP=$?
    coreDumpMessage ${CORE_DUMP} "testing extract from corrupt md5 file 2"
    if [ ${CORE_DUMP} -eq 0 ]
    then
        ((POINTS+=10))
        echo -e "\tNice... Exit value from bad md5 is 0"
    else
        echo "Exit value from a bad md5 should be 0"
        echo ">>> Continuing - missing 10 points"
        CLEANUP=0
    fi

    ${DIFF} ${DIFF_OPTIONS} corruptTest2.jerr corruptTest2.serr > /dev/null 2> /dev/null
    if [ $? -ne 0 ]
    then
        echo ">>> FAILED bad md5 in archive file 2"
        echo ">>> "
        echo "Your output:"
        cat corruptTest2.serr
        echo "Jesse output:"
        cat corruptTest2.jerr
        echo ">>> Continuing - missing 10 points"
        CLEANUP=0
    else
        ((POINTS+=10))
        echo -e "\tbad md5 test 2.1 is good\n\tPOINTS=${POINTS}"
    fi
    if [ ! -e 6-s.txt ]
    then
        echo ">>> You did not extract the corrupt file"
        echo ">>> Continuing - missing 10 points"
        CLEANUP=0
    else
        ((POINTS+=10))
        echo -e "\tbad md5 test 2.2 is good\n\tPOINTS=${POINTS}"
    fi

    echo "** Done with Testing bad viktar md5 value."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testValidate()
{
    echo "Testing with Validate..."

    ${JPROG} -Vf goodTest2.viktar 2> validate01_J.err > validate01_J.out
    ${JPROG} -Vf goodTest3.viktar 2> validate02_J.err > validate02_J.out
    
    ${SPROG} -Vf goodTest2.viktar 2> validate01_S.err > validate01_S.out
    ${SPROG} -Vf goodTest3.viktar 2> validate02_S.err > validate02_S.out

    ${DIFF} ${DIFF_OPTIONS} validate01_J.out validate01_S.out > /dev/null 2> /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "\tValidate checks out on goodTest2.viktar"
        ((POINTS+=5))
    else
        echo ">>> Validate fails on goodTest2.viktar"
        echo "  try: ${DIFF} ${DIFF_OPTIONS} -y validate01_J.out validate01_S.out"
        CLEANUP=0
    fi
    
    ${DIFF} ${DIFF_OPTIONS} validate02_J.out validate02_S.out > /dev/null 2> /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "\tValidate checks out on goodTest3.viktar"
        ((POINTS+=5))
    else
        echo ">>> Validate fails on goodTest3.viktar"
        echo "  try: ${DIFF} ${DIFF_OPTIONS} -y validate02_J.out validate02_S.out"
    fi
    
    ${JPROG} -V < corruptTest4.viktar 2> validate03_J.err > validate03_J.out
    ${JPROG} -V < corruptTest8.viktar 2> validate04_J.err > validate04_J.out

    ${SPROG} -V < corruptTest4.viktar 2> validate03_S.err > validate03_S.out
    ${SPROG} -V < corruptTest8.viktar 2> validate04_S.err > validate04_S.out

    ${DIFF} ${DIFF_OPTIONS} validate03_J.out validate03_S.out > /dev/null 2> /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "\tValidate checks out on corruptTest4.viktar"
        ((POINTS+=5))
    else
        echo ">>> Validate fails on corruptTest4.viktar"
        echo "  try: ${DIFF} ${DIFF_OPTIONS} -y validate03_J.out validate03_S.out"
        CLEANUP=0
    fi
    
    ${DIFF} ${DIFF_OPTIONS} validate04_J.out validate04_S.out > /dev/null 2> /dev/null
    if [ $? -eq 0 ]
    then
        echo -e "\tValidate checks out on corruptTest8.viktar"
        ((POINTS+=5))
    else
        echo ">>> Validate fails on corruptTest8.viktar"
        echo "  try: ${DIFF} ${DIFF_OPTIONS} -y validate04_J.out validate04_S.out"
        CLEANUP=0
    fi
    
    echo "** Done with Testing Validate."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

testValgrind()
{
    echo "Testing with valgrind for memory leaks..."
    
    ${VALGRIND} ${SPROG} -xc ?-s.txt > valgrindTest1.viktar 2> valgrindTest1.err
    ${VALGRIND} ${SPROG} -xc ?-s.txt -f valgrindTest2.viktar 2> valgrindTest2.err
    LEAKS=$(grep "${NOLEAKS}" valgrindTest[12].err | wc -l)
    #echo "No leak count ${LEAKS}"
    if [ ${LEAKS} -eq 2 ]
    then
        echo -e "\tNo leaks found in archive create. Excellent."
    else
        echo ">>> Leaks found in archive create."
        LEAKS_FOUND=1
        CLEANUP=0
    fi

    ${VALGRIND} ${SPROG} -tx < valgrindTest1.viktar 2> valgrindTest3.err
    ${VALGRIND} ${SPROG} -tx -f valgrindTest2.viktar 2> valgrindTest4.err
    LEAKS=$(grep "${NOLEAKS}" valgrindTest[34].err | wc -l)
    #echo "No leak count ${LEAKS}"
    if [ ${LEAKS} -eq 2 ]
    then
        echo -e "\tNo leaks found in archive extract. Excellent."
    else
        echo ">>> Leaks found in archive extract.."
        LEAKS_FOUND=1
        CLEANUP=0
    fi

    ${VALGRIND} ${SPROG} -t < valgrindTest1.viktar 2> valgrindTest5.err > valgrindTest5.out
    ${VALGRIND} ${SPROG} -t -f valgrindTest2.viktar 2> valgrindTest6.err > valgrindTest6.out
    LEAKS=$(grep "${NOLEAKS}" valgrindTest[56].err | wc -l)
    #echo "No leak count ${LEAKS}"
    if [ ${LEAKS} -eq 2 ]
    then
        echo -e "\tNo leaks found in small TOC. Excellent."
    else
        echo ">>> Leaks found in small TOC."
        LEAKS_FOUND=1
        CLEANUP=0
    fi

    ${VALGRIND} ${SPROG} -T < valgrindTest1.viktar 2> valgrindTest7.err > valgrindTest7.out
    ${VALGRIND} ${SPROG} -T -f valgrindTest2.viktar 2> valgrindTest8.err > valgrindTest8.out
    LEAKS=$(grep "${NOLEAKS}" valgrindTest[78].err | wc -l)
    #echo "No leak count ${LEAKS}"
    if [ ${LEAKS} -eq 2 ]
    then
        echo -e "\tNo leaks found in big TOC. Excellent."
    else
        echo ">>> Leaks found in big TOC."
        LEAKS_FOUND=1
        CLEANUP=0
    fi
    
    ${VALGRIND} ${SPROG} -ctTV < valgrindTest1.viktar 2> valgrindTest9.err > valgrindTest9.out
    ${VALGRIND} ${SPROG} -ctTV -f valgrindTest2.viktar 2> valgrindTest10.err > valgrindTest10.out
    LEAKS=$(grep "${NOLEAKS}" valgrindTest9.err valgrindTest10.err | wc -l)
    #echo "No leak count ${LEAKS}"
    if [ ${LEAKS} -eq 2 ]
    then
        echo -e "\tNo leaks found in Validate. Excellent."
    else
        echo ">>> Leaks found in Validate."
        LEAKS_FOUND=1
        CLEANUP=0
    fi
    
    echo "** Done with Testing valgrind."
    echo "*** Points so far ${POINTS} of ${TOTAL_POINTS}"
}

cleanTestFiles()
{
    if [ ${CLEANUP} -eq 1 ]
    then
        rm -f Constitution.txt Iliad.txt jargon.txt text-*k.txt words.txt
        rm -f [0-9]-s.txt
        rm -f random-*.bin
        rm -f zeroes-?M.bin zero-sized-file.bin

        rm -f test[01][0-9]_[JS].viktar

        rm -f test0[0-9]_[JS].{toc,err}

        rm -f testX0[0-9]_[JS].viktar

        rm -f *.out *.jout *.sout *.viktar *.jerr *.serr random-333-with*

        rm -f valgrindTest*.err WARN.err validate*.err

        rm -f Jviktar* viktar.o viktar.h
        ln -s ${JDIR}/${PROG}.h .

        make clean 1> /dev/null 2> /dev/null
    fi
}

while getopts "xChl" opt
do
    case $opt in
        x)
            # If you really, really, REALLY want to watch what is going on.
            echo "Hang on for a wild ride."
            set -x
            ;;
        C)
            # Skip removal of data files
            CLEANUP=0
            ;;
        h)
            echo "$0 [-h] [-C] [-x]"
            echo "  -h  Display this amazing help message"
            echo "  -C  Do not remove all the test files"
            echo "  -x  Show LOTS and LOTS and LOTS of text about what is happening"
            echo "  -l  When used with -x, line numbers are prefixed to diagnostic output"
            exit 0
            ;;
        l)
            PS4='Line ${LINENO}: '
            ;;
        \?)
            echo "Invalid option" >&2
            echo ""
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done

HOST=$(hostname -s)
if [ ${HOST} != ${FILE_HOST} ]
then
    echo "This script MUST be run on ${FILE_HOST}"
    exit 1
fi

BDATE=$(date)

build
if [ ${BuildFailed} -ne 0 ]
then
    echo "Since the program build failed (using make), ending test"
    echo "Points = 0"
    exit 1
else
    echo "Build success!"
fi

trap 'signalCaught;' SIGTERM SIGQUIT SIGKILL SIGSEGV
trap 'signalCtrlC;' SIGINT
#trap 'signalSegFault;' SIGCHLD

rm -f test_[0-9][1-9]_[JS].viktar

###################################################
#altBuild
###################################################

copyTestFiles

testHelp

testSmallTOC
testBigTOC

testCreateTextFiles
testCreateBinFiles
testLongName
testBigArchive


testExtractTextFiles

# included with TextFiles
##testExtractBinFiles

####
##testSingleFileExtract

testBadFile
testCRCErrors

testValidate

testValgrind

cleanTestFiles

EDATE=$(date)

echo -e "\n\n*********************************************************"
echo "*********************************************************"
echo "Done with Testing."
echo "Points so far ${POINTS} of ${TOTAL_POINTS}"
echo "This does not include the points from the Makefile-test.bash script"
if [ ${LEAKS_FOUND} -ne 0 ]
then
    echo -e "\n**** But.... Memory leaks were found. That is a 20% deduction. ****"
    POINTS=$(echo ${POINTS} | awk '{print $1 * 0.8;}')
    echo "Points with leak deductions ${POINTS} of ${TOTAL_POINTS}"
    echo -e "OUCH!!! That hurts! Where is my leak detector?\n"
fi

if [ ${WARNINGS} -ne 0 ]
then
    echo -e "\n**** But.... Compiler warnings were found. That is a 20% deduction. ****"
    POINTS=$(echo ${POINTS} | awk '{print $1 * 0.8;}')
    echo "Points with compiler warning deductions ${POINTS} of ${TOTAL_POINTS}"
    echo -e "OUCH!!! That hurts! Where is that compiler warnings fixer-upper?\n"
fi
echo "This does not take into account any late penalty that may apply."

echo -e "\n"
echo "Test begun at     ${BDATE}"
echo "Test completed at ${EDATE}"
echo -e "\n"
echo "+++ TOTAL_POINTS    = ${POINTS} of ${TOTAL_POINTS} ***"
