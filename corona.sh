#!/bin/bash

#BEGIN
#funkcia na vypis pouzitia a ukoncenie corona aplikacie
usage() {
  echo corona [-h] [FILTERS] [COMMAND] [LOG [LOG2 [...]]
  exit 1; #mozna popsat signal 1 - co znamena ta picovna
}

#input file separator
OLDIFS=$IFS
IFS=','


IFS=$OLDIFS



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

verify_gender() {
    case $OPTARG in 
        Z) gender="Z"
        ;;
        M) gender="M"
        ;;
        ?) echo Invalid gender: $OPTARG #namiesto optarg vypisat cely chybovy riadok
        ;;
    esac
}

check_histogram_width() {
  if [[ $OPTARG =~ ^[1-9][0-9]*$ ]] #mozno dorobit overenie pre cisla jebnuteho typu 0000025 atd
  then histogram_width=$OPTARG
  else
    echo nem cislo tady toto or nula
  fi
}

histogram_commands='^(gender|age|daily|monthly|yearly|countries|districts|regions)$'

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

optstring_filters=":a:b:g:s:h:"
optstring_commands='^(infected|merge|gender|age|daily|monthly|yearly|countries|districts|regions)$'
head_regex='^id,datum,vek,pohlavi,kraj_nuts_kod,okres_lau_kod,nakaza_v_zahranici,nakaza_zeme_csu_kod,reportovano_khs$'

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
    g) verify_gender ; echo gender $OPTARG
    ;;
    s) check_histogram_width ; echo sexy option $OPTARG
    ;;
    h) usage
    ;;
    #:) echo expected argument. ; usage
    #;;
    ?) echo Invalid option ; usage
    ;;
  esac
done

eval command=\$${OPTIND} #ziskanie nasledujuceho argumentu, ktory by mal byt command

#overenie commandu, ci je v mnozine prikazov
if ! [[ $command =~ $optstring_commands ]]
then 
    command=""  
fi

echo current command: $command
#eval file=\$$# #zatial input file na poslednom argumente

# function load_data(){
# while read -r id datum vek pohlavi kraj_nuts_kod okres_lau_kod nakaza_v_zahranici nakaza_zeme_csu_kod reportovano_khs 
# do 
# # read -r id datum vek pohlavi kraj_nuts_kod okres_lau_kod nakaza_v_zahranici nakaza_zeme_csu_kod reportovano_khs 
#   echo "$id $datum $vek $pohlavi $kraj_nuts_kod $okres_lau_kod $nakaza_v_zahranici $nakaza_zeme_csu_kod $reportovano_khs"
#   done < $file
# }

#LOADING DATA

#dorobit cykly pre hladanie viacerych suborov

DATA=""
#funkcie na spracovavanie jednotlivych typov suborov


head_regex='id,datum,vek,pohlavi,kraj_nuts_kod,okres_lau_kod,nakaza_v_zahranici,nakaza_zeme_csu_kod,reportovano_khs'
head_count=0
new_line_regex='^(\r\n|\r|\n)$'

load_data() { 
    read -r line < $1 #nacitani prvej linky, kvoli hlavicke
    echo $line 

    if [[ $line =~ $head_regex ]] 
    then 
      echo TRUE
      head_count=$(($head_count+1))
    fi 

    if (( $head_count > 1 )) #tu treba dat date verifycation 
    then 
      DATA+="$(awk '$0 !~ /^((\r\n|\r|\n)$|(id,datum,vek,pohlavi,kraj_nuts_kod,okres_lau_kod,nakaza_v_zahranici,nakaza_zeme_csu_kod,reportovano_khs))/' $1)"
    else
    DATA+="$(awk '$0 !~ /^(\r\n|\r|\n)$/' $1)"
    fi
    DATA+=$'\n' #optional - moze sposobovat problemy
}



gz_open() {
  #DATA=gzip -dc "here place the file you want to decompress..."

  echo processing gz file..
}

bz2_open() {
  echo processing bz2 file..
}

csv_open() {
  echo processing csv file..
}


input_type="stdin"

#get input type right here
index=0
while (( $index != $#+1 ))
do
  eval file=\$$index
  if [[ $file =~ ^.*\.csv$ ]] 
  then input_type="csv" ; echo csv ;  load_data $file ; ((count++))
  elif [[ $file =~ ^.*\.bz2$ ]]
  then input_type="bz2" ; echo bz2 ;  load_data $file ; ((count++)) 
  elif [[ $file =~ ^.*\.zip$ ]] 
  then input_type="zip" ; echo zip ;  ((count++))
  elif [[ $file =~ ^.*\.gz$ ]]
  then input_type="gz" echo gz ;  ((count++))
  fi 
  ((index++))
done 

echo number of files: $count

echo "$DATA"

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
  infected_data=$(echo "$DATA" | awk '$0 !~ /^((\r\n|\r|\n)$|(id,datum,vek,pohlavi,kraj_nuts_kod,okres_lau_kod,nakaza_v_zahranici,nakaza_zeme_csu_kod,reportovano_khs))/' | wc -l)
  number_infected=$(($infected_data-1)) # minus header
  echo Infected: $number_infected
}

merge() {
  echo merge... #DATA +=... este zistit ci treba subor aj vytvorit
}

gender() { #completed
  echo M: $(echo "$DATA" | awk -F, '$4 == "M"'  | wc -l) 
  echo Z: $(echo "$DATA" | awk -F, '$4 == "Z"' | wc -l)
}

age() {
  echo age... #podla intervalov vypise statistiku (tabulka) 
          # interval: awk -F 'x <= $5 <=y' | wc -l
}

daily() {
  echo daily... #statistika podla dni
  #asi regexp 
}

monthly() {
  echo monthly... #podla mesiacov
}

yearly() {
  echo yearly... #podla rokov
}

countries() {
  echo countries... #statistika nakazenych pre jednotlive krajiny - bez CZ
}

districts() {
  echo districts... #pre okresy
}

regions() {
  echo regions... #pre kraje
}

infected
gender




#load your data based on input type here 

#napad 1: unzip vsetky zazipovane veci a potom s nimi narabat ako s csv fileom

# VZOREC na vypocet pre grafy: 
# WIDTH - defined:
#  WIDTH - pocet mriezok v grafe s najvacsou hodnotou: cislo/x = WIDTH, kde x je najvacsie cislo => pocet# = cislo/x *WIDTH (zaokruhlovat dole.) 
#

#AKO BY TO MALO PRACOVAT
# najprv nacitat vsetky filtre, overit ich spravnost parametrov
# nacitat prikazy, v pripade nezmyslov pokracovat standarne ako bez prikazu alebo ukoncit program, to este nevim
# po nacitani prikazov nacitat vstupy - stdin, subor, taky, taky, onaky
# nakoniec vyfiltrovat potrebne zanamy pomocou potrebnych prikazov (ako awk, grep, sed a podobne)
# vypisat output 
# ende do pice 