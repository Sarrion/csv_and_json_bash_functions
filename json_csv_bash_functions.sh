#!/bin/bash


# add nesting index
function sarrion.add_nest_idx {
    awk 'BEGIN {
           nest_lvl = 0
         }

         {  
           print nest_lvl " " $0
	   curl_br = gsub(/{/, "{")
	   sq_br = gsub(/\[/, "\[")    # this is the only one that needs scape
	   back_curl_br = gsub(/}/, "}") 
	   back_sq_br = gsub(/]/, "]")
	   nest_lvl += curl_br + sq_br - back_curl_br - back_sq_br
	 }'
}

function sarrion.tree {
    sarrion.add_nest_idx | \
    awk '{ if( $1 <= level ) print $0 }' level=$1
}



######
# CSV Utilities
#####
function sarrion.select {

    data=$(</dev/stdin)
    header=$(echo $data | head -n 1)
    header=$(echo $header | tr " ./" "_" | tr "," " ")
    header=($(echo $header))

    for i in {1..${#header[@]}}
    do
        $(echo "declare $header[$i]=$i")
    done

    col_selection=$1
    col_selection=$(echo $col_selection | tr " ./" "_" | tr "," " ")
    col_selection=($(echo $col_selection))

    command=""
    for col in "${col_selection[@]}"
    do
        command="$command\$$col "
    done

    command=$(eval "echo $command")
    command=$(echo $command | sed -E 's/([0-9]*)/$\1,/g; s/,$//')
    command="BEGIN{FS=\",\"; OFS=\",\"} { print $command }"

    echo $data | awk "$command"
}



function sarrion.filter {

    data=$(</dev/stdin)
    header=$(echo $data | head -n 1)
    header=$(echo $header | tr " ./" "_" | tr "," " ")
    header=($(echo $header))

    for i in {1..${#header[@]}}
    do
        $(echo "declare $header[$i]=$i")
    done

    col=$(echo $1 | sed -E 's/([^=]*)=.*/$\1/' | tr " ./" "_")
    col=$(eval "echo $col" | sed -E 's/([0-9]*)/$\1/')
    value=$(echo $1 | sed -E 's/[^=]*=([^=]*)/\1/')

    command="BEGIN { FS=\",\"; OFS=\",\" } { if( NR==1 || $col == \"$value\") { print \$0 } }"

    echo $data | awk "$command"
}



function sarrion.csvpprint {
    awk 'BEGIN {FS=","}{print} NR==1 {gsub(/[^,]/, "-"); print}' | column -s, -t
}
