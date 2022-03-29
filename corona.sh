#!/bin/bash

env POSIXLY_CORRECT=1 | echo -n #trosku ojeb ale uvidme

#BEGIN
#funkcia na vypis pouzitia a ukoncenie corona aplikacie
usage() {
  echo corona [-h] [FILTERS] [COMMAND] [LOG [LOG2 [...]]
  exit 1; #mozna popsat signal 1 - co znamena ta picovna
}

#OUTPUT
# Pokud má skript vypsat seznam, každá položka je vypsána na jeden řádek a pouze jednou. Není-li uvedeno jinak, je pořadí řádků dáno abecedně. Položky se nesmí opakovat.
# Pokud skript nedostane ani filtr ani příkaz, opisuje záznamy na standardní výstup.
# Grafy jsou vykresleny pomocí ASCII a jsou otočené doprava. Hodnota řádku je vyobrazena posloupností znaku mřížky #.

#FILTERS

#verifying filters
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

histogram_width=""
histogram_commands='^(gender|age|daily|monthly|yearly|countries|districts|regions)$'

#PREPINAC -s

#histogram_width
#max_value 

#ak je zadany prepinac s:


#nacitaj argument a over ho
# PO PRVE 
    #neprazndy argument
      #nacitaj do premennej histogram_width
# PO DRUHE
    #prazdny
      #postupuj podla defaultnych hodnot (pre kazdy z histogram_commands vlastna hodnota)


#ak neni zadany prepinac s;
 #postupuj standardnym behom programu


# gender — 100 000
# age — 10 000
# daily — 500
# monthly — 10 000
# yearly — 100 000
# countries — 100
# districts — 1 000
# regions — 10 000

# VZOREC na vypocet pre grafy: 
# WIDTH - defined:
#  WIDTH - pocet mriezok v grafe s najvacsou hodnotou: 
#cislo/max-width = WIDTH, kde x je najvacsie cislo => pocet# = cislo/max_value * histogram_width (zaokruhlovat dole.) 
#PRIPAD CISLO 1. ak je sirka definovana - # = (cislo = max_value)/max_value * histogram_width = histogram_width
#PRIPAD CISLO 2. ak je sirka nedefinovana - # 'cislo/max_value * 1 = cislo/max_value

check_histogram_width() {
  if [[ $1 =~ ^[1-9][0-9]*$ ]] #mozno dorobit overenie pre cisla jebnuteho typu 0000025 atd
  then 
  histogram_width=$1
  max_value="get_max_value"
  else
    if [[ $1 =~ $optstring_commands ]]
    then
      ((OPTIND--)) 
    fi
  fi
}

#PRIPAD CISLO 2
# if [[ "$histogram_width" = "" ]]
#histogram_width=1
# case "$command" in 
#     "gender") 
#          max_value=100000
#     ;;
#     "age")
#          max_value=10000
#     ;;
#     "daily")
#          max_value=500
#     ;;
#     "monthly")
#          max_value=10000
#     ;;
#     "yearly")
#          max_value=100000
#     ;;
#     "countries")
#          max_value=100
#     ;;
#     "districts")
#          max_value=1000
#     ;;
#     "regions")
#          max_value=10000
#     ;;
# esac 

# FILTERS může být kombinace následujících (každý maximálně jednou):
# -a DATETIME — after: jsou uvažovány pouze záznamy PO tomto datu (včetně tohoto data). DATETIME je formátu YYYY-MM-DD.
# -b DATETIME — before: jsou uvažovány pouze záznamy PŘED tímto datem (včetně tohoto data).
# -g GENDER — jsou uvažovány pouze záznamy nakažených osob daného pohlaví. GENDER může být M (muži) nebo Z (ženy).
# -s [WIDTH] u příkazů gender, age, daily, monthly, yearly, countries, districts a regions vypisuje data ne číselně, ale graficky v podobě histogramů. Nepovinný parametr WIDTH nastavuje šířku histogramů, tedy délku nejdelšího řádku, na WIDTH. Tedy, WIDTH musí být kladné celé číslo. Pokud není parametr WIDTH uveden, řídí se šířky řádků požadavky uvedenými níže.
# (nepovinný, viz níže) -d DISTRICT_FILE — pro příkaz districts vypisuje místo LAU 1 kódu okresu jeho jméno. Mapování kódů na jména je v souboru DISTRICT_FILE
# (nepovinný, viz níže) -r REGIONS_FILE — pro příkaz regions vypisuje místo NUTS 3 kódu kraje jeho jméno. Mapování kódů na jména je v souboru REGIONS_FILE
# -h — vypíše nápovědu s krátkým popisem každého příkazu a přepínače.


#PARSING FILTERS 

# Skript umí zpracovat i záznamy komprimované pomocí nástrojů gzip a bzip2 (v případě, že název souboru končí .gz resp. .bz2).
# V případě, že skript na příkazové řádce nedostane soubory se záznamy (LOG, LOG2, …), očekává záznamy na standardním vstupu.

optstring_filters=":a:b:g:s:h"
optstring_commands='^(infected|merge|gender|age|daily|monthly|yearly|countries|districts|regions)$'
head_regex='(id,datum,vek,pohlavi,kraj_nuts_kod,okres_lau_kod,nakaza_v_zahranici,nakaza_zeme_csu_kod,reportovano_khs)'

#initial value of variables:
after_date=""
before_date=""
gender=""

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
    :) echo expected argument. 
    ;;
    ?) echo Invalid option ; usage
    ;;
  esac
done



echo histogram width : $histogram_width


eval command=\$${OPTIND} #ziskanie nasledujuceho argumentu, ktory by mal byt command

if ! [[ $command =~ $optstring_commands ]]
then 
    command=""  
fi


echo current command: $command
#eval file=\$$# #zatial input file na poslednom argumente

#LOADING DATA

#dorobit cykly pre hladanie viacerych suborov

DATA=""

head_regex='(id,datum,vek,pohlavi,kraj_nuts_kod,okres_lau_kod,nakaza_v_zahranici,nakaza_zeme_csu_kod,reportovano_khs)'
head_count=0

#vsetky mozne pripady ukonecnia riadka
new_line_regex='^(\r\n|\r|\n)$'

input_type="stdin"

load_from_stdin() { #completed
  while read -r line 
  do 
    if [[ $line =~ $head_regex ]] 
    then 
      DATA+="$line"
      head_count=$(($head_count+1))
    fi 

    if (( $head_count == 1 )) && ! [[ $line =~ $head_regex ]]; then
          DATA+=$'\n'
          DATA+="$line"
    fi
  done
}

load_data() { #completed
 #nacitani prvej linky, kvoli hlavicke, pre kazdy typ suboru inak
    case "$input_type" in 
        csv) read -r line < $1 ;;
        bz2) gzcat $1 | read -r line ;;
        zip) unzip $1 | read -r line ;;
        gz) gzcat $1 | read -r line ;;
    esac 

    if [[ $line =~ $head_regex ]] 
    then 
      head_count=$(($head_count+1))
    fi 

    if (( $head_count > 1 )) 
    then 
    case "$input_type" in 
        csv) DATA+=$'\n' ; DATA+="$(awk -v header="$head_regex" -v empty_line="$new_line_regex" '{ if ($0 !~ empty_line && $0 !~ header) {print $0 } }' $1)"  ;;
        bz2) DATA+=$'\n' ;  DATA+="$(gzcat $1 | awk -v header="$head_regex" -v empty_line="$new_line_regex" '{ if ($0 !~ empty_line && $0 !~ header) {print $0 } }' )" ;;
        zip) DATA+=$'\n' ;  DATA+="$(unzip $1 |  awk -v header="$head_regex" -v empty_line="$new_line_regex" '{ if ($0 !~ empty_line && $0 !~ header) {print $0 } }' )" ;;
        gz) DATA+=$'\n' ;  DATA+="$(gzcat $1 |  awk -v header="$head_regex" -v empty_line="$new_line_regex" '{ if ($0 !~ empty_line && $0 !~ header) {print $0 } }' )" ;;
    esac 
     #tu treba dat date a age verifycation 
    else
     case "$input_type" in 
        csv) DATA+="$(awk -v empty_line="$new_line_regex" '{ if($0 !~ empty_line) {print $0}}' $1)" ;;
        bz2)  DATA+="$(gzcat $1 |  awk -v empty_line="$new_line_regex" '{ if($0 !~ empty_line) {print $0}}' )" ;;
        zip) DATA+="$(unzip $1 |  awk -v empty_line="$new_line_regex" '{ if($0 !~ empty_line) {print $0}}' )" ;;
        gz) DATA+="$(gzcat $1 |  awk -v empty_line="$new_line_regex" '{ if($0 !~ empty_line) {print $0}}' )" ;;
    esac 
    fi
}


 #TOTO A TERAZ DO PICII dorobit presmerovanie pre standardny vstup

#tu ziskat typ suboru a podla toho to nacitat
index=0
while (( $index != $#+1 ))
do
  eval file=\$$index
  if [[ $file =~ ^.*\.csv$ ]] 
  then input_type="csv" ; load_data $file  
  elif [[ $file =~ ^.*\.bz2$ ]]
  then input_type="bz2" ; load_data $file 
  elif [[ $file =~ ^.*\.zip$ ]] 
  then input_type="zip" ;  load_data $file 
  elif [[ $file =~ ^.*\.gz$ ]]
  then input_type="gz" ; load_data $file 
  fi 
  ((index++))
done 

if [[ $input_type == "stdin" ]]
then
    load_from_stdin 
    DATA="$(echo "$DATA" | awk  -v empty_line="$new_line_regex" '{ if ($0 !~ empty_line ) {print $0 } }' )"
fi

echo input type : $input_type

#echo "$DATA"

#COMMANDS

# COMMAND může být jeden z:
# infected — spočítá počet nakažených.
# merge — sloučí několik souborů se záznamy do jednoho, zachovávající původní pořadí (hlavička bude ve výstupu jen jednou).
# gender — vypíše počet nakažených pro jednotlivá pohlaví.
# age — vypíše statistiku počtu nakažených osob dle věku (bližší popis je níže).
# daily — vypíše statistiku nakažených osob pro jednotlivé dny.
# monthly — vypíše statistiku nakažených osob pro jednotlivé měsíce.
# yearly — vypíše statistiku nakažených osob pro jednotlivé roky.
# countries — vypíše statistiku nakažených osob pro jednotlivé země nákazy (bez ČR, tj. kódu CZ).
# districts — vypíše statistiku nakažených osob pro jednotlivé okresy.
# regions — vypíše statistiku nakažených osob pro jednotlivé kraje.


infected() { #completed
  infected_data=$(echo "$DATA" | awk '$0 !~ /^(\r\n|\r|\n)$/' | wc -l)
  number_infected=$(($infected_data-1)) # minus header
  echo Infected: $number_infected
}

merge() { #completed
  echo "$DATA"
}

gender() { #completed
case "$gender" in 
  M) echo M: $(echo "$DATA" | awk -F, '$4 == "M"'  | wc -l) ;;
  Z) echo Z: $(echo "$DATA" | awk -F, '$4 == "Z"' | wc -l) ;;
  "") echo M: $(echo "$DATA" | awk -F, '$4 == "M"'  | wc -l) ; echo Z: $(echo "$DATA" | awk -F, '$4 == "Z"' | wc -l) ;;
esac
}

age() { #dorobit zarovnanie
  #podla intervalov vypise statistiku (tabulka)
  echo "$DATA" | awk -F, -v count0_5=0 -v count6_15=0 -v count16_25=0 -v count26_35=0 -v count36_45=0 -v count46_55=0 -v count56_65=0 -v\
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
  }'
}

daily() {
  #pozn netreba overovat datujmy - uz su overene v tomto bode
  #date1: data 
  #date2: data
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

countries() { #next
  echo countries... #statistika nakazenych pre jednotlive krajiny - bez CZ
}

districts() { 
  echo districts... #pre okresy
}

regions() {
  echo regions... #pre kraje
}

case "$command" in 
    infected) infected ;;
    merge) merge ;;
    gender) gender ;;
    age) age ;;
    daily) daily ;;
    monthly) monthly ;;
    yearly) yearly ;;
    countries) countries ;;
    districts) districts ;;
    regions) regions ;;
    "") merge ;;
esac

#overenie datumov 
echo "$DATA" | awk -F, -v norm_date="$normal_year_pattern" -v leap_date="$leap_year_pattern" -v age=$age_regex 'NR == 1{next}\
( $2 !~ norm_date && $2 !~ leap_date) {printf("Invalid date: %s\n",$0)| "cat 1>&2"}\
($3 !~ age && $3 != "") {printf("Invalid age: %s\n", $0) | "cat 1>&2"}' 

#NEXT
#dokocint filter s 
#zakomponovat filtre do commnadov
#dokoncit commandy
#bud upravit funkciu load data alebo spravit dalsie dve funkcie - pre kazdy subor jeden

#load your data based on input type here 

#napad 1: unzip vsetky zazipovane veci a potom s nimi narabat ako s csv fileom

#AKO BY TO MALO PRACOVAT
# najprv nacitat vsetky filtre, overit ich spravnost parametrov
# nacitat prikazy, v pripade nezmyslov pokracovat standarne ako bez prikazu alebo ukoncit program, to este nevim
# po nacitani prikazov nacitat vstupy - stdin, subor, taky, taky, onaky
# nakoniec vyfiltrovat potrebne zanamy pomocou potrebnych prikazov (ako awk, grep, sed a podobne)
# vypisat output 
# ende do pice 

# overenia na stdout 