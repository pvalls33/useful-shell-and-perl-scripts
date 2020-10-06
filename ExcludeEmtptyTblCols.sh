#!/bin/bash
#Preston Valls
source /home/pvalls/sourceFile_2020-09-06

 _USAGE_ () {
 local thisScript=$(basename $0)
 box_Prompt "\e[1;4;31;40mUSAGE:\e[0m" "*"
 echo -e "\n\e[1m${thisScript}\e[0m Takes in sql out data or table data and excludes columns with no data"
 echo -e "then prints the table in a \"pretty\" way"
 echo -e "By Default, \e[1m${thisScript}\e[0m attempts to figure out the delimiter, but you can provide the optional delimter as the second arg\n"

 echo -e "\e[38;5;42mOPTIONS\e[0m"
 ops=$(cat <<'EOF'
 -d|--debug             Enables Debug Mode
 -s|--sep               Specify optional output Sep instead of tabbed delimed output
                                  -s <"out seperator in quotes">
EOF
)
echo -e "$ops"
echo -e "\e[1;36;40mEX\e[0m"
echo -e "  \e[1m$0\e[0m <-d (debug - optional)> -s \":\" (output seperator - optional)(<FILE> <delimeter (optional)"
echo -e "  \e[1m$0\e[0m -s \":\" -d <FILE> <Optional Input Dilimeter>"
echo "  $0 <FILE>"
 exit
}

_exit_ ()
{
exit
}

while :; do
        case $1 in
        -d|--debug) debugMode=1
                        ;;
        -s|--sep)
                        shift
                        sep=$1
                        ;;
        *) break
        esac
shift
done



if
        [ $# -eq 0 ] || [ ! -e $1 ]; then
        _USAGE_
fi

if [ $sep ]; then echo "SEP is $sep";fi

#check to see if file has no rows
zegrep -q "no rows selected" $1
if [ $? -eq 0 ]; then
        echo -e "No Rows selected"
        _exit_
fi

#Set up sed command to format file
egrep -q "SQL>" $1
############## Check infile for sed expression first
if [ $? -eq 0 ]; then
        sExp='sed -e '"'"'1,/SQL>/d'"'"'';
        #Q prints from empty line to end
        sedOpVar="Q"
 else
        sExp='sed "/SYS_CONTEXT/,/^$/d"';
        #d goes to end of file
        sedOpVar="d"
fi



if [ $# -eq 2 ]; then
        delim="$2"
        fmtTable=$(mktemp fmtTable_XXXXX)
        #Sed replace space may neeed to make 2 spaces
        eval $(echo "$sExp $1")|egrep -vi session|sed "/^$/$sedOpVar"|egrep -vi session|perl -ne 'print unless /^$/'|egrep -v "^-"|perl -pe 's/^\s+//'|sed 's/[[:space:]]\{1,\}/ /g' > $fmtTable
else
        #Sed replace space may neeed to make 2 spaces
        fmtTable=$(mktemp fmtTable_XXXXX)
        eval $(echo "$sExp $1")|egrep -vi session|sed "/^$/$sedOpVar"|egrep -vi session|perl -ne 'print unless /^$/'|egrep -v "^-"|perl -pe 's/^\s+//'|sed 's/[[:space:]]\{1,\}/ /g' > $fmtTable
        delim=$(head -1 $fmtTable|sed -e 's/[\t ]//g;/^$/d'|sed "s/[A-Za-z]/@/g"|sed "s/[@_]/\n/g"|perl -ne 'print unless /^$/'|sed -n '2p'|perl -pe 's/^\s+//'|cut -c1)

        if [ ! "$delim" ];then
                sed -i 's/[[:space:]]\{1,\}/|/g' $fmtTable
                delim=""
                delim=$(head -1 $fmtTable|sed -e 's/[\t ]//g;/^$/d'|sed "s/[A-Za-z]/@/g"|sed "s/[@_]/\n/g"|perl -ne 'print unless /^$/'|sed -n '2p'|perl -pe 's/^\s+//'|cut -c1)
        fi
fi
[ $debugMode ] && echo "DELIM IS $delim"


#create Array
declare -A cname=();
while read -r x; do
        cn=$(echo "$x"|cut -d"${delim}" -f1)
        field=$(echo "$x"|cut -d"${delim}" -f2)
        cname[$cn]=$field
done < <(head -1 $fmtTable|tr "${delim}" "\n"|nl -nln|sed "s/[[:space:]]\{2,\}/${delim}/g")

if [ $debugMode ]; then
        echo -e "---ALL COLUMNS ---"
        #Sort Array
        for i in "${!cname[@]}"; do
                printf "%s: %s\n" "$i" "${cname[$i]}"
        done |sort -t":" -n -k1,1 -k2,2 |column -s":" -t
        echo -e "\n----------------------------------------------------"
fi

>t

[ $debugMode ] && box_Prompt "column : #Items" "+"
#Get blank column names
for x in `seq 1 ${#cname[@]}`; do
        lc=$(cat $fmtTable|cut -d"${delim}" -f${x}|sed '1d'|perl -ne 'print unless /^$/'|grep -v rows|sed -e 's/[\t ]//g;/^$/d'|wc -l)
        [ $debugMode ] && printf "%-7s:%s\n" "$x" "$lc"
#for x in `seq 1 $(printf "%d\n" "${#cname[@]}")`; do lc=$(cat $fmtTable|cut -d"${delim}" -f${x}|sed '1d'|perl -ne 'print unless /^$/'|wc -l)
        if [ $lc -eq 0 ]; then
                echo -e "$x" >> t
        fi
        ((x++))
done

if [ $debugMode ]; then
    box_Prompt -r "DEBUG: EXCLUDED COLUMNS" "="
    box_Prompt "$(printf "%-10s%s\n" "Column" "Header")" "~"
    for x in `for i in "${!cname[@]}"; do printf "%s\n" "$i";done|sort -n |egrep -f t`; do
            printf "%-10s%s\n" "$x" "${cname[$x]}"
echo " "
done
fi

#exlude columns to print
#Gen exrprression
cutExp=$(for i in "${!cname[@]}"; do printf "%s\n" "$i,";done|sort -n |egrep -v -f t|sed '$ s/,$//g'|paste -sd" "|sed "s/\n//g"|sed "s/[[:space:]]//g")

[ $debugMode ] && echo -e "cut : cut -d\"${delim}\" -f$cutExp"

#print non epmty fields
#cat $fmtTable|cut -d"${delim}" -f"${cutExp}"|column -s"${delim}" -t

if [ $sep ]; then
        cat $fmtTable|cut -d"${delim}" -f"${cutExp}"|sed "s/${delim}/$sep/g"|perl -pe 's/^\s+//'
else
        cat $fmtTable|cut -d"${delim}" -f"${cutExp}"|perl -pe 's/^\s+//'|column -s"${delim}" -t
fi
rm $fmtTable t 2>/dev/null
