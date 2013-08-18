#!/bin/bash

# Get User Info
USER=$(id -u -n)
GROUP=$(id -g -n)

# Set PWROOT
PWROOT="$(cat /etc/passwd | grep -E "^$USER:" | cut -d ':' -f 6)/passwordmanager"

# Create passwordmanager directory
if [ ! -d "$PWROOT" ]; then
   mkdir -p "$PWROOT"
fi

cd "$PWROOT"

# Initialize GIT repo
if [ ! -d "$PWROOT/.git" ]; then
   git init
   echo "password.txt" > .gitignore
   git add -A
   git commit -m "Created git repo and added .gitignore"
fi

# Set permissions
chown -R $USER:$USER "$PWROOT"
chmod u=rwx,go=- "$PWROOT"



function waitforenter() {
   echo
   echo -n "Enter drücken zum fortfahren... "
   read
}

function showpasswords() {
   clear
   cat "$PWROOT/passwords.txt"
   waitforenter
}

function editpasswords() {
   echo "vim ist ein Editor der nur mit der Tastatur bedient wird."
   echo "Zum einfügen von Text muss in den Einfügen-Modus mit der Taste 'i' gewechselt werden."
   echo "Zum Ende mit ESC aus dem Einfügen-Modus aussteigen."
   echo "Mit :x speichern und beenden, mit :q! ohne Speichern beenden."
   waitforenter

   vim "$PWROOT/passwords.txt"
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

function changepassword() {
   clear
   echo "Das alte Passwort eingeben, danach zwei mal das neue."
   echo "Dabei werden keinerlei Eingaben angezeigt!"
   echo
   passwd
   waitforenter
}

# Run endless while
while true; do

clear
echo "Was möchtest Du machen?"
echo
echo "1] Passwörter anzeigen"
echo "2] Passwörter mit vim bearbeiten"
echo "3] Login Passwort ändern"
echo "9] Ausloggen"
echo

echo -n "> "
read INPUT

case $INPUT in

1)
   showpasswords
   ;;

2)
   editpasswords
   ;;

3)
   changepassword
   ;;

9)
   break;
   ;;

esac


done

