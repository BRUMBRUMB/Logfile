#!/bin/bash

#Create and initializing variables
FILENAME=""
c_option=0
r_option=0
two_option=0
F_option=0
t_option=0
number_of_fields=

#Usage function to show how to use the code
USAGE()
{
cat << EOF
Error occured
USAGE: $./log_sum.sh [-n N] (-c|-2|-r|-F|-t|-f|-e) <filename>
Options:
    -n) Limit the number of results to n (Optional)
    -c) IP adresses that makes the most number of connection attempts
    -2) IP addresses with most succesful attempts
    -r) Most common status codes and their IP addresses
    -F) Most common status codes that indicates failure
    -t) IP addresses with their total bytes sent to them
    -e) IP addresses which are blacklisted
    -h) Help
EOF
}

#reading command line arguments
while [ "$1" != "" ]; do
    case $1 in
        -n )    shift
                number_of_fields=$1
                ;;
        -c )    c_option=1
                ;;
        -2 )    two_option=1
                ;;
        -r )    r_option=1
                ;;
        -F )    F_option=1
                ;;
        -t )    t_option=1
                ;;
        -e )    e_option=1
                ;;
        -h | --help )   USAGE
                        exit
                        ;;
        * )     if [ -f "$1" ]; then #get the name of the logfile
                    FILENAME=$1
                else
                    printf "%s\n"  "$1 is not a valid option" #if the argument is not a valid option 
                    USAGE                                     #or it is not a filename then it will print this
                    exit 1
                fi
    esac
    shift
done

#if user enter more than 1 mandatory option then the code will show usage function and will exit
mandatory_sum_options=$(($c_option + $two_option + $r_option + $t_option + $F_option))
if [[ $mandatory_sum_options != "1" ]]; then
    printf "%s\n" "Please enter 1 mandatory option"
    USAGE
    exit 1
fi

#check to see if the temperory files which we used in the script exist or not...if exists then remove them
if [[ -f temp ]]; then
    rm temp
elif [[ -f temp2 ]]; then
    rm temp2
elif [[ -f all_results ]]; then
    rm all_results
elif [[ -f result ]]; then
    rm result
fi

#check to see if user used a log file or not
if [ -z $FILENAME ]; then
    echo "No logfile">&2
    USAGE
    exit 1
fi

#check to see if user used -n option or not... if -n option is used then we apply it to the output
LIMITATION()
{
    if [ "$number_of_fields" != "" ]; then
        cat temp | sed -n "1,$number_of_fields p" > temp2
    else
        cat temp > temp2
    fi
}

#this function try to find blacklisted IPs 
BLACKLIST()
{               #we have if statements for each group of options because our function print the results and the format of the results for each option is different
    if [[ "$r_option" == "1" ]] || [[ "$F_option" == "1" ]]; then
        IP=$(cat temp2 | cut -d' ' -f2)
        all_results=$(cat temp2)
        BLACKLIST=$(<dns.blacklist.txt)
        for ip in $IP; do #loop through IPs
            COUNTS=$(grep ${ip} <<< ${all_results} | cut -d' ' -f3) # get the number of counts for IPs
            STATUS_CODE=$(grep ${ip} <<< ${all_results} | cut -d' ' -f1) #get the IPs status codes
            DNS=$(getent hosts "$ip") #get the DNS of an IP
            RESULT=""
            for dns in $BLACKLIST; do #loop through the blacklisted dns and check them against the IPs
                RESULT+=$(grep "${dns}" <<< $DNS) #if it find any then it will store it in RESULT variable
            done
            if [[ -n $RESULT ]]; then 
                printf "%s\t%s\t%s\t\t%s\n" ${STATUS_CODE} ${ip} ${COUNTS} "Blacklisted" #print blacklisted IPs
            else
                printf "%s\t%s\t%s\t\n" ${STATUS_CODE} ${ip} ${COUNTS} #print normal normal IPs
            fi
        done
        printf "\n"
    elif [[ "$c_option" == "1" ]] || [[ "$two_option" == "1" ]]; then #Same as last statement but for -c and -2 options 
        IP=$(cat temp2 | cut -d' ' -f1)                               #the print format is different from -r and -F option
        all_results=$(cat temp2)
        BLACKLIST=$(<dns.blacklist.txt)
        for ip in $IP; do
            COUNTS=$(grep ${ip} <<< ${all_results} | cut -d' ' -f2)
            DNS=$(getent hosts "$ip")
            RESULT=""
            for dns in $BLACKLIST; do
                RESULT+=$(grep "${dns}" <<< $DNS)
            done
            if [[ -n $RESULT ]]; then
                printf "%s\t%s\t\t%s\t\n" "${ip}" "${COUNTS}" "Blacklisted"
            else
                printf "%s\t%s\t\n" "${ip}" "${COUNTS}"
            fi
        done
    elif [[ "$t_option" == "1" ]]; then #if statment for -t option
        IP=$(cat temp2 | cut -d' ' -f1)
        all_results=$(cat temp2)
        BLACKLIST=$(<dns.blacklist.txt)
        for ip in $IP; do
            byte=$(cat temp2 | grep ${ip} <<< ${all_results} | cut -d' ' -f2)
            DNS=$(getent hosts "$ip")
            RESULT=""
            for dns in $BLACKLIST; do
                RESULT+=$(grep "${dns}" <<< $DNS)
            done
            if [[ -n $RESULT ]]; then
                printf "%s\t%s\t\t%s\n" ${ip} ${byte} "Blacklisted"
            else
                printf "%s\t%s\n" ${ip} ${byte}
            fi
        done
    fi
}

if [[ "$c_option" == "1" ]]; then #if statement to print results for -c option
    cat $FILENAME | cut -d' ' -f1 | sort | uniq -c | sort -nrk1 | awk '{print $2,$1}' > temp  #It get the IPs and their counts and store it in temp file
    LIMITATION #if the user use -n option then it will get n number of results and store it in temp2 file (check LIMITATION function above)
    if [ "$e_option" == "1" ]; then #check to see if -e option has been used or not
        BLACKLIST #show blacklisted IPs
        rm temp temp2 #remove temp files
    else
        cat temp2 | column -t #get the results and show them 
        rm temp temp2 #remove temp files
    fi

elif [[ "$two_option" == "1" ]]; then #if statement to print results for -2 option
    cut -d' ' -f1,9 $FILENAME | grep "200" | sed "/200$/!d" | sort | uniq -c | sort -nrk1 | awk '{print $2,$1}' > temp #It get the IPs that has 200 status code.
    LIMITATION                                                                                                         # sort and uniq them and store it in temp file
    if [ "$e_option" == "1" ]; then #the other section of this statement is same as the -c option
        BLACKLIST
        rm temp temp2
    else
        cat temp2 | column -t
        rm temp temp2
    fi

elif [[ "$r_option" == "1" ]]; then    #if statement for -r option
    # all_status_codes=$(cut -d' ' -f9 $FILENAME | sort | uniq -c | sort -nrk1 | rev | cut -c -3 | rev)
    all_status_codes=$(cut -d' ' -f9 $FILENAME | sort | uniq -c | sort -nrk1 | awk '{print $2}') #it gets all the status codes of all uniq IPs
    cut -d' ' -f1,9 $FILENAME >> all_results #get all IPs with status codes and store in all_results file

    for status_code in $all_status_codes; do #loop through and get the IPs with their status codes and counts and store in temp file
        cat all_results | grep "${status_code}$" | sort | uniq -c | sort -nrk1 | awk '{print $3,$2,$1}' >> temp    #Note: the feilds are sorted base on the
        LIMITATION                                                                                     # counts of the status codes and then in each group
        if [ "$e_option" == "1" ]; then                                                            #sorted base on the counts of IPs
            BLACKLIST
            rm temp temp2
        else
            cat temp2 | column -t
            printf "\n"
            rm temp temp2
        fi
    done
    rm all_results
elif [[ "$F_option" == "1" ]]; then  #if statement for -F option
    if [[ -f all_results ]]; then
        rm all_results
    fi
    all_failure_status_codes=$(cut -d' ' -f9 $FILENAME | grep "^[4]" | sort | uniq -c | sort -nrk1 | awk '{print $2}') #It get all failure codes in the file
    cut -d' ' -f1,9 $FILENAME >> all_results #get all the results

    for status_code in $all_failure_status_codes; do #loop through the list 
        cat all_results | grep "${status_code}$" | sort | uniq -c | sort -nrk1 | awk '{print $3,$2,$1}' >> temp #get the specific result and store in temp
        LIMITATION #get nth number of results if -n option is used
        if [ "$e_option" == "1" ]; then
            BLACKLIST   #get blacklisted IPs if -e option is used
            rm temp temp2
        else
            cat temp2 | column -t
            printf "\n"     #print the results if -e option is not used
            rm temp temp2
        fi
    done
    rm all_results
elif [ "$t_option" == "1" ]; then #if -t option is used
    IP_BYTES_LIST=$(cut -d' ' -f1,10 $FILENAME | sed '/-/d' | sort) #it get all the IPs with their bytes sent to them but some the IPs has - bytes and we don't 
    IP_ADDRESS=$(cut -d' ' -f1 <<< $IP_BYTES_LIST)                  #these fields so we used sed command to delete this fields
    for ip in $IP_ADDRESS; do
        TOTAL_BYTES=0
        for byte in $(egrep -o "^${ip} [0-9]+$" <<< $IP_BYTES_LIST | cut -d' ' -f2); do #get the bytes for each ip and then sum them and store 
            TOTAL_BYTES=$(( $TOTAL_BYTES + $byte )) # TOTAL_BYTES variable keeps track of the total bytes for each IP
        done
        echo "${ip} ${TOTAL_BYTES}" >> results #store the results in results file which is a temperory file
    done
    cat results | sort -nrk2 | uniq >> temp #get the results and sort them base on total bytes for each IP and stire them in temp file
    LIMITATION
    if [ "$e_option" == "1" ]; then 
        BLACKLIST
        rm temp temp2 results
    else
        cat temp2 | column -t
        rm temp temp2 results
    fi
fi