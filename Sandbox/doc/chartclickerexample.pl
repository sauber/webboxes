#!/usr/bin/env perl

use Chart::Clicker;
my $cc = Chart::Clicker->new;

my $data = { 12 => 123, 13 => 341, 14 => 1241 };
$cc->add_data('Sales', $data);

$cc->write_output('foo.png');

