#!/bin/bash

# Check the given program
function checkprogram() {
   local exist=0
   type $1 >/dev/null 2>&1 || { local exist=1; }
   echo "$exist"
}

# Read a password and show only stars
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

# Pause the script execution and wait for enter
function waitforenter() {
   echo
   echo -n "Enter drücken zum fortfahren... "
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
   echo "Zeige Passwörter an:"
   echo "----------------------"
   echo

   if [ -f "$PWFILE.gpg" ]; then
      filedecrypt "$PW" "echo"
   else
      echo "Keine verschlüsselte Passwortdatei gefunden"
   fi

   echo
   echo "----------------------"
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

   clear
   echo "Änderungen in Versionsverwaltung sichern?"
   echo -n "ja oder nein?> "
   read CHOICE
   if [ "$CHOICE" == "ja" ]; then
      cd "$PWROOT"
      echo
      git add -A
      git commit -m "Passwortliste bearbeitet $(date)"
      waitforenter
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
      echo
      git add -A
      git commit -m "Masterkennwort geändert! $(date)"
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
   echo -n "ja oder nein?> "
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
echo
echo "Password Manager Shell (pwmgrsh) by Christian Blechert"
echo "Letzte Änderung: 2013-08-21"
echo "Source Code: https://github.com/agentp/pwmgrsh"
echo
echo "Prüfe auf alle benötigten Programme..."
ERROR=0
for PROG in gpg vim cat chown chmod git nano read;
do
   echo -n "Programm $PROG "
   if [ ! "$(checkprogram "$PROG")" == "0" ]; then
      ERROR=1
      echo "nicht gefunden!"
   else
      echo "gefunden!"
   fi
done;
echo

if [ "$ERROR" == "1" ]; then
   echo "Einige Programme wurden nicht gefunden! Bitte nachinstallieren!"
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
if [ ! -d "$PWROOT/.git" ]; then
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
echo "Was möchtest Du machen?"
echo
echo "1] Passwörter anzeigen"
echo "2] Passwörter mit vim bearbeiten"
echo "3] Passwörter mit nano bearbeiten"
echo "4] Login Passwort ändern"
echo "5] Masterkennwort ändern"
echo "6] Historie der Versionsverwaltung anzeigen"
echo "7] Versionsverwaltung zurücksetzen"
echo
echo "9] Ausloggen"
echo

echo -n "> "
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
   githistory
   ;;
   
7)
   resetgit
   ;;

9)
   break;
   ;;

*)
   unknownoption
   ;;

esac


done

