# Long tree (native flags appended after $argv so a leading depth number still works)
function lst --description "eza long tree (lt + -l --group --smart-group)"
    lt $argv -l --group --smart-group
end
