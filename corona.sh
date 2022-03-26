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
#sem overenie, ci tam je input file alebo to treba citat z stdin

# while read -r id datum vek pohlavi kraj_nuts_kod okres_lau_kod nakaza_v_zahranici nakaza_zeme_csu_kod reportovano_khs 
# do 
# # read -r id datum vek pohlavi kraj_nuts_kod okres_lau_kod nakaza_v_zahranici nakaza_zeme_csu_kod reportovano_khs 
# echo "$id $datum $vek $pohlavi $kraj_nuts_kod $okres_lau_kod $nakaza_v_zahranici $nakaza_zeme_csu_kod $reportovano_khs"
# done < $file




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
    echo date verification $OPTARG; #regexp
    if [[ $OPTARG =~ $normal_year_pattern ]] || [[ $OPTARG =~ $leap_year_pattern ]] #yyyy-mm-dd - basic verification - to ADD: limity, priestupne roky / kvôli februáru, validácia poctu dni
    then 
        echo "the date format is valid"
        date_is_valid="true"
    else
      echo "Invalid date: $OPTARG"
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

# FILTERS může být kombinace následujících (každý maximálně jednou):
# -a DATETIME — after: jsou uvažovány pouze záznamy PO tomto datu (včetně tohoto data). DATETIME je formátu YYYY-MM-DD.
# -b DATETIME — before: jsou uvažovány pouze záznamy PŘED tímto datem (včetně tohoto data).
# -g GENDER — jsou uvažovány pouze záznamy nakažených osob daného pohlaví. GENDER může být M (muži) nebo Z (ženy).
# -s [WIDTH] u příkazů gender, age, daily, monthly, yearly, countries, districts a regions vypisuje data ne číselně, ale graficky v podobě histogramů. Nepovinný parametr WIDTH nastavuje šířku histogramů, tedy délku nejdelšího řádku, na WIDTH. Tedy, WIDTH musí být kladné celé číslo. Pokud není parametr WIDTH uveden, řídí se šířky řádků požadavky uvedenými níže.
# (nepovinný, viz níže) -d DISTRICT_FILE — pro příkaz districts vypisuje místo LAU 1 kódu okresu jeho jméno. Mapování kódů na jména je v souboru DISTRICT_FILE
# (nepovinný, viz níže) -r REGIONS_FILE — pro příkaz regions vypisuje místo NUTS 3 kódu kraje jeho jméno. Mapování kódů na jména je v souboru REGIONS_FILE
# -h — vypíše nápovědu s krátkým popisem každého příkazu a přepínače.


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


#REST

# Skript umí zpracovat i záznamy komprimované pomocí nástrojů gzip a bzip2 (v případě, že název souboru končí .gz resp. .bz2).
# V případě, že skript na příkazové řádce nedostane soubory se záznamy (LOG, LOG2, …), očekává záznamy na standardním vstupu.

optstring_filters=":a:b:g:s:h:"
optstring_commands='^infected|gender|age|daily|monthly|yearly|countries|districts|regions$'

while getopts "${optstring_filters}" options; 
do 
  case "${options}" in
    a) verify_date; 
    if [[ "$date_is_valid" = "true" ]]
    then after_date="$OPTARG"
    fi
    ;;
    b) verify_date; 
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


command=""

get_command() {
#bere to po prvom najdenom regexpe z vrchu - najprv hlada infected, potom daily atd.. mozno to skusit spravit od zacatku radku
    if [[ $1 =~ infected ]] 
    then command="infected"
    elif [[ $1 =~ merge ]] 
    then command="merge"
    elif [[ $1 =~ gender ]] 
    then command="gender"
    elif [[ $1 =~ daily ]] 
    then command="daily"
    elif [[ $1 =~ monthly ]] 
    then command="monthly"
    elif [[ $1 =~ yearly ]] 
    then command="yearly"
    elif [[ $1 =~ countries ]] 
    then command="countries"
    elif [[ $1 =~ districts ]] 
    then command="districts"
    elif [[ $1 =~ regions ]] 
    then command="regions"
    fi

    # case $1 in 
    # [[:space:]]infected) 
    # command="infected"
    # ;;
    # [[:space:]]merge) 
    # command="merge"
    # ;;
    # [[:space:]]gender) 
    # command="gender"
    # ;;
    # [[:space:]]daily) 
    # command="daily"
    # ;;
    # [[:space:]]monthly) 
    # command="monthly"
    # ;;
    # [[:space:]]yearly) 
    # command="yearly"
    # ;;
    # [[:space:]]countries) 
    # command="countries"
    # ;;
    # [[:space:]]districts) 
    # command="districts"
    # ;;
    # [[:space:]]regions) 
    # command="regions"
    # ;;
    # esac

}

get_command "$*"  #place here that command variable as argumet
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

#funkcie na spracovavanie jednotlivych typov suborov
load_data() {
  echo loading data..
}

gz_open() {
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

if [[ "$*" =~ .csv ]] 
then input_type="csv"
elif [[ "$*" =~ .bz2 ]]
then input_type="bz2"
elif [[ "$*" =~ .zip ]]
then input_type="zip"
elif [[ "$*" =~ .gz ]]
then input_type="gz"
fi 

case "$input_type" in
    stdin) load_data ;;
    csv) csv_open ;;
    bz2) bz2_open;;
    gz) gz_open;;
esac

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