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
└── passwords.txt.gpg

1 directory, 2 files
```

Screenshots
-----------
![Login](/Screenshot-11.png "Login")

![Mainmenu](/Screenshot-12.png "Mainmenu")
