This is a password manager for the linux shell. The script provides a interactive shell to view and edit passwords.
All data is stored encrypted with GPG.
Any change will stored in a git repository. Of course only the encrypted data.

* Encrypted a password (GPG)
* View and Edit
* vim and nano supported
* Store changes in a git repository

Password Storage
----------------
```
~/.pwmgrsh/
├── .git
├── .gitignore
├── hosting.txt.gpg
└── passwords.txt.gpg

1 directory, 3 files
```

Installation
------------
Simple clone the repo from github:
```
git clone https://github.com/agentp/pwmgrsh.git
cd pwmgrsh
chmod a+x pwmgr.sh
./pwmgr.sh
```
For a global installation use as root the option in pwmgrsh menu.

Update
------
Simple update the repo from github:
```
cd pwmgrsh
git pull
```

Uninstall
---------
- Use the option in pwmgrsh as root
- Remove the pwmgrsh folder
- Remove all .prmgrsh folders in user homes

Screenshots
-----------
![Login](/Screenshot-11.png "Login")

![Mainmenu](/Screenshot-12.png "Mainmenu")
