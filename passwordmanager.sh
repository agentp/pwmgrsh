#!/bin/bash

CGRAY="\e[\033[1;30m"
CLGRAY="\e[\033[1;37m"
CCYAN="\e[\033[1;36m"
CLCYAN="\e[\033[1;36m"
CNOCOLOR="\e[\033[0m"
CBLUE="\e[\033[1;34m"
CLBLUE="\e[\033[1;34m"
CRED="\e[\033[1;31m"
CLRED="\e[\033[1;31m"
CGREEN="\e[\033[1;32m"
CLGREEN="\e[\033[1;32m"
CPURPLE="\e[\033[1;35m"
CLPURPLE="\e[\033[1;35m"
CBROWN="\e[\033[1;33m"
CYELLOW="\e[\033[1;33m"
CBLACK="\e[\033[1;30m"
CWHITE="\e[\033[1;37m"

# Check the given program
function checkprogram() {
   local exist=0
   type $1 >/dev/null 2>&1 || { local exist=1; }
   echo "$exist"
}

# Read a password and show only stars
# Source http://stackoverflow.com/questions/1923435/how-do-i-echo-stars-when-reading-password-with-read
function readpassword() {
   unset password
   prompt="$1: "
   while IFS= read -p "$prompt" -r -s -n 1 char
   do
      if [[ $char == $'\0' ]]
      then
          break
      fi
      prompt='*'
      password+="$char"
   done
   echo $password
}

function banner() {
   # Source: http://patorjk.com/software/taag/#p=testall&f=Graffiti&t=pwmgrsh
   echo -e "$CPURPLE                                   _     "
   echo -e "                                  | |    "
   echo -e " ____  _ _ _ ____   ____  ____ ___| |__  "
   echo -e "|  _ \| | | |    \ / _  |/ ___)___)  _ \ "
   echo -e "| |_| | | | | | | ( (_| | |  |___ | | | |"
   echo -e "|  __/ \___/|_|_|_|\___ |_|  (___/|_| |_|"
   echo -e "|_|               (_____|                $CNOCOLOR"
   echo -e "${CRED}Password Manager Shell by Christian Blechert"
   echo -e "Source Code: https://github.com/agentp/pwmgrsh$CNOCOLOR"
}

# Pause the script execution and wait for enter
function waitforenter() {
   echo
   echo -n -e "${CBLUE}Enter drücken zum fortfahren...$CNOCOLOR "
   read
}

# Unknown option!
function unknownoption() {
   clear
   echo
   echo "Ungültige Option"
   waitforenter
}

# Change the Linux password
function changepassword() {
   clear
   echo "Das alte Passwort eingeben, danach zwei mal das neue."
   echo "Dabei werden keinerlei Eingaben angezeigt!"
   echo
   passwd
   waitforenter
}

# Pipe the GPG password in a file and protect the file
function createpwfile() {
   killpwfile
   touch "$TMPPWFILE"
   chown $USER:$GROUP "$TMPPWFILE"
   chmod u=rwx,go=- "$TMPPWFILE"
   echo -n "$1" > "$TMPPWFILE"
}

# Delete the password file
function killpwfile() {
   if [ -f "$TMPPWFILE" ]; then
      rm "$TMPPWFILE"
   fi
}

# Protect the files
function setpwfilepermissions() {
   if [ -f "$PWFILE" ]; then
      chown $USER:$GROUP "$PWFILE"
      chmod u=rwx,go=- "$PWFILE"
   fi
   if [ -f "$PWFILE.gpg" ]; then
      chown $USER:$GROUP "$PWFILE.gpg"
      chmod u=rwx,go=- "$PWFILE.gpg"
   fi
}

# Encrypt the password list
function fileencrypt() {
   createpwfile "$1"
   gpg -q --batch --yes --passphrase-fd 0 -c "$PWFILE" < "$TMPPWFILE" 2> /dev/null
   local RES=$?
   killpwfile
   setpwfilepermissions
   return $RES
}

# Decrypt the password list
function filedecrypt() {
   createpwfile "$1"
   local RES=9
   if [ "$2" == "echo" ]; then
      gpg -q --batch --yes --output - --passphrase-fd 0 "$PWFILE.gpg" < "$TMPPWFILE" 2> /dev/null
      RES=$?
   else
      gpg -q --batch --yes --passphrase-fd 0 "$PWFILE.gpg" < "$TMPPWFILE" 2> /dev/null
      RES=$?
   fi
   
   killpwfile
   setpwfilepermissions
   return $RES
}

# Check GPG password is correct
function checkmasterpw() {
   if [ -f "$PWFILE.gpg" ]; then
      filedecrypt "$1" "echo" 2> /dev/null > /dev/null
      echo $?
   else
      echo 1
   fi
}

# Display the password list
function showpasswords() {
   clear
   echo
   echo -e "Zeige Passwörter an:"
   echo -e "${CPURPLE}----------------------$CNOCOLOR"
   echo

   if [ -f "$PWFILE.gpg" ]; then
      filedecrypt "$PW" "echo"
   else
      echo -e "${CRED}Keine verschlüsselte Passwortdatei gefunden$CNOCOLOR"
   fi

   echo
   echo -e "${CPURPLE}----------------------$CNOCOLOR"
   waitforenter
}

# Edit the password list
function editpasswords() {
   local ED="$1"
   echo "$1 ist ein Editor der nur mit der Tastatur bedient wird."
   if [ "$1" == "vim" ]; then
      echo "Zum einfügen von Text muss in den Einfügen-Modus mit der Taste 'i' gewechselt werden."
      echo "Zum Ende mit ESC aus dem Einfügen-Modus aussteigen."
      echo "Mit :x speichern und beenden, mit :q! ohne Speichern beenden."
      ED="$ED -Z -n --noplugin"
   else
      echo "Unterhalb des Editors sind alle Tastenkombinationen aufgelistet."
      echo "Das ^ Zeichen entspricht dabei der Strg-Taste."
      ED="$ED -R -i"
   fi

   waitforenter

   filedecrypt "$PW"
   $ED "$PWFILE"
   fileencrypt "$PW"
   rm "$PWFILE"

   if [ "$GITAVAILABLE" == "1" ]; then
      clear
      echo "Änderungen in Versionsverwaltung sichern?"
      echo -e -n "${CBLUE}ja oder nein?>$CNOCOLOR "
      read CHOICE
      if [ "$CHOICE" == "ja" ]; then
         cd "$PWROOT"
         echo
         git add -A
         git commit -m "Passwortliste bearbeitet $(date)"
         waitforenter
      fi
   fi
}

# Change the GPG password
function changemasterpassword() {
   local OLDPW=$(readpassword "Aktuelles Masterkennwort eingeben")
   local AKTPWRES=$(checkmasterpw "$OLDPW")
   
   echo
   if [ "$AKTPWRES" == "2" ]; then
      echo "Aktuelles Masterkennwort ist falsch!"
      waitforenter
      return
   fi

   local TMPPWA=$(readpassword "Neues Masterkennwort eingeben")
   echo
   local TMPPWB=$(readpassword "Neues Masterkennwort wiederholen")
   echo

   if [ "$TMPPWA" == "$TMPPWB" ]; then
      filedecrypt "$PW"
      PW="$TMPPWA"
      fileencrypt "$PW"
      rm "$PWFILE"
      if [ "$GITAVAILABLE" == "1" ]; then
         echo
         git add -A
         git commit -m "Masterkennwort geändert! $(date)"
      fi
      echo
      echo "Masterkennwort erfolgreich geändert!"
      waitforenter
   else
      echo "Kennwörter stimmen nicht überein!"
      waitforenter
   fi
}

# Delete GIT Repo
function resetgit() {
   echo "Wirklich die komplette Versionsverwaltung löschen und neu anlegen?"
   echo -e -n "${CBLUE}ja oder nein?>$CNOCOLOR "
   read CHOICE
   if [ "$CHOICE" == "ja" ]; then
      echo
      rm -rf ".git"
      git init
      git add -A
      git commit -m "Versionsverwaltung zurückgesetzt. $(date)"
      waitforenter
   fi
}

# Show GIT History
function githistory() {
   echo "Die letzten 20 Änderungen:"
   echo
   PAGER=cat git log --oneline | sort --key=1,7 -r | tail -n 20
   waitforenter
}



clear
banner
echo
echo "Prüfe auf alle benötigten Programme..."
ERROR=0
GITAVAILABLE=1
for PROG in gpg vim cat chown chmod git nano read rm;
do
   echo -n "Programm $PROG "
   if [ ! "$(checkprogram "$PROG")" == "0" ]; then
      if [ ! "$PROG" == "git" ]; then
         ERROR=1
         echo -e "${CRED}nicht gefunden!$CNOCOLOR"
      else
         echo -e "${CRED}nicht gefunden!$CNOCOLOR (optional)"
         GITAVAILABLE=0
      fi
   else
      echo -e "${CGREEN}gefunden!$CNOCOLOR"
   fi
done;
echo

if [ "$ERROR" == "1" ]; then
   echo -e "${CRED}Einige Programme wurden nicht gefunden! Bitte nachinstallieren!$CNOCOLOR"
   waitforenter
   exit 1
fi



# Get User Info
USER=$(id -u -n)
GROUP=$(id -g -n)

# Set PWROOT
PWROOT="$(cat /etc/passwd | grep -E "^$USER:" | cut -d ':' -f 6)/passwordmanager"
PWFILE="$PWROOT/passwords.txt"
TMPPWFILE="$PWROOT/.temppw"

# Create passwordmanager directory
if [ ! -d "$PWROOT" ]; then
   mkdir -p "$PWROOT"
fi

cd "$PWROOT"

# Kill unencrypted pasword file if exist
if [ -f "$PWFILE" ]; then
   rm "$PWFILE"
fi

# Initialize GIT repo
if [ ! -d "$PWROOT/.git" ] && [ "$GITAVAILABLE" == "1" ]; then
   git init
   echo "$PWFILE" > .gitignore
   echo "$TMPPWFILE" >> .gitignore
   git add -A
   git commit -m "Created git repo and added .gitignore"
fi

# Set permissions
chown -R $USER:$GROUP "$PWROOT"
chmod u=rwx,go=- "$PWROOT"

# Enter masterpw
PW=$(readpassword "Bitte Masterkennwort eingeben")
RESULT=$(checkmasterpw "$PW")

# Check MasterPW
if [ "$RESULT" == "2" ]; then
   echo
   echo
   echo "Masterpasswort ist nicht korrekt!"
   echo "Verbindung wird beendet!"
   waitforenter
   exit 1
fi



# Run endless while
while true; do

clear
banner
echo
echo "Was möchtest Du machen?"
echo
echo -e "${CPURPLE}1]$CNOCOLOR Passwörter anzeigen"
echo -e "${CPURPLE}2]$CNOCOLOR Passwörter mit vim bearbeiten"
echo -e "${CPURPLE}3]$CNOCOLOR Passwörter mit nano bearbeiten"
echo -e "${CPURPLE}4]$CNOCOLOR Login Passwort ändern"
echo -e "${CPURPLE}5]$CNOCOLOR Masterkennwort ändern"
if [ "$GITAVAILABLE" == "1" ]; then
   echo -e "${CPURPLE}6]$CNOCOLOR Historie der Versionsverwaltung anzeigen"
   echo -e "${CPURPLE}7]$CNOCOLOR Versionsverwaltung zurücksetzen"
fi
echo
echo -e "${CPURPLE}9]$CNOCOLOR Ausloggen"
echo

echo -n -e "${CPURPLE}>$CNOCOLOR "
read INPUT

clear
case $INPUT in

1)
   showpasswords
   ;;

2)
   editpasswords vim
   ;;

3)
   editpasswords nano
   ;;

4)
   changepassword
   ;;

5)
   changemasterpassword
   ;;
   
6)
   if [ "$GITAVAILABLE" == "1" ]; then githistory; fi
   ;;
   
7)
   if [ "$GITAVAILABLE" == "1" ]; then resetgit; fi
   ;;

9)
   break;
   ;;

*)
   unknownoption
   ;;

esac


done

