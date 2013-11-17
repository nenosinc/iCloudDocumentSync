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

#### Documentation Guidelines
Before submitting any changes, make sure that you've documented those changes. The changes you make should be noted in the Changelog.md file. If necessary, make the appropriate updates in the Readme.md file. You should also write appropriate documentation in the code (using comments). You can use documentation comments to create and modfy documentation. Always write the documentation comments in the header, above the related method, property, etc. Write regular comments with your code in the implementation too. Here's an example of a documentation comment:

    /// One line documentation comments can use the triple forward slash
    @property (strong) NSObject *object;

    /** Multi-line documentation comments can use the forward slash with a double asterik at the beginning and a single asterick at the end.
        @description Use different keys inside of a multi-line documentation comment to specify various aspects of a method. There are many available keys that Xcode recognizes: @description, @param, @return, @deprecated, @warning, etc. The documentation system also recognizes standard markdown formatting within comments. When building the documentation, this information will be appropriately formatted in Xcode and the Document Browser.

        @param parameterName Paramater Description. The @param key should be used for each parameter in a method. Make sure to describe exactly what the parameter does and if it can be nil or not.
        @return Return value. Use the @return key to specify a return value of a method. */
    - (BOOL)alwaysWriteDocumentCommentsAboveMethods:(NSObject *)paramName;

#### Building the Documentation
Documentation is a fundamental portion of iCloud Document Sync. When you make changes to iCloud Document Sync (especially breaking changes), those changes should be documented (along with any additions or removals). You'll need to document changes in a few places (may vary by case): Readme.md, Changelog.md, and the DocSet bundle within the Documentation folder. This section discusses how to build the documentation through Xcode for the DocSet.

1. Make any changes to the project and build it with the *iCloud* target selected  
2. When you've finished making changes and testing, select the *Documentation* target from the scheme selector in the upper-left corner of Xcode. Click on Build / Run. Xcode will generate the framework and related documentation.  
3. To find the documentation, open Finder and then press CMD+SHIFT+G. A prompt will appear and ask for a path to navigate to. Paste the following into the prompt: `~/Library/Developer/Shared/Documentation/DocSets/`. Finder will open to that folder if it exists (it should).  
4. Find the `com.iRareMedia.iCloudSDK.docset` DocSet bundle (if everything build correctly, it should be there - if not try running `mdfind com.iRareMedia.iCloudSDK.docset` in the terminal).  
5. Copy the DocSet into the iCloud Document Sync folder titled *Documentation*. Be sure that the old DocSet is completely overwritten / replaced.

## Too Confusing? Too Much Work?
Building the documentation and framework for submitting changes can be a very tedious process. If you don't have time, can't do it, don't know how to do it, or just want to make a small change - don't worry. Just make your change and don't bother with building the documentation or framework. When you submit a pull request we can fix it up.

## Automated Builds
We're looking for a way to automatically build the documentation and framework everytime the iCloud project is compiled and built. If you can figure out how to setup an automatic build system, please let us know how, or submit a pull request. We'd really appreciate that (and so would every other contributor).

## What to Contribute
Contribute anything, we're open to ideas! Although if you're looking for a little more structure, you can go through the [open issues on GitHub](https://github.com/iRareMedia/iCloudDocumentSync/issues?status=open) or look at the known issues in the [Releases documentation](https://github.com/iRareMedia/iCloudDocumentSync/releases). And if you're feeling adventerous, we're still working on adding OS X Compatibility (wink wink, nudge nudge).