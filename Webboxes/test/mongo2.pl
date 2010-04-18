#!/opt/local/bin/perl

use MongoDB;

my $conn = MongoDB::Connection->new;
my $db = $conn->get_database("color_test");
my $letters = $db->get_collection("colors");
#$letters->drop;

#for my $n ( 1..1000 ) {
#for my $l ( a..z ) {
#  #$letters->insert({
#  #  "letter" => $l, "inserts" => 1 });
#  $letters->update({"letter" => $l},
#    { '$inc' => {"inserts" => 1} },
#    {'upsert' => 1});
#  #print MongoDB::Database::last_error() . "\n";
#}
#}

$letters->insert({ "color" => 'green' });
my $r = $letters->query();
while ( my $doc = $r->next ) {
  printf "%s %s: %s\n", $doc->{_id}, $doc->{color}, $doc->{color};
}
