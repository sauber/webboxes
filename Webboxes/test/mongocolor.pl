#!/opt/local/bin/perl

use MongoDB;
use Data::Dumper;
use strict;
use warnings;

my $conn = MongoDB::Connection->new;
my $db = $conn->get_database("color_test");
my $coll = $db->get_collection("colors");

#print Dumper $conn;
#print Dumper $db;
#print Dumper $coll;

#my $colors = MongoDB::Connection->new()->get_database('color_test')->get_collection('colors');
my $r = $coll->query();
#print MongoDB::Database::last_error() . "\n";
print Dumper $r;

#my $r = $colors->query({})->all;

while (my $doc = $r->next) {
  print $doc->{'color'}."\n";
}

