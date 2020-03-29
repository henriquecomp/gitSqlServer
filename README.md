# GIT SQLSERVER Workaround

It's a small piece of code to track changes on SQL Server objects and commit into GIT.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes, and if you are satisfect install it on your server.

### Prerequisites

You will need:
* SQL Server Management Studio
* Visual Studio
* NET Framework 4.6.1
* GIT
* A basic knowledge of SQL Server and GIT

```
Give examples
```

### Installing

* Clone your source code into your server. Keep in mind this path, you will using on table GITConfig.
* Clone this repository
* After that, open CLR.sln in Visual Studio.
* Build the project
* Go to \bin\Realease and copy CLR.dll
* Paste CLR.dll in the folder that you wish. Keep this path, you will need below.
* Open install.sql (the file is in the CLR.sln) in your SSMS.
* Change the lines 6, 24 and 60 to your configurations.
* Run all the script.

### Executing
* Execute a select on table GITConfig
* Change only Value column with new values.
* If you want to configure more one user, INSERT using the same schema, so, get user machine name, and create 4 records with the same tag.
* Now you are able to execute the command to commit in git.

### Main command

```
EXEC git '<branch>', '<objeto_to_commit>', '<message>'
```


## Built With

* NET Framework 4.6.1
* SQL Server 2016
* GIT

## Authors

* **Henrique Fávaro Tâmbalo** - *GitSqlServer* - [henriquecomp](https://github.com/henriquecomp)

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
