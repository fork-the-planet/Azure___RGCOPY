# bash\verify-job.sh

echo ">> Verify started - $(date -u +"%H:%M:%S")" >>$backupLog

tar -df $backupFile . \
    --record-size=$blocksize_kb\K \
    --checkpoint=$blocks_per_checkpoint \
    --checkpoint-action="$action" 2>&1 >>$backupLog
rc=$?
if [ $rc -ne 0 ]; then 
    echo "> ERROR: tar return code: $rc" >>$backupLog
    echo '++ exit 1'
    exit 1
else 
    echo ">> tar return code: $rc" >>$backupLog; 
fi

echo ">> Verify finished - $(date -u +"%H:%M:%S")" >>$backupLog
