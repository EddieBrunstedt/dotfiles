function reminders --description "List pending at reminders"
    set -l jobs (atq -o '%Y-%m-%d %a %H:%M' | sort -t \t -k2)
    if test (count $jobs) -eq 0
        echo "No reminders"
        return
    end

    for job in $jobs
        set -l fields (string split \t -- $job)
        set -l id $fields[1]
        # atq appends the queue and user after the time
        set -l when (string replace -r ' \S+ \S+$' '' -- $fields[2])

        # The command is everything after the cd block at puts in every job
        set -l cmd (at -c $id | sed '1,/^}$/d' | string match -v '' | string join '; ')
        if string match -q "notify-send -u critical Reminder *" -- $cmd
            # Undo the sh quoting remind added around the message
            set cmd (string replace 'notify-send -u critical Reminder ' '' -- $cmd \
                | string replace -r "^'(.*)'\$" '$1' \
                | string replace -a "'\\''" "'")
        end

        printf '#%-3s %s  %s\n' $id $when $cmd
    end
end
