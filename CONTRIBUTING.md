## Contributing
This document lays out exactly how you can contribute to iCloud Document Sync. Thanks for contributing!

### How to Contribute - Issues
Found something that needs to be improved or fixed? Here's the best way to let everyone know about issues, bugs, possible new features, or just ask questions.

1. Sign up for a GitHub Account  
2. Star this repository (so you can follow changes and find it easily)  
3. Look through the [issues](https://github.com/iRareMedia/iCloudDocumentSync/issues) (opened or closed) for iCloud Document Sync to see if your issue has already been fixed, answered, or is being fixed  
4. Create a [new issue](https://github.com/iRareMedia/iCloudDocumentSync/issues/new) from the issues tab on the right side of the screen

### How to Contribute - Changes
Want to make a change to this project? Maybe you have a great idea, a new feature, bug fix, or something else. Here's the best way to contribute changes to the project.

1. Sign up for a GitHub Account  
2. Star this repository (so you can follow changes and find it easily)  
3. Fork this repository and clone your fork onto your computer  
4. Make changes to the forked repo (you'll probably want to change the `iCloud.m` and `iCloud.h` files)  
5. Build the files, fix any errors, debug, test debug some more, build again  
6. Ensure that you build the Framework target and copy the built framework into the project folder (overwrite the older version)  
7. If you made any changes to the documentation, make sure to build the Documentation target and copy the built docset bundle into the project folder (overwrite the older version)  
8. Commit and then push all your changes up to your forked GitHub repo
9. Submit a pull request from your forked GitHub repo into the main repo. Your pull request will then be reviewed and possibly accepted if everything looks good

#### Code Guidelines
Before submitting any code changes, read over the code / syntax guidelines to make sure everything you write matches the appropriate coding style. The [Objective-C Coding Guidelines](https://github.com/github/objective-c-conventions) are available on GitHub.

#### Building the Framework
Building the Framework for iCloud is easy, however finding where Xcode places it after built can be tricky. Follow these steps to build the Framework and copy it into the iCloud Document Sync project. In a future version, this process will be automated.

1. Make any changes to the project and build it with the *iCloud* target selected  
2. When you've finished making changes and testing, select the *Framework* target from the scheme selector in the upper-left corner of Xcode. Click on Build / Run. Xcode will generate the framework.
3. To find the framework, right click on `libiCloud.a` in the Products folder within Xcode and then click *Show in Finder*.
4. Finder will open with a folder showing all of the build products for iCloud Document Sync. Find the bundle called `iCloud.framework`. Copy that framework into the iCloud Document Sync project. Be sure that the old framwork is completely overwritten.

#### Building the Documentation
Instructions Coming Soon
