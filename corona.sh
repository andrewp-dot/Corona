#!/bin/bash
#mc tinysurvival eu

env POSIXLY_CORRECT=1 | echo -n #trosku ojeb ale uvidme

declare -a csv_files=("")
declare -a bz2_files=("")
declare -a gz_files=("")

usage() {
  echo corona [-h] [FILTERS] [COMMAND] [LOG [LOG2 [...]]
  exit 1; #mozna popsat signal 1 - co znamena ta picovna
}

normal_year_pattern='^[0-9]{4}(\-)((((0[13578]|1[02])(\-)31))|((0[13456789]|1[012])(\-)(30|29))|((0[1-9]|1[0-2])(\-)(0[1-9]|1[0-9]|2[0-8])))$'
leap_year_pattern='^[0-9]{2}([02468][048]|[13579][26])(\-)((((0[13578]|1[02])(\-)31))|((0[13456789]|1[012])(\-)(30))|((0[1-9]|1[0-2])(\-)(0[1-9]|1[0-9]|2[0-9])))$'

#overenia na format prepinacov
verify_date() {
    echo date verification $1; #regexp
    if [[ $1 =~ $normal_year_pattern ]] || [[ $OPTARG =~ $leap_year_pattern ]] #yyyy-mm-dd - basic verification - to ADD: limity, priestupne roky / kvôli februáru, validácia poctu dni
    then 
        echo "the date format is valid"
        date_is_valid="true"
    else
      echo "Invalid date: $1"
      date_is_valid="false"
    fi
}

age_regex='^[1-9][0-9]*$'
verify_age(){
  if ! [[ $1 =~ $age_regex ]]
  then 
    echo Invalid age: 
  else
    echo age is good 
  fi
}

#premenne pre histogram
histogram="false" # ci bol zadany prepinac
histogram_width=""
max_value=1
histogram_commands='^(gender|age|daily|monthly|yearly|countries|districts|regions)$'

check_histogram_width() {
  histogram="true"

  if [[ $1 =~ ^[1-9][0-9]*$ ]] 
  then 
  histogram_width=$1
  max_value="get_max_value"
  else
    if [[ $1 =~ $optstring_commands ]]
    then
      ((OPTIND--))  #option index - 1 preto, aby sme nepreskocili prikaz, ak by bol za prepinacom -s rovno prikaz
    fi
  fi
}

#inicializacia filtrov
after_date="0-0-0" #implicitna najnizsia hodnota - pri porovnani stringov nie je nic mesnie ako 0 (v nasom pripade pri porovnavani cisel)
before_date="9-9-9" 
gender=""

# filtre a prikazy
optstring_filters=":a:b:g:s:h"
optstring_commands='^(infected|merge|gender|age|daily|monthly|yearly|countries|districts|regions)$'
head_regex='(id,datum,vek,pohlavi,kraj_nuts_kod,okres_lau_kod,nakaza_v_zahranici,nakaza_zeme_csu_kod,reportovano_khs)'
header="id,datum,vek,pohlavi,kraj_nuts_kod,okres_lau_kod,nakaza_v_zahranici,nakaza_zeme_csu_kod,reportovano_khs"
new_line_regex='^([[:space:]]*|\r\n|\r|\n)$'

while getopts "${optstring_filters}" options; 
do 
  case "${options}" in
    a) verify_date $OPTARG; 
    if [[ "$date_is_valid" = "true" ]]
    then after_date="$OPTARG"
    fi
    ;;
    b) verify_date $OPTARG; 
    if [[ "$date_is_valid" = "true" ]]
    then before_date="$OPTARG"
    fi
    ;;
    g) gender=$OPTARG
    ;;
    s) check_histogram_width $OPTARG ;
    ;;
    h) usage
    ;;
    ?) echo Invalid option ; usage
    ;;
  esac
done

#ziskanie stringu - ocakaveho prikazu a overenie, ci to je prikaz
eval command=\$${OPTIND} #ziskanie nasledujuceho argumentu, ktory by mal byt command

if ! [[ $command =~ $optstring_commands ]]
then 
    command=""  
fi

head_count=0

#nacitanie z konkretneho suboru
read_data(){ #input type mi je na vyliz picu 
  if [[ "$input_type" = "csv" ]];then 
    if ((head_count == 0)); then
        read -r head < $1
        echo $head
        ((head_count++))
    fi
    if [[ "$gender" == "" ]];then
      awk -F, -v new_line="$new_line_regex" -v before="$before_date" -v after="$after_date" '$0 !~ new_line && after <=$2 && $2<= before ' $1 
    else
      awk -F, -v new_line="$new_line_regex" -v before="$before_date" -v after="$after_date" -v gend="$gender" '$0 !~ new_line && after <=$2 && $2<= before && $4 == gend' $1
    fi

  else
  if [[ "$gender" == "" ]];then 
  if ((head_count == 0)); then
        gzcat -q $1 | read -r head 
        echo $head
        ((head_count++))
    fi
      awk -F, -v new_line="$new_line_regex" -v before="$before_date" -v after="$after_date" '$0 !~ new_line && after <=$2 && $2<= before ' $1
    else
      awk -F, -v new_line="$new_line_regex" -v before="$before_date" -v after="$after_date" -v gend="$gender" '$0 !~ new_line && after <=$2 && $2<= before && $4 == gend' $1
    fi
  fi
}

#nacitanie zo standartneho vstupu
read_from_stdin() { #dobra na merge, ale treba vytvorit univerzalnu funkciu, ktora executne command passnuty do nej jak argument
  while read -r line 
        do
        if (( $head_count == 0 )) && [[ $line =~ $head_regex ]]; then
          echo "$line" 
          (( head_count++ ))
        fi

        if ! [[ $line =~ $head_regex ]]; then 
          if [[ "$gender" == "" ]];then 
            echo "$line" | awk -F, -v new_line="$new_line_regex" -v before="$before_date" -v after="$after_date" '$0 !~ new_line && after <=$2 && $2<= before'
          else 
            echo "$line" | awk -F, -v new_line="$new_line_regex" -v before="$before_date" -v after="$after_date" -v gend="$gender" '$0 !~ new_line && after <=$2 && $2<= before && $4 == gend' 
          fi
        fi
  done
}

#COMMANDS

infected() { #completed
  number_infected=0
if [[ "$gender" == "" ]];then 

  if [[ "$input_type" == "stdin" ]]; then
  (( number_infected+=$(awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
    '$0 !~ new_line && $0 !~ head && after <= $2 && $2 <= before'  | wc -l ) ))
  fi

  #csv
  for csv in "${csv_files[@]}";do
    if [[ "$csv" != "" ]]; then
    (( number_infected+=$(awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
    '$0 !~ new_line && $0 !~ head && after <= $2 && $2 <= before' $csv | wc -l ) ))
    fi
  done
  
  #bz
  for bzf in "${bz2_files[@]}"; do
    (( number_infected+=$( gzcat -q $bzf |awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
    '$0 !~ new_line && $0 !~ head && after <= $2 && $2 <= before'  | wc -l ) ))
  done
  
  #gzf
  for gzf in  "${gz_files[@]}"; do
    (( number_infected+=$(gzcat -q $gzf |awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
    '$0 !~ new_line && $0 !~ head && after <= $2 && $2 <= before'  | wc -l ) ))
  done

else 
  if [[ "$input_type" == "stdin" ]]; then
  (( number_infected+=$(awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date" -v gend="$gender" \
       '$0 !~ new_line && $0 !~ head && after <=$2 && $2<= before && $4 == gend' | wc -l ) ))
  fi

  #csv
  for csv in "${csv_files[@]}"; do
   if [[ "$csv" != "" ]]; then
      (( number_infected+=$(awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date" -v gend="$gender" \
       '$0 !~ new_line && $0 !~ head && after <=$2 && $2<= before && $4 == gend' $csv | wc -l ) ))
    fi
  done

  #bz
  for bzf in "${bz2_files[@]}"; do 
      (( number_infected+=$(gzcat -q $bzf |awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date" -v gend="$gender"\
        '$0 !~ new_line && $0 !~ head && after <=$2 && $2<= before && $4 == gend'  | wc -l ) ))
  done
    
  #gzf
  for gzf in  "${gz_files[@]}"; do
      (( number_infected+=$(gzcat -q $gzf |awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date" -v gend="$gender"\
      '$0 !~ new_line && $0 !~ head && after <=$2 && $2<= before && $4 == gend'  | wc -l ) ))
  done
fi
  echo $number_infected 

}

merge() { #completed
  if [[ $input_type == "stdin" ]] ; then
    read_from_stdin
  fi

if [[ "$gender" == "" ]];then 
  #csv
  for csv in "${csv_files[@]}";do
    if [[ "$csv" != "" ]]; then
      awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
      '$0 !~ new_line && $0 !~ head && after <= $2 && $2 <= before' $csv 
    fi
  done
  
  #bz
  for bzf in "${bz2_files[@]}"; do
    gzcat -q $bzf |awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
    '$0 !~ new_line && $0 !~ head && after <= $2 && $2 <= before' 
  done
  
  #gzf
  for gzf in  "${gz_files[@]}"; do
    gzcat -q $gzf |awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
    '$0 !~ new_line && $0 !~ head && after <= $2 && $2 <= before' 
  done

else 

  #csv
  for csv in "${csv_files[@]}"; do
    if [[ "$csv" != "" ]]; then
      awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date" -v gend="$gender" \
       '$0 !~ new_line && $0 !~ head && after <=$2 && $2<= before && $4 == gend' $csv  
    fi
  done

  #bz
  for bzf in "${bz2_files[@]}"; do 
      gzcat -q $bzf |awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date" -v gend="$gender"\
        '$0 !~ new_line && $0 !~ head && after <=$2 && $2<= before && $4 == gend'
  done
    
  #gzf
  for gzf in  "${gz_files[@]}"; do
   gzcat -q $gzf |awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date" -v gend="$gender"\
      '$0 !~ new_line && $0 !~ head && after <=$2 && $2<= before && $4 == gend' 
  done
fi

}

gender() { #completed
men=0
women=0
  for csv in "${csv_files[@]}";do
      (( men+=$( awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
      '$0 !~ new_line && $0 !~ head && $4 == "M" && after <= $2 && $2 <= before'  $csv | wc -l) ))
      (( women+=$( awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
      '$0 !~ new_line && $0 !~ head && $4 == "Z" && after <= $2 && $2 <= before' $csv | wc -l) ))
    done

    for bzf in "${bz2_files[@]}"; do
      (( men+=$( gzcat -q $bzf | awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
      '$0 !~ new_line && $0 !~ head && $4 == "M" && after <= $2 && $2 <= before' | wc -l) ))
      (( women+=$( gzcat -q $bzf |awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
      '$0 !~ new_line && $0 !~ head && $4 == "Z" && after <= $2 && $2 <= before' | wc -l) ))
    done

    for gzf in "${gz_files[@]}"; do
      (( men+=$( gzcat -q $gzf | awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
      '$0 !~ new_line && $0 !~ head && $4 == "M" && after <= $2 && $2 <= before' | wc -l) ))
      (( women+=$( gzcat -q $gzf | awk -F, -v new_line="$new_line_regex" -v head="$head_regex" -v before="$before_date" -v after="$after_date"\
      '$0 !~ new_line && $0 !~ head && $4 == "Z" && after <= $2 && $2 <= before' | wc -l) ))
    done  

case "$gender" in 
  M) echo M: $men ;;
  Z) echo Z: $women ;;
  "")  echo M: $men ; echo Z: $women ;;
   #$( awk -F, '$4 == "M"'  $csv | wc -l) ; echo Z: $( awk -F, '$4 == "Z"' $csv | wc -l) ;;
esac
#if [[ "$histogram" == "true" ]]
}

age() { #dorobit zarovnanie
  #podla intervalov vypise statistiku (tabulka)
  awk -F, -v count0_5=0 -v count6_15=0 -v count16_25=0 -v count26_35=0 -v count36_45=0 -v count46_55=0 -v count56_65=0 -v\
  count66_75=0 -v count76_85=0 -v count86_95=0 -v count96_105=0 -v above_105=0 \
  'NR ==1 {next}\
  0 <= $3 && $3 <= 5 {count0_5++ } \
  6 <= $3 && $3 <= 15 {count6_15++ } \
  16 <= $3 && $3 <= 25 {count16_25++ }\
  26 <= $3 && $3 <= 35 {count26_35++ }\
  36 <= $3 && $3 <= 45 {count36_45++ }\
  46 <= $3 && $3 <= 55 {count46_55++ }\
  56 <= $3 && $3 <= 65 {count56_65++ }\
  66 <= $3 && $3 <= 75 {count66_75++ }\
  76 <= $3 && $3 <= 85 {count76_85++ }\
  86 <= $3 && $3 <= 95 {count86_95++ }\
  96 <= $3 && $3 <= 105 {count96_105++ }\
  105 < $3 {above_105++ }

END{ 
printf("\
0-5 : %d\n\
6-15 : %d\n\
16-25 : %d\n\
26-35 : %d\n\
36-45 : %d\n\
46-55 : %d\n\
56-65 : %d\n\
66-75 : %d\n\
76-85 : %d\n\
86-95 : %d\n\
96-105 : %d\n\
> 105 : %d\n",
    count0_5 , count6_15 , count16_25 , count26_35 , count36_45, count46_55 , count56_65 , count66_75\
    , count76_85 , count86_95 , count96_105 , above_105)
  }' $1 #dorobit formatovanie
#if [[ "$histogram" == "true" ]]
}

daily() {
  #ulozit jeden datum do pola a vnimat zmeny tadaa
  #prist na sposob, ako vyfiltrovat vsetky datumy
  echo daily... #statistika podla dni
  #asi regexp 
}

monthly() {
  echo monthly... #podla mesiacov
}

yearly() {
  echo yearly... #podla rokov
}

countries() { #completed - pridat formatovanie
  awk -F, '$8 != "CZ" && $8 != ""  {countries[$8] += 1} END{for (country in countries) printf("%s : %d\n", country, countries[country])}'
}

districts() { #completed - pridat formatovanie
  awk -F, '$6 != ""  {districts[$6] += 1} END{for (district in districts) printf("%s : %d\n", district, districts[district])}'
}

regions() { #completed - pridat formatovanie
  awk -F, '$5 != ""  {regions[$5] += 1} END{for (region in regions) printf("%s : %d\n", region, regions[region])}'
}


# awk -F, -v before="$before_date" -v after="$after_date" -v gend="gender" 'after <=$2 && $2<= before && $4 == gend' $1

input_type="stdin"
index=0
csv_idx=0
bz_idx=0
gz_idx=0
while (( $index != $#+1 ))
do
  eval file=\$$index
  if [[ $file =~ ^.*\.csv$ ]] 
  then input_type="csv" ; csv_files[$csv_idx]="$file" ; ((csv_idx++))
  elif [[ $file =~ ^.*\.bz2$ ]]
  then input_type="bz2" ; bz2_files[$bz_idx]="$file" ; ((bz_idx++))
  elif [[ $file =~ ^.*\.gz$ ]]
  then input_type="gz" ; gz_files[$gz_idx]="$file" ;((gz_idx++))
  fi 
  # if (( $index == $# )) && [[ "$input_type" == "stdin" ]];then
  #     read_from_stdin #fix this
  # fi
  ((index++))
done 

case "$command" in 
    infected) infected ;;
    merge) echo $header; merge | sort -d ;;
    gender) gender ;;
    age) merge | age ;;
    daily) daily ;;
    monthly) monthly ;;
    yearly) yearly ;;
    countries) merge | countries | sort -d  ;;
    districts) merge | districts | sort -d ;;
    regions) merge | regions | sort -d ;;
    "") echo $header; merge | sort -d ;;
esac

# awk -F, -v norm_date="$normal_year_pattern" -v leap_date="$leap_year_pattern" -v age=$age_regex 'NR == 1{next}\
# ( $2 !~ norm_date && $2 !~ leap_date) {printf("Invalid date: %s\n",$0)| "cat 1>&2"}\
# ($3 !~ age && $3 != "") {printf("Invalid age: %s\n", $0) | "cat 1>&2"}'   #este vyriesit kde a ako to vypisat

exit 0;

#NAPAD ZA MILION - dat si premennu INPUT alebo pole INPUTFILES a z toho vytahovat data 

#useful pattern
# if [[ "$gender" == "" ]];then 

#   if [[ "$input_type" == "stdin" ]]; then
#   fi

#   #csv
#   for csv in "${csv_files[@]}";do
#     if [[ "$csv" != "" ]]; then
#     fi
#   done
  
#   #bz
#   for bzf in "${bz2_files[@]}"; do
#   done
  
#   #gzf
#   for gzf in  "${gz_files[@]}"; do
#   done

# else 
#   if [[ "$input_type" == "stdin" ]]; then
#   fi

#   #csv
#   for csv in "${csv_files[@]}"; do
#     if [[ "$csv" != "" ]]; then
#     fi
#   done

#   #bz
#   for bzf in "${bz2_files[@]}"; do 
#   done
    
#   #gzf
#   for gzf in  "${gz_files[@]}"; do
#   done
# fi