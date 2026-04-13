# bash\backup-compare.sh

echo ">> Compare started - $(date -u +"%H:%M:%S")" >>$backupLog

comm -23 <(\
    find . -type f -printf "%M\t%u/%g\t%s\t%TY-%Tm-%Td\t%TH:%TM\t%p\n" \
    | sort \
) <(\
    tar -tvf $backupFile \
    | grep "^-" \
    | sed -E 's/ +/\t/g' \
    | sort \
) >$backupFile.err

if [[ -s $backupFile.err ]]; then
    echo ""
    head $backupFile.err >>$backupLog
    echo ""
    echo "> ERROR: backup files have been changed" >>$backupLog
    echo '++ exit 1'
    exit 1
fi

echo ">> Compare finished - $(date -u +"%H:%M:%S")" >>$backupLog
