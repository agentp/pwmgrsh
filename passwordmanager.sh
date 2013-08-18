#!/bin/bash


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

function waitforenter() {
   echo
   echo -n "Enter drücken zum fortfahren... "
   read
}

function showpasswords() {
   clear
   echo
   echo "Zeige Passwörter an:"
   echo "----------------------"
   echo

   if [ -f "$PWFILE.gpg" ]; then
      echo "$PW" | gpg -q --batch --yes --output - --passphrase-fd 0 "$PWFILE.gpg" 2> /dev/null
   else
      echo "Keine verschlüsselte Passwortdatei gefunden"
   fi

   echo
   echo "----------------------"
   waitforenter
}

function editpasswords() {
   local ED="$1"
   echo "$1 ist ein Editor der nur mit der Tastatur bedient wird."
   if [ "$1" == "vim" ]; then
      echo "Zum einfügen von Text muss in den Einfügen-Modus mit der Taste 'i' gewechselt werden."
      echo "Zum Ende mit ESC aus dem Einfügen-Modus aussteigen."
      echo "Mit :x speichern und beenden, mit :q! ohne Speichern beenden."
      ED="$ED -Z"
   else
      echo "Unterhalb des Editors sind alle Tastenkombinationen aufgelistet."
      echo "Das ^ Zeichen entspricht dabei der Strg-Taste."
   fi

   waitforenter

   echo "$PW" | gpg -q --batch --yes --passphrase-fd 0 "$PWFILE.gpg"
   $ED "$PWFILE"
   echo "$PW" | gpg -q --batch --yes --passphrase-fd 0 -c "$PWFILE"
   rm "$PWFILE"

   clear
   echo "Änderungen in Versionsverwaltung sichern?"
   echo -n "ja oder nein?> "
   read CHOICE
   if [ "$CHOICE" == "ja" ]; then
      cd "$PWROOT"
      echo
      git add -A
      git commit -m "Backup $(date)"
      waitforenter
   fi
}

function unknownoption() {
   clear
   echo
   echo "Ungültige Option"
   waitforenter
}

function changepassword() {
   clear
   echo "Das alte Passwort eingeben, danach zwei mal das neue."
   echo "Dabei werden keinerlei Eingaben angezeigt!"
   echo
   passwd
   waitforenter
}

function changemasterpassword() {
   local TMPPWA=$(readpassword "Neues Masterkennwort eingeben")
   echo
   local TMPPWB=$(readpassword "Neues Masterkennwort wiederholen")
   echo

   if [ "$TMPPWA" == "$TMPPWB" ]; then
      echo "$PW" | gpg -q --batch --yes --passphrase-fd 0 "$PWFILE.gpg" 2> /dev/null
      PW="$TMPPWA"
      echo "$PW" | gpg -q --batch --yes --passphrase-fd 0 -c "$PWFILE" 2> /dev/null
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

function checkmasterpw() {
   if [ -f "$PWFILE.gpg" ]; then
      echo "$1" | gpg -q --batch --yes --output - --passphrase-fd 0 "$PWFILE.gpg" 2> /dev/null > /dev/null
      echo $?
   else
      echo 1
   fi
}

function checkprogram() {
   local exist=0
   type $1 >/dev/null 2>&1 || { local exist=1; }
   echo "$exist"
}



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

# Create passwordmanager directory
if [ ! -d "$PWROOT" ]; then
   mkdir -p "$PWROOT"
fi

cd "$PWROOT"

# Initialize GIT repo
if [ ! -d "$PWROOT/.git" ]; then
   git init
   echo "$PWFILE" > .gitignore
   git add -A
   git commit -m "Created git repo and added .gitignore"
fi

# Set permissions
chown -R $USER:$USER "$PWROOT"
chmod u=rwx,go=- "$PWROOT"

# Enter masterpw
PW=$(readpassword "Bitte Masterkennwort eingeben")
RESULT=$(checkmasterpw "$PW")

echo $RESULT

# Check MasterPW
if [ "$RESULT" == "2" ]; then
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
echo
echo "9] Ausloggen"
echo

echo -n "> "
read INPUT

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

9)
   break;
   ;;

*)
   unknownoption
   ;;

esac


done

