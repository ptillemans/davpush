# Uploading documents with WebDAV

## Using the *Cadaver* WebDAV client

Although WebDAV is currently well integrated in modern desktop environments, a CLI alternative is useful for automation, like *Jenkins* build scripts.

### Automatic Login

Ideally we want password-less operation from script, both from a usability  as from a security standpoint.

*Cadaver*  supports  automatically logging in to servers requiring authentication via a .netrc file, like the *ftp* client. The syntax is such that the file can be shared for both tools.

The file ~/.netrc may be used to automatically login to a server requiring authentication. The following tokens (separated by spaces, tabs  or newlines) may be used:

#### machine host

Identify  a  remote  machine  host which is compared with the hostname given on the command line or as an argument to the open command. Any subsequent tokens up to the end of file or the next machine or default token are associated with this entry.

#### default

This is equivalent to the machine token but matches any hostname. Only one default token may be used and it must be after  all  machine tokens.

#### login *username*

Specifies the username to use when logging in to the remote machine.

#### password *secret*

Specifies the password to use when logging in to the remote machine. (Alternatively the keyword **passwd** may be used)

#### Example ~/.netrc file

    default
    login jenkins
    passwd secret
    
#### Example Session

### Troubleshooting

#### Error 409 Conflict
This can mean a lot of things, like a real conflict. However most of the time it means that the folder where the stuff is uploaded does not exist:
 
    dav:/cmdb/Members/pti/> mput Dropbox/Apps/Byword/plone_webdav.md
    Uploading Dropbox/Apps/Byword/plone_webdav.md to `/cmdb/...':
    Progress: [=============================>] 100,0% of 1488 bytes failed:
    409 Conflict
   
This actually tries to upload the file to a subfolder *Dropbox/Apps/Byword*which does not exist, causing this confusing error.

Simply changing the local directory solves the issue:

    dav:/cmdb/Members/pti/> lcd Dropbox/Apps/Byword
    dav:/cmdb/Members/pti/> mput plone_webdav.md
    Uploading plone_webdav.md to `/cmdb/Members/pti/plone_webdav.md':
    Progress: [=============================>] 100,0% of 1488 bytes succeeded.
    
#### Cannot create folders using WebDAV

Problem: The WebDAV "make folder" method, MKCOL, requires the "Add Folders" permission. This is not normally granted to Members or Owners on the site.

    dav:/cmdb/Members/jenkins/> mkcol test2
    Creating `test2': Authentication required for Zope on server `cmdb-uat.elex.be':
    Username: 
    Password: 
    Retrying: Authentication required for Zope on server `cmdb-uat.elex.be':
    Username: Terminated by signal 2.

Plone asks to login again because the current user has insufficient rights.

Workaround: In the Zope Management Interface, under the "Security" tab for the Plone root, check the "Owners" and "Managers" box for the "Add Folders" permission setting.

    ~  ᐅ cadaver dav://cmdb-uat.elex.be:1980/cmdb/Members/jenkins
    dav:/cmdb/Members/jenkins/> mkcol test2
    Creating `test2': succeeded.
    dav:/cmdb/Members/jenkins/> 

Source: [Members Can't Create Folders Through WebDAV](http://plone.org/documentation/error/unable-to-create-a-folder-through-webdav)

## Automating Cadaver with **davpush.pl**

Cadaver uses an ftp like command language to interact with the WebDAV server. This is very flexible, but impractical when a large number of files and  folders must be uploaded. This happens often when the documentation for a new release must replace the previous version.

Cadaver accepts its input on the  **stdin** stream, which allows us to pipe a script of commands to it. Since it is non-trivial to create and maintain such a script by hand,  a script generator is needed. The generator presented here is meant to be simple and easy to use and modify. No attempt was made to made to add advanced syncing (like removing deleted files), handle exceptions gracefully or 'do the right thing'. 

 With that in mind, organize the docs in such a way that it is easy to delete the target folder and push a fresh copy to clean everything up. This is common (and good) practice anyway in order to effectively use relative links within a subsite.
 
 The principle is to **cd** to the root directory of the documentation root and run the script there and point it to the target.
  
### Usage

    davpush.pl dav://_hostname_:_port_/_upload path_

Uploads all files and folders recursively to the WebDAV folder passed in the url.

### Code

	#!/usr/bin/perl
	use File::Find;
	
	my $script = "";
	
	sub wanted() {
	  my $f = $File::Find::name;
	  if (-f $f) {
	    $script .= "put $f\n";
	  } else {
	    $script .= "cd $target_dir\n";
	    $script .= "mkdir $f\n";
	    $script .= "cd $f\n"
	  }
	}
	
	my $url = $ARGV[0];
	print "URL: $url";
	
	if ($url =~ m#dav://.*?(/\S*)#) {
	
	  my $target_url = "$0";
	  my $target_dir = "$1";
	
	  find({'wanted'=>\&wanted, 'no_chdir' => 1},   ".");
	
	
	  $pid = open(POUT, "| cadaver $url");
	  print POUT $script;
	  print POUT "bye\n";
	  close POUT;
	
	} else {
	  print "Usage: davpush.pl dav://<hostname>:<port>/<upload path>\n";
	  print "\n";
	  print "Uploads all files and folders recursively to the WebDAV folder passed in the url.";
	}

### Code Notes

The standard perl **File::Find** module traverses the folder tree in the right order to make sure all folders are created before other files or folders are created in them. Default behavior is to **chdir** to the directory, but then we lose the nice paths relative  from the root, which would require additional administration entering and leaving the directory. Setting the **no_chdir** flag in the options keeps the paths like we want them in the script. (Look at the **preprocess** and **postprocess** options to help with the directory admin, but I think the added complexity will outweigh the gains for small to moderate trees)

For every file or folder, the **wanted** subroutine is called.  For files we just add a **mput** command to copy the file over, because it keeps the path intact. If there is a file already (and the permissions are not screwed up) then it is overwritten. When we enter a new folder then we create the folder. If the folder already exists we get a (harmless) **405 Method Not Allowed** error. Here we make another offer to the *God of Simplicity*, and *ignore* it.

After walking the tree, we have the script in the **$script** variable. It is unceremoniously piped as input for **cadaver**. We add the **bye** command to close the session, and we're done. The output of **cadaver** appears on the **stdout** for easy verification using a *MkI Eyeball* check or by piping it to **grep**.

### Sample session

	~/Dropbox/Apps/Byword  ᐅ perl ~/tmp/davpush.pl dav://cmdb-uat.elex.be:1980/cmdb/Members/pti
	URL: dav://cmdb-uat.elex.be:1980/cmdb/Members/ptiCreating `.': failed:
	405 Method Not Allowed
	Uploading ./plone_webdav.html to `/cmdb/Members/pti/plone_webdav.html':
	Progress: [=============================>] 100,0% of 4007 bytes succeeded.
	Uploading ./plone_webdav.md to `/cmdb/Members/pti/plone_webdav.md':
	Progress: [=============================>] 100,0% of 6369 bytes succeeded.
	Uploading ./Untitled.txt to `/cmdb/Members/pti/Untitled.txt':
	Progress: [=============================>] 100,0% of 203 bytes succeeded.
	Uploading ./Uploading to `/cmdb/Members/pti/Uploading': Could not open file: No such file or directory
	Uploading documents to `/cmdb/Members/pti/documents': Could not open file: No such file or directory
	Uploading to to `/cmdb/Members/pti/to': Could not open file: No such file or directory
	Uploading Plone to `/cmdb/Members/pti/Plone': Could not open file: No such file or directory
	Uploading with to `/cmdb/Members/pti/with': Could not open file: No such file or directory
	Uploading WebDAV.md to `/cmdb/Members/pti/WebDAV.md': Could not open file: No such file or directory
	Creating `./foo': failed:
	405 Method Not Allowed
	Creating `./foo/bar': failed:
	405 Method Not Allowed
	Creating `./foo/bar/baz': failed:
	405 Method Not Allowed
	Uploading ./foo/bar/baz/plone_webdav.md to `/cmdb/Members/pti/foo/bar/baz/plone_webdav.md':
	Progress: [=============================>] 100,0% of 3380 bytes succeeded.
	Creating `./images': failed:
	405 Method Not Allowed
	Uploading ./images/SJ09_1.jpg to `/cmdb/Members/pti/images/SJ09_1.jpg':
	Progress: [=============================>] 100,0% of 31637 bytes succeeded.
	Uploading ./images/SJ09_2.jpg to `/cmdb/Members/pti/images/SJ09_2.jpg':
	Progress: [=============================>] 100,0% of 29182 bytes succeeded.
	Uploading ./images/SJ09_3.jpg to `/cmdb/Members/pti/images/SJ09_3.jpg':
	Progress: [=============================>] 100,0% of 31296 bytes succeeded.
	Uploading ./images/SJ09_4.jpg to `/cmdb/Members/pti/images/SJ09_4.jpg':
	Progress: [=============================>] 100,0% of 31094 bytes succeeded.
	Uploading ./images/SJ09_5.jpg to `/cmdb/Members/pti/images/SJ09_5.jpg':
	Progress: [=============================>] 100,0% of 26886 bytes succeeded.
	Uploading ./images/SJ09_6.jpg to `/cmdb/Members/pti/images/SJ09_6.jpg':
	Progress: [=============================>] 100,0% of 29373 bytes succeeded.
	Uploading ./images/SJ09_7.jpg to `/cmdb/Members/pti/images/SJ09_7.jpg':
	Progress: [=============================>] 100,0% of 34486 bytes succeeded.
	Uploading ./images/SJ09_8.jpg to `/cmdb/Members/pti/images/SJ09_8.jpg':
	Progress: [=============================>] 100,0% of 28561 bytes succeeded.
	Uploading ./images/SJ09_9.jpg to `/cmdb/Members/pti/images/SJ09_9.jpg':
	Progress: [=============================>] 100,0% of 27381 bytes succeeded.
	Connection to `cmdb-uat.elex.be' closed.

