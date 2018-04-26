#!/bin/bash

#---arg in script command line: -u print "unknown password" and -f<path to file> is a name of file, where stored credentials---------
key=0
FILE=""
while getopts "uf:" opt;
      do
      case "$opt" 
      in
      u) key=1;;
      f) FILE=$OPTARG;;
      esac
done
#---sort and sample result from dump to array by string with field separator '\n'-----------
#-----array is a massive for dump with format "<date> <time> <uid> <passwd> <passwd>\n"---------------

IFS=$'\n'

array=($(tac $FILE | awk '{if(/^[a-z]/) {print $1,$2,$3;} else print $3,$4,$5}' | awk '!_[$1]++'))

IFS=$' '


#---if ldap_OK then return 0, else if ldap_ERR then return 1----------------
ldap_check () {
local err
local result

local uid=$1
local ldap_passwd="$2"

local ldap_command="ldapwhoami -x -D uid=$uid,ou=People,dc=<domain name>,dc=loc -w $ldap_passwd 2>&1 >/dev/null"

err=$(eval "$ldap_command")

if [ "$err" == "" ]
then result=0
else result=1
fi
echo $result
}
#---end of function which checking ldap uid-------------------------------

#---if krb_OK then return 0, else if krb_ERR then return 1----------------
krb_check () {
local err
local result

local uid=$1
local krb_passwd="$2"

local krb_command="echo "$krb_passwd" | kinit $uid 2>&1 >/dev/null"

err=$(eval "$krb_command")

if [ "$err" == "" ]
then result=0
else result=1
fi
echo $result
}
#---end of function which checking ldap uid-------------------------------

#---$1 is ${ldap_result_new_passwd}, $2 is ${krb_result_new_passwd}, $3 is $uid----------------
result_print() {
if [ $1 -eq 0 ]; then
   if [ $2 -eq 0 ]; then return $(( 0 ))
      else printf "$3\n"
           return $(( 0 ))
   fi
elif [ $2 -eq 0 ]; then printf "$3\n"
                        return $(( 0 ))
else return $(( 1 ))
fi
}
#---end of function which print results-------------------------------

#---reading lines from array in loop and print result, first arg is array, second is key to print message "unknown passwd"------------------------------
read_lines() {
j=0
local arr=$1[@]

for j in "${!arr}"
do

uid=$(awk '{print $1}' <<< "$j")
ldap_new_passwd="\"$(awk '{print $2}' <<< "$j")\""
ldap_old_passwd=$(awk '{print $3}' <<< "$j")

ldap_result_new_passwd=$(ldap_check $uid $ldap_new_passwd)
krb_result_new_passwd=$(krb_check $uid $ldap_new_passwd)

ldap_result_old_passwd=$(ldap_check $uid $ldap_old_passwd)
krb_result_old_passwd=$(krb_check $uid $ldap_old_passwd)

result_print $ldap_result_new_passwd $krb_result_new_passwd $uid
rr=$?

if [ $rr -eq 1 ]; then
   result_print $ldap_result_old_passwd $krb_result_old_passwd $uid
   rr=$?
   if [ $rr -eq 1 ]; then
      if [ $2 -eq 1 ]; then printf "$uid unknown password\n"
      fi
   fi
fi
done
}
#------------------------------------------------
read_lines array $key
