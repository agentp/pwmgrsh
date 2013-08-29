#!/bin/bash

CGRAY="\033[1;30m"
CLGRAY="\033[1;37m"
CCYAN="\033[1;36m"
CLCYAN="\033[1;36m"
CNOCOLOR="\033[0m"
CBLUE="\033[1;34m"
CLBLUE="\033[1;34m"
CRED="\033[1;31m"
CLRED="\033[1;31m"
CGREEN="\033[1;32m"
CLGREEN="\033[1;32m"
CPURPLE="\033[1;35m"
CLPURPLE="\033[1;35m"
CBROWN="\033[1;33m"
CYELLOW="\033[1;33m"
CBLACK="\033[1;30m"
CWHITE="\033[1;37m"

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

function yesno() {
   echo -e -n "${CPURPLE}ja oder nein?>$CNOCOLOR "
   read CHOICE
   if [ "$CHOICE" == "ja" ]; then
      return 0
   else
      return 1
   fi
}

function banner() {
   # Source: http://patorjk.com/software/taag/#p=testall&f=Graffiti&t=pwmgrsh
   echo -e "$CPURPLE                                    _     "
   echo -e "                                   | |    "
   echo -e "  ____  _ _ _ ____   ____  ____ ___| |__  "
   echo -e " |  _ \| | | |    \ / _  |/ ___)___)  _ \ "
   echo -e " | |_| | | | | | | ( (_| | |  |___ | | | |"
   echo -e " |  __/ \___/|_|_|_|\___ |_|  (___/|_| |_|"
   echo -e " |_|               (_____|                $CNOCOLOR"
   echo -e "${CRED}Password Manager Shell by Christian Blechert"
   echo -e "Source Code: https://github.com/agentp/pwmgrsh"
   echo -e "Aktive Passwort Datei:$CNOCOLOR $(basename "$PWFILE" | sed 's/\.txt$//g')"
}

# Pause the script execution and wait for enter
function waitforenter() {
   echo
   echo -n -e "${CPURPLE}Enter drücken zum fortfahren...$CNOCOLOR "
   read
}

# Unknown option!
function unknownoption() {
   clear
   echo
   echo "Ungültige Option"
   sleep 1
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
   local apwd="$1"   
   
   killpwfile
   touch "$TMPPWFILE"
   chown $USER:$GROUP "$TMPPWFILE"
   chmod u=rw,go=- "$TMPPWFILE"
   echo -n "$apwd" > "$TMPPWFILE"
}

# Delete the password file
function killpwfile() {
   if [ -f "$TMPPWFILE" ]; then
      rm "$TMPPWFILE"
   fi
}

# Protect the files
function setpwfilepermissions() {
   local apwfile="$1"

   if [ -f "$apwfile" ]; then
      chown $USER:$GROUP "$PWFILE"
      chmod u=rw,go=- "$apwfile"
   fi
   if [ -f "$apwfile.gpg" ]; then
      chown $USER:$GROUP "$apwfile.gpg"
      chmod u=rw,go=- "$apwfile.gpg"
   fi
}

# Encrypt the password list
function fileencrypt() {
   local apwd="$1"
   local apwfile="$2"

   createpwfile "$apwd"
   gpg -q --batch --yes --passphrase-fd 0 -c "$apwfile" < "$TMPPWFILE" 2> /dev/null
   local RES=$?
   killpwfile
   setpwfilepermissions
   return $RES
}

# Decrypt the password list
function filedecrypt() {
   local apwd="$1"
   local aaction="$2"
   local apwfile="$3"

   createpwfile "$apwd"
   local RES=9
   if [ "$aaction" == "echo" ]; then
      gpg -q --batch --yes --output - --passphrase-fd 0 "$apwfile.gpg" < "$TMPPWFILE" 2> /dev/null
      RES=$?
   else
      gpg -q --batch --yes --passphrase-fd 0 "$apwfile.gpg" < "$TMPPWFILE" 2> /dev/null
      RES=$?
   fi
   
   killpwfile
   setpwfilepermissions "$apwfile"
   return $RES
}

# Check GPG password is correct
function checkmasterpw() {
   local apwd="$1"
   local apwfile="$2"

   if [ -f "$apwfile.gpg" ]; then
      filedecrypt "$apwd" "echo" "$apwfile" 2> /dev/null > /dev/null
      echo $?
   else
      echo 1
   fi
}

# Display the password list
function showpasswords() {
   local apwd="$1"
   local apwfile="$2"

   clear
   echo
   echo -e "Zeige Passwörter an:"
   echo -e "${CPURPLE}----------------------$CNOCOLOR"
   echo

   if [ -f "$apwfile.gpg" ]; then
      filedecrypt "$apwd" "echo" "$apwfile"
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
   local apwd="$2"
   local apwfile="$3"
   
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

   filedecrypt "$apwd" "file" "$apwfile"
   $ED "$apwfile"
   fileencrypt "$apwd" "$apwfile"
   rm "$apwfile"

   if [ "$GITAVAILABLE" == "1" ]; then
      clear
      echo "Änderungen in Versionsverwaltung sichern?"
      yesno
      if [ "$?" == "0" ]; then
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
   local apwfile="$1"

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
      filedecrypt "$OLDPW" "file" "$apwfile"
      PW="$TMPPWA"
      fileencrypt "$TMPPWA" "$apwfile"
      rm "$apwfile"
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
   yesno
   if [ "$?" == "0" ]; then
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

function isinstalled() {
   if [ -L "$BINLINK" ]; then
      echo 1
   else
      echo 0
   fi
}

# Install in system
function installpwmgrsh() {
   if [ "$(isinstalled)" == "1" ]; then
      echo -e "pwmgrsh ist unter ${CRED}$BINLINK$CNOCOLOR im System installiert."
      echo "Somit können alle Benutzer auf den Passwortmanager"
      echo -e "mit dem Befehl ${CRED}$(basename "$BINLINK")$CNOCOLOR zugreifen und ihn nutzen."
      echo
      echo "Möchtest Du die Installation rückgängig machen?"
   else
      echo "pwmgrsh ist nicht im System installiert."
      echo -e "Bei einer Installation wird ein symlink unter ${CRED}$BINLINK$CNOCOLOR angelegt."
      echo
      echo -e "Der Passwortmanager wird dann für alle Benutzer mit dem Befehl ${CRED}$(basename "$BINLINK")$CNOCOLOR nutzbar sein."
   fi   
   echo
   echo "Fortfahren?"
   yesno
   if [ "$?" == "0" ]; then
      if [ "$(isinstalled)" == "1" ]; then
         rm "$BINLINK"
         chown $USER:$GROUP "$SCRIPT"
         chmod u=rwx,go=- "$SCRIPT"
         echo "Symlink wurde entfernt und die Benutzerrechte auf dieses Script auf dich allein beschränkt."
      else
         ln -s "$SCRIPT" "$BINLINK"
         chown $USER:$GROUP "$SCRIPT"
         chmod u=rwx,go=rx "$SCRIPT"
         echo "Symlink wurde angelegt und die Rechte auf dieses Script so verändert, dass alle darauf zugreifen können."
         echo -e "Mit dem Befehl ${CRED}$(basename "$BINLINK")$CNOCOLOR kann pwmgrsh nun aufgerufen werden."
      fi
      waitforenter
   fi
}

# List pwfiles
function listfiles() {
   while IFS= read -r line
   do
      local linefile="$(basename "$line" | sed 's/\.txt\.gpg$//g')"

      echo -n "["
      if [ "$(basename "$PWFILE" | sed 's/\.txt$//g')" == "$linefile" ]; then
         echo -n -e "${CRED}x$CNOCOLOR"
      else
         echo -n " "
      fi
      echo -n "] "
      echo -e "${CGREEN}$linefile$CNOCOLOR"
   done <<< "$(ls -1)"
}

function filescount() {
   ls -1 | wc -l
}

# Change the password file
function changefile() {
   local apwdfile="$(basename "$1" | sed 's/\.gpg$//g' | sed 's/\.txt$//g')"

   if [ "$apwdfile" == "" ]; then
      echo -e "Datei auswählen:"
      echo
   
      listfiles
   
      echo
      echo -n -e "${CPURPLE}>$CNOCOLOR "
      read INPUT
   
      if [ "$INPUT" == "" ]; then
         return 1
      fi
   
      local targetfile="$PWROOT/$(echo $INPUT | sed 's/[^A-Za-z0-9]/_/g').txt"
      echo
   else
      local targetfile="$PWROOT/$apwdfile.txt"
   fi
   
   if [ ! -f "$targetfile.gpg" ]; then

      echo "Neue Passwort Datei erstellen?"
      yesno
      if [ ! "$?" == "0" ]; then
         return 1;
      fi
      echo
      
      local TMPPWA=$(readpassword "Masterkennwort für neue Datei eingeben")
      echo
      local TMPPWB=$(readpassword "Masterkennwort für neue Datei wiederholen")
      echo

      if [ "$TMPPWA" == "$TMPPWB" ]; then
         PWFILE="$targetfile"
         PW="$TMPPWA"
         echo "Neue Datei, erstellt am $(date)" > $PWFILE
         fileencrypt "$PW" "$PWFILE"
         rm "$PWFILE"
      else
         echo
         echo "Passwörter stimmen nicht überein!"
         waitforenter
         return 2
      fi

   else
   
      CRESULT=$(checkmasterpw "$PW" "$targetfile")
      if [ "$CRESULT" == "2" ]; then
         local NEWPW=$(readpassword "Masterkennwort für '$(basename "$targetfile" | sed 's/\.txt$//g')' eingeben")
         echo
      
         RESULT=$(checkmasterpw "$NEWPW" "$targetfile")
         if [ "$RESULT" == "2" ]; then
            echo "Masterkennwort nicht korrekt!"
            echo "Dateiwechsel abgebrochen."
            waitforenter
            return 3
         else
            PWFILE="$targetfile"
            PW="$NEWPW"
         fi
      else
         PWFILE="$targetfile"
      fi
   
   fi

   return 0
}

# Reset pwmgr
function resetpwmgr() {

   if [ "$(filescount)" -gt "0" ]; then
      
      echo "Hier können die Passwort Dateien oder die Versionsverwaltung"
      echo "gelöscht werden. Wenn nur die Versionsverwaltung gelöscht"
      echo "werden soll, einfach [Enter] drücken."
      echo
      echo "Datei auswählen:"
      echo
      listfiles
      
      echo
      echo -n -e "${CPURPLE}>$CNOCOLOR "
      read INPUT
      local delfile="$PWROOT/$INPUT.txt"
   
      if [ ! "$INPUT" == "" ] && [ -f "$delfile.gpg" ]; then
         
         echo
         TMPPW=$(readpassword "Masterkennwort zur Bestätigung")
         echo
         RESULT=$(checkmasterpw "$TMPPW" "$delfile")
         if [ "$RESULT" == "2" ]; then
            echo "Masterkennwort wurde falsch eingegeben!"
            waitforenter
            return
         else
            rm "$delfile.gpg"
            echo "Datei erfolgreich gelöscht!"
            echo
            git add -A
            git commit -m "Datei gelöscht: $INPUT $(date)"
         fi
         
      fi
      
      
   fi
   
   if [ "$GITAVAILABLE" == "1" ]; then
      echo
      resetgit
   fi

}



# Get script location
SCRIPT=$(readlink -f "$0")
SCRIPTDIR=$(dirname "$SCRIPT")
BINLINK="/usr/bin/pwmgrsh"

# Get User Info
USER=$(id -u -n)
GROUP=$(id -g -n)

# Set PWROOT
PWROOT="$(cat /etc/passwd | grep -E "^$USER:" | cut -d ':' -f 6)/.pwmgrsh"
TMPPWFILE="$PWROOT/.temppw.$$"
PWFILE="$PWROOT/passwords.txt"

# Select first pwfile if passwords.txt.gpg not exist
if [ ! -f "$PWFILE.gpg" ] && [ "$(ls -1 "$PWROOT" | wc -l)" -gt 0 ]; then
   PWFILE="$PWROOT/$(ls -1 "$PWROOT" | head -n 1 | sed 's/\.gpg$//g')"
fi



clear
banner
echo
echo "Prüfe auf alle benötigten Programme..."
ERROR=0
GITAVAILABLE=1
for PROG in gpg vim cat chown chmod git nano read rm readlink dirname basename;
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

if [ "$ERROR" == "1" ] || [ "$GITAVAILABLE" == "0" ]; then
   echo -e "${CRED}Einige Programme wurden nicht gefunden! Bitte nachinstallieren!$CNOCOLOR"
   waitforenter
fi

if [ "$ERROR" == "1" ]; then
   exit 1
fi

clear
banner
echo



# Create passwordmanager directory
if [ ! -d "$PWROOT" ]; then
   echo -e "Es muss ein Ordner zur Speicherung der verschlüsselten Daten angelegt werden."
   echo -e "Speicherort: ${CPURPLE}$PWROOT$CNOCOLOR"
   echo
   echo "Fortfahren?"
   yesno
   if [ "$?" == "1" ]; then
      echo "Programm wird beendet."
      waitforenter
      exit 1
   fi
   mkdir -p "$PWROOT"
   echo -e "${CPURPLE}Erstelle $PWROOT$CNOCOLOR"
   echo
fi

cd "$PWROOT"

# Kill unencrypted pasword file if exist
if [ -f "$PWFILE" ]; then
   rm "$PWFILE"
fi

# Initialize GIT repo
if [ ! -d "$PWROOT/.git" ] && [ "$GITAVAILABLE" == "1" ]; then
   echo -e "${CPURPLE}Initialize git repository$CNOCOLOR"

   if [ ! -f "$HOME/.gitconfig" ]; then
      git config --global user.email "$USER@localhost"
      git config --global user.name "$USER"
   fi

   git init
   echo "$PWFILE" > .gitignore
   echo "$TMPPWFILE" >> .gitignore
   git add -A
   git commit -m "Created git repo and added .gitignore"
   echo
fi

# Set permissions
chown -R $USER:$GROUP "$PWROOT"
chmod -R u=rwx,go=- "$PWROOT"



clear
banner
echo



# Enter master password
changefile "$PWFILE"
RESULT=$?

echo
if [ "$RESULT" == "1" ]; then
   echo "Aktionen abgebrochen."
elif [ "$RESULT" == "2" ]; then
   echo "Masterkennwörter stimmen nicht überein!"
elif [ "$RESULT" == "3" ]; then
   echo "Masterkennwort ist nicht korrekt!"
fi

if [ ! "$RESULT" == "0" ]; then
   echo "Verbindug wird beendet!"
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
echo -e "${CPURPLE}1]$CNOCOLOR Passwortdatei wechseln"
echo -e "${CPURPLE}2]$CNOCOLOR Passwörter anzeigen"
echo -e "${CPURPLE}3]$CNOCOLOR Passwörter mit vim bearbeiten"
echo -e "${CPURPLE}4]$CNOCOLOR Passwörter mit nano bearbeiten"
echo -e "${CPURPLE}5]$CNOCOLOR Login Passwort ändern"
echo -e "${CPURPLE}6]$CNOCOLOR Masterkennwort ändern"
if [ "$GITAVAILABLE" == "1" ]; then
   echo -e "${CPURPLE}7]$CNOCOLOR Historie der Versionsverwaltung anzeigen"
fi
if [ "$USER" == "root" ] && [ "$(isinstalled)" == "1" ]; then
   echo -e "${CPURPLE}8]$CNOCOLOR pwmgrsh deinstallieren"
elif [ "$USER" == "root" ] && [ "$(isinstalled)" == "0" ]; then
   echo -e "${CPURPLE}8]$CNOCOLOR pwmgrsh installieren"
fi
echo -e "${CPURPLE}9]$CNOCOLOR Zurücksetzen"
echo
echo -e "${CPURPLE}0]$CNOCOLOR Ausloggen"
echo

echo -n -e "${CPURPLE}>$CNOCOLOR "
read INPUT

clear
case $INPUT in

1)
   changefile
   ;;
2)
   showpasswords "$PW" "$PWFILE"
   ;;
3)
   editpasswords vim "$PW" "$PWFILE"
   ;;
4)
   editpasswords nano "$PW" "$PWFILE"
   ;;
5)
   changepassword
   ;;
6)
   changemasterpassword "$PWFILE"
   ;;
7)
   if [ "$GITAVAILABLE" == "1" ]; then githistory; else unknownoption; fi
   ;;
8)
   if [ "$USER" == "root" ]; then installpwmgrsh; else unknownoption; fi
   ;;
9)
   resetpwmgr
   ;;
0)
   break;
   ;;
*)
   unknownoption
   ;;

esac


done

