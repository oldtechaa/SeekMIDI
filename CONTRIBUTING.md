# How to Contribute to SeekMIDI #

## The Basics ##

### Why Contribute ###

Perhaps you want new functionality in SeekMIDI, or you've found a bug. Perhaps you just want to help out somewhere and think this would be a good place to start. We can certainly use your help, and we welcome contributors! It's a big job to write any program, especially only in your free time.

### Where to Start ###

To help out, look through the sections below for the type of contribution you would like to make. There are many different ways to help on SeekMIDI.

### Getting SeekMIDI ###

Follow [these directions](https://help.github.com/articles/cloning-a-repository/) to download the repo. Begin development!

### Making Changes ###

Here are some guidelines on coding style for changes:

 * Use two space indentation. Not tabs.

 * Functions should be called in this style: $foo->bar()

 * Keywords and built-ins should be called in this style: for ()

 * Properties of a class should not use parentheses, like this: $foo->bar

 * Use perlish fors when possible, declaring the count variable before the opening parentheses. C-style loops should generally be avoided.

 * Use good judgement when choosing to optimise for performance versus readability. If some "performance optimisation" is not generally accepted as improving performance and harms readability, don't use it.

 * Use single quotes when not including variables to be escaped, double quotes if including escaped variables.

 * Comment your code as you add major new features.

 * For anything not mentioned here, take a look at the existing code for examples of how to format things.

### Submitting Pull Requests ###

Follow [these directions](https://help.github.com/articles/creating-a-pull-request/) to submit a pull request to the repository when done with your changes.

### Issue Tracker ###

The issue tracker is located [here](https://github.com/oldtechaa/SeekMIDI/issues).

## Reporting Bugs ##

If you've found a bug in SeekMIDI, please report it. We can't test everything, so we appreciate it when others report bugs. You can use the issue tracker to report it. Please clearly state the following:

 * **What does the bug make the program do?**
 
 * **What should the program do?**
 
 * **What version did this appear in?**
 
 * **Were there any versions in which the bug did not appear? If so, which ones?**
 
 * **How can we reproduce this bug?**
 
 * **What is your system configuration?**
 
Please use tags to label the severity of the problem, and use the "bug" tag when submitting.

### Security ###

If you are reporting a security issue, please use the **"security"** tag. We will attempt to repair the flaw immediately.

## Bug Triage ##

If a bug affects you as it does other people, please use the discussion functionality in the issue tracker to confirm that it affects you as well. If you have extra details, by all means report them!

## Adding Features ##

If you have a feature you really want implemented in SeekMIDI, there are two ways to get it implemented:

 * Clone the repo, make your changes, then submit a pull request. Watch for acceptance and merge!
 
     **Please note that not all pull requests may be acccepted. You may want to use the second method of adding features if you're not sure about your feature.**
 
 * Submit an issue listing what you want to do, your reasons, and how you would like to implement it. When it is discussed and approved, you can begin implementing it and then submit a pull request referencing the issue in which it was discussed. This way, you will be assured of acceptance of your pull request before you start work.

## Fixing Bugs ##

If you have found a bug you want to fix, look through the issue report and discussion. Some bugs may have a known cause and just haven't been fixed, others may take some searching. Whatever the case, once you find the cause and fix the bug, submit a pull request. We'll try to test it a little and put it in the master for further testing.

## Helping Out Wherever ##

If you just want to help out somewhere, we suggest you look through the "help-wanted" issues. When you find one you like, try your hand at fixing it. Then submit a pull request when you get it done.

## Conclusion ##

### How to Get Help ###

Everyone was new to contributing at one time. If you need help, don't hesitate to ask! Email me at [oldtechaa@gmail.com](mailto://oldtechaa@gmail.com)

### Thanks for Contributing! ###

Whatever type of contribution you made, thank you very much for your assistance. We can use all the help we can get.

### Legal ###

By submitting contributions in code form to this project, you agree to license your contributions under the GPLv3+ license. By licensing your code in this way, you grant us the rights to incorporate the code in SeekMIDI. You retain your copyright and will be credited for your contribution.
