#!/usr/bin/perl
# Copyright 2011 Peter Tillemans

#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at

#        http://www.apache.org/licenses/LICENSE-2.0

#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

use File::Find;

my $script = "";
my $target_url;
my $target_dir;

sub wanted() {
  my $f = $File::Find::name;
  if (-f $f) {
    $script .= "mput $f\n";
  } else {
    $script .= "mkdir $f\n";
  }
}

my $url = $ARGV[0];
print "URL: $url";

if ($url =~ m#dav://.*?(/\S*)#) {

  $target_url = "$0";
  $target_dir = "$1";

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
