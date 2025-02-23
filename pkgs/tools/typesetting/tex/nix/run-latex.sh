mkdir -p $out

export VARTEXFONTS=$TMPDIR/texfonts
export TEXMFCNF=$TMPDIR:
echo 'max_print_line = 8192' >> $TMPDIR/texmf.cnf

mkdir root
cd root

startDir=$(perl $copyIncludes $includes)
cd $startDir

for i in $extraFiles; do
    if test -d $i; then
        ln -s $i/* .
    else
        ln -s $i $(stripHash $i)
    fi
done

rootName=$(basename $(stripHash "$rootFile"))

rootNameBase=$(echo "$rootName" | sed 's/\..*//')

if test -n "$generatePDF"; then
    latex=pdflatex
else
    latex=latex
fi

latexFlags="-file-line-error"
tmpFile=$out/log

showError() {
    echo
    echo "LATEX ERROR (LAST LOG LINES SHOWN):"
    tail -n 20 $tmpFile
    bzip2 $tmpFile
    exit 1
}

pass=0

runLaTeX() {
    ((pass=pass+1))
    echo "PASS $pass..."
    if ! $latex $latexFlags $rootName >$tmpFile 2>&1; then showError; fi
    runNeeded=
    if fgrep -q \
        -e "LaTeX Warning: Label(s) may have changed." \
        -e "Rerun to get citations correct." \
        -e "Please rerun LaTeX." \
        "$tmpFile"; then
        runNeeded=1
    fi
    echo
}

echo


if test -n "$copySources"; then
    cp -prd $TMPDIR/root $out/tex-srcs
fi


runLaTeX

for auxFile in $(find . -name "*.aux"); do
    # Run bibtex to process all bibliographies.  There may be several
    # when we're using the multibib package.
    if grep -q '\\citation' $auxFile; then
        auxBase=$(basename $auxFile .aux)
        if [ -e $auxBase.bbl ]; then
            echo "SKIPPING BIBTEX ON $auxFile!"
        else
            echo "RUNNING BIBTEX ON $auxFile..."
            bibtex --terse $auxBase
            cp $auxBase.bbl $out
            runNeeded=1
        fi
        echo
    fi

    # "\pgfsyspdfmark" in the aux file seems to indicate that PGF/TikZ
    # requires a second run (e.g. to resolve arrows between pictures).
    if grep -q pgfsyspdfmark $auxFile; then
        runNeeded=1
    fi
done

if test "$runNeeded"; then
    runLaTeX
fi


if test -f $rootNameBase.idx; then
    echo "MAKING INDEX..."
    if test -n "$compressBlanksInIndex"; then
        appendToVar makeindexFlags "-c"
    fi
    makeindex $makeindexFlags $rootNameBase.idx
    runNeeded=1
    echo
fi

# We check that pass is less than 2 to catch situations where the document is
# simple enough (no bibtex, etc.) so that it would otherwise require only one
# pass but also contains a ToC.
# In essence this check ensures that we do at least two passes on all documents.
if test "$runNeeded" = 1 -o "$pass" -lt 2 ; then
    runLaTeX
fi

if test "$runNeeded"; then
    runLaTeX
fi


if test "$runNeeded"; then
    echo "Hm, still not done :-("
    echo
fi


if test -n "$generatePDF"; then
    cp $rootNameBase.pdf $out
else
    cp $rootNameBase.dvi $out
    if test -n "$generatePS"; then
        echo "CONVERTING TO POSTSCRIPT..."
        dvips $rootNameBase.dvi -o $out/$rootNameBase.ps
        echo
    fi
fi


echo "WARNINGS:"
cat $tmpFile | grep "Warning:" | grep -v "Citation.*undefined" || true

echo
echo "OVERFULL/UNDERFULL:"
cat $tmpFile | egrep "Overfull|Underfull" || true

echo
echo "UNDEFINED REFERENCES:"
cat $tmpFile | grep "Reference.*undefined" || true

echo
echo "UNDEFINED CITATIONS:"
cat $tmpFile | grep "Citation.*undefined" || true

echo
echo "STATS:"
printf "%5d overfull/underfull h/vboxes\n" $(cat $tmpFile | egrep -c "Overfull|Underfull" || true)
printf "%5d undefined references\n" $(cat $tmpFile | grep -c "Reference.*undefined" || true)
printf "%5d undefined citations\n" $(cat $tmpFile | grep -c "Citation.*undefined" || true)
printf "%5d pages\n" \
    $(cat $tmpFile | grep "Output written.*(.*pages" | sed "s/.*(\([0-9]*\) pages.*/\1/" || true)
echo

bzip2 $tmpFile
