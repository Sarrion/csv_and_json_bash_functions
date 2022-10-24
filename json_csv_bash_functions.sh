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

    readarray data
    header=$(echo ${data[0]} | head -n 1)
    header=$(echo $header | tr " ./?" "_" | tr "," " ")
    header=($(echo $header))

    for i in "${!header[@]}"
    do
	$(echo "declare ${header[$i]}=$(( $i + 1 ))")
    done

    col_selection=$1
    col_selection=$(echo $col_selection | tr " ./?" "_" | tr "," " ")
    col_selection=($(echo $col_selection))

    command=`printf "$%s " "${col_selection[@]}"`

    command=$(eval "echo $command")
    command=$(echo $command | sed -E 's/([0-9]*)/$\1,/g; s/,$//')
    command="BEGIN{FS=\",\"; OFS=\",\"} { print $command }"

    printf "%s" "${data[@]}" | awk "$command"
}



function sarrion.filter {

    readarray data
    header=$(echo ${data[0]} | head -n 1)
    header=$(echo $header | tr " ./?" "_" | tr "," " ")
    header=($(echo $header))


    n=1
    for i in "${header[@]}"
    do
        eval `printf "%s='$%s'" "$i" "$n"`
	n=$(( $n + 1 ))
    done

    eval "condition=\"\`echo \$$1\`\""

    condition="`echo $condition | sed -E 's/([^ =<>~!]*)([ =<>~!]*)([^=<>{!]*)/\1\2"\3"/'`"
    command="BEGIN { FS=\",\"; OFS=\",\" } { if( NR==1 || $condition) { print \$0 } }"

    printf "%s" "${data[@]}" | awk "$command"
}



function sarrion.csvpprint {
    sed 's/,,/, ,/g' | awk 'BEGIN {FS=","}{print} NR==1 {gsub(/[^,]/, "-"); print}' | column -s, -t
}
