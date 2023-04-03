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

    condition=`echo $1 | sed 's/"/__doublequotes__/g'`
    eval "condition=\"\`echo \$$condition\`\""
    condition="`echo $condition | sed -E 's/__doublequotes__/"/g'`"

    command="BEGIN { FS=\",\"; OFS=\",\" } { if( NR==1 || $condition) { print \$0 } }"

    printf "%s" "${data[@]}" | awk "$command"
}



function sarrion.csvpprint {
    sed 's/,,/, ,/g' | awk 'BEGIN {FS=","}{print} NR==1 {gsub(/[^,]/, "-"); print}' | column -s, -t
}



function sarrion.generate_csv {
    # Check that two arguments were passed
    if [ $# -lt 2 ]; then
        echo "Usage: generate_csv <field_1_name>,<field_1_type> [<field_2_name>,<field_2_type> ...] <number_of_rows>"
        return 1
    fi



  # print header
  local header=""
  for pair in "${@:1:$#-1}"; do
    fst="${pair%,*}"
    header+="${fst},"
  done
  echo "${header::-1}"

  # Generate random data for each field
  last_arg="${@: -1}"
  for ((i=0; i<$last_arg; i++)); do
    local row=""
    # Generate random values for each field based on the field type
    for pair in "${@:1:$#-1}"; do
        type="${pair#*,}"
        case $type in
            int)
                val="$((RANDOM % 100))"
                ;;
            string)
                val="$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 10 | head -n 1)"
                ;;
            float)
                val="$(awk -v min=0 -v max=1 'BEGIN{srand(); print min+rand()*(max-min)}' | tr ',' '.')"
                ;;
            date)
                val="$(date -d "$((RANDOM % 30)) days ago" +%Y%m%d)"
                ;;
            datetime)
                val="$(date -d "$((RANDOM % 30)) days ago $((RANDOM % 24)) hours ago $((RANDOM % 60)) minutes ago" +"%Y%m%d %H:%M:%S")"
                ;;
        esac
        row+="${val},"
    done
    echo "${row::-1}" 
  done
}

