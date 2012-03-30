#!/usr/bin/perl
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
