# Explain a shell command with an LLM (pi) without running it.
#   explain [--debug] [command ...]
# With no command, explains the current commandline (it is bound to ctrl-e),
# falling back to the last history entry. Each word is first resolved through
# fish (functions, aliases, abbreviations, binaries) so the agent describes
# what actually runs. The agent may consult documentation with its tools; each
# tool call streams as a dim line while the final markdown answer is
# highlighted by bat. --debug prints the assembled prompts instead of calling pi.
function explain --description 'Explain a shell command via pi'
    argparse --ignore-unknown d/debug -- $argv; or return

    set -l src
    set -l cmd
    if set -q argv[1]
        set cmd (string join ' ' -- $argv)
        set src arguments
    else
        set cmd (commandline)
        set src commandline
        if test -z "$cmd"
            set cmd $history[1]
            set src 'history[1]'
        end
    end
    if test -z "$cmd"
        commandline -f repaint
        return 1
    end

    set -l words (string split -n ' ' -- $cmd)
    set -l ctx
    set -l seen
    for word in $words
        string match -qr -- '^[[:alnum:]_.][[:alnum:]_.-]*$' $word; or continue
        contains -- $word $seen; and continue
        set -a seen $word
        set -l re (string escape --style=regex -- $word)
        set -l res (type -a -- $word 2>/dev/null | string collect)
        test -n "$res"; and set -a ctx (string sub -l 1200 -- $res)
        set -a ctx (abbr --show | string match -r -- "^abbr .*-- $re .*")
    end
    if not type -q -- $words[1]; and not abbr -q -- $words[1]
        set -a ctx "Note: '$words[1]' does not resolve to any command, function, alias or abbreviation on this system."
    end

    set -l system_prompt "You explain shell commands concisely, including what each flag does. Answer in markdown. Background context, in case it is relevant: this is an Arch Linux system with the fish shell. Do not mention this context unless it actually matters for the command at hand. You may use your tools to consult documentation (man pages, --help output, package queries) when you are unsure, but NEVER execute the command you are asked to explain, nor anything else with side effects. Your bash tool cannot see fish definitions directly: to inspect a fish function, alias or abbreviation that is not already in the context (e.g. one referenced inside another function's body), run fish -c 'type -a NAME' or fish -c 'abbr --show' via bash."
    if test -n "$ctx"
        set -l ctxtext (string join \n $ctx | string collect)
        set system_prompt "$system_prompt

Context gathered from the user's shell, showing how each word of the command resolves (functions, aliases, abbreviations, binaries). Explain what actually runs; mention shadowed binaries only if relevant. The user CANNOT see this context, so never refer to it as 'shown' or 'above' — quote whatever parts you need in your answer:

$ctxtext"
    end
    set -l prompt "Explain this command: $cmd"

    set -l pi_flags -p --no-session --mode json
    set -l dim (set_color --dim)
    set -l off (set_color normal)

    if set -q _flag_debug
        set -l hl (set_color --bold cyan)
        echo $hl"command"$off" (from $src): $cmd"
        echo $hl"pi invocation:"$off" pi $pi_flags --system-prompt <system-prompt> <prompt>"
        echo $hl"resolved words:"$off" $seen"
        echo
        echo $hl"system prompt:"$off
        echo "$system_prompt"
        echo
        echo $hl"prompt:"$off
        echo "$prompt"
        echo
        set -l sys_len (string length -- "$system_prompt")
        set -l pr_len (string length -- "$prompt")
        echo $hl"sizes:"$off" system prompt $sys_len chars, prompt $pr_len chars (~"(math "round(($sys_len + $pr_len) / 4)")" tokens)"
        return 0
    end

    echo
    echo $dim"explaining: $cmd"$off
    pi $pi_flags \
        --system-prompt "$system_prompt" \
        "$prompt" \
        | jq -r --unbuffered --arg dim $dim --arg off $off '
            if .type == "tool_execution_start" then
                ("\($dim)  ⚙ \(.toolName) \(.args | tostring | .[0:120])\($off)\n" | stderr | empty)
            elif .type == "agent_end" then
                [.messages[] | select(.role == "assistant") | .content[] | select(.type == "text") | .text] | last // empty
            else
                empty
            end' \
        | command bat -l md --style plain --paging never
    # The two-line prompt makes repaint redraw starting one line above the
    # cursor; leave a blank line for it to consume instead of the output.
    echo
    commandline -f repaint
end
