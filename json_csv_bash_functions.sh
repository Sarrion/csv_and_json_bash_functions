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
        echo "Usage: sarrion.generate_csv <field_1_name>,<field_1_type> [<field_2_name>,<field_2_type> ...] <number_of_rows>"
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



function sarrion.inner_join {
    # Check that two arguments were passed
    if [ $# -lt 2 ]; then
        echo "Usage: <csv_1_content> | sarrion.inner_join <join_field_x_fst_csv_name>=<join_field_y_snd_csv_name>[,<join_field_x2_fst_csv_name>=<join_field_y2_snd_csv_name> ...] <csv_2>"
        echo ""
        echo 'example usage: cat example1.csv | sarrion.inner_join "fst_csv_field1=snd_csv_field2,fst_csv_field3=snd_csv_field3" example2.csv'
        return 1
    fi

    # read the join fields as a comma-separated list
    local join_fields=($(echo "$1" | tr ',' ' '))

    # read the second CSV file
    local csv2_file="$2"
    local -a csv2_headers
    read -r -a csv2_headers < <(head -n 1 "$csv2_file")
    local csv2_num_fields="${#csv2_headers[@]}"

    # build the join fields for the second CSV file
    local -a csv2_join_fields
    for join_field in "${join_fields[@]}"; do
        local csv2_field=$(echo "$join_field" | cut -d '=' -f 2)
        csv2_join_fields+=("${csv2_headers[@]/$csv2_field}")
    done

    # loop through the first CSV file and perform the join
    while read -r csv1_line; do
        # split the line into fields
        IFS=',' read -r -a csv1_fields <<< "$csv1_line"
        local csv1_num_fields="${#csv1_fields[@]}"
        
        # check if the join fields match any lines in the second CSV file
        local -a csv2_lines
        while read -r csv2_line; do
            # split the line into fields
            IFS=',' read -r -a csv2_fields <<< "$csv2_line"
            local csv2_num_fields="${#csv2_fields[@]}"
            
            # check if the join fields match
            local match=true
            for join_field in "${join_fields[@]}"; do
                local csv1_field=$(echo "$join_field" | cut -d '=' -f 1)
                local csv2_field=$(echo "$join_field" | cut -d '=' -f 2)
                local csv1_index=$(echo "${csv1_headers[@]}" | tr ' ' '\n' | grep -n "^$csv1_field$" | cut -d ':' -f 1)
                local csv2_index=$(echo "${csv2_headers[@]}" | tr ' ' '\n' | grep -n "^$csv2_field$" | cut -d ':' -f 1)
                if [[ "${csv1_fields[$csv1_index]}" != "${csv2_fields[$csv2_index]}" ]]; then
                    match=false
                    break
                fi
            done
            
            if $match; then
                csv2_lines+=("$csv2_line")
            fi
        done < <(tail -n +2 "$csv2_file")
        
        # output the matched lines
        local num_csv2_lines="${#csv2_lines[@]}"
        for ((i=0; i<$num_csv2_lines; i++)); do
            local csv2_line="${csv2_lines[$i]}"
            echo "${csv1_line},${csv2_line}"
        done
        unset csv2_lines
    done
}



function sarrion.generate_json {
  # check that 2 arguments have been passed
  if [ $# -lt 2 ]; then
    echo "usage: sarrion.generate_json <int> 0"
    return 1
  fi

  local max_depth="$1"
  local depth="$2"

  if ((depth > max_depth)); then
    echo "\"$(date +%s)\""
  else
    local array_size=$((RANDOM % 5 + 1))
    local json="{"

    # Generate random keys and values
    for ((i=0; i<$array_size; i++)); do
      local key=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)
      local value=""
      local rand=$((RANDOM % 7))

      case $rand in
        0) value="\"$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 10)\"" ;;
        1) # Comma-separated array
          local array_size=$(( RANDOM % 5 + 1 ))
          local array=""
          for (( i=0; i<$array_size; i++ )); do
            array="$array$(generate_json $max_depth $(( depth + 1 ))),"
          done
          array="${array%?}"
          value="[$array]"
          ;;
        2) value="$((RANDOM % 1000))" ;;
        3) value="$((RANDOM % 1000)).$((RANDOM % 100))" ;;
        4) value="$(generate_json $max_depth $((depth + 1)))" ;;
        5) value="\"$(date +%Y%m%d)\"" ;;
        6) value="\"$(date +%Y%m%d\ %H:%M:%S)\"" ;;
      esac

      # Append the key-value pair to the JSON string
      json+="\"$key\":${value:default},"

    done

    # Remove the trailing comma and close the JSON string
    json="${json%,}}"

    echo "$json"
  fi
}

