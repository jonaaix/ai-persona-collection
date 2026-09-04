#!/bin/bash
INPUT=$(cat)
SESSION=$(jq -r '.session_id' <<<"$INPUT")
COUNTER="/tmp/claude-loop-$SESSION"
COUNT=$(cat "$COUNTER" 2>/dev/null || echo 0)

[ "$COUNT" -ge 20 ] && exit 0
echo $((COUNT + 1)) > "$COUNTER" || exit 0

if [ $((COUNT % 3)) -eq 0 ]; then
    TASK="Find one innovative feature that would genuinely improve the app and the business. Propose it in the log only, no code."
else
    TASK="Find one improvement to the quality of the app. Implement it and commit it."
fi

jq -n --arg t "$TASK" '{decision:"block",reason:("Read .ai/loop-log.md first to see what earlier rounds already did. Then: " + $t + " One thing only. Append one line to .ai/loop-log.md.")}'