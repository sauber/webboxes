#!/usr/bin/env perl -I../lib

use strict;
use warnings;
#use pragma { no warnings; print ... };
binmode STDOUT, ":utf8";
use Load::Manager;
use Sandbox::Model::Project;

sub x {
 use Data::Dumper;
 warn Data::Dumper->Dump([$_[1]], ["*** dump $_[0]"]);
}

our $jobs = new Load::Manager;
our $proj = new Sandbox::Model::Project;
$proj->listid( 'UnixProjects' );

# Read configuration
my %F;
for my $field ( $proj->fieldlist() ) {
  if ( my $function = $field->{loadmanager} ) {
    my $fieldname = $field->{fieldname};
    for ( $function ) {
      /label/         and ++$F{label}{$fieldname};
      /color/         and ++$F{color}{$fieldname};
      /queuename/     and ++$F{queue}{$fieldname};
      /position/      and ++$F{position}{$fieldname};
      /completed/     and ++$F{completed}{$fieldname};
    }
  }
}
#x 'config', \%F;
#exit;

my $items = $proj->items->query();
while ( my $item = $items->next ) {

  my($cancel,$start,$stop) = $proj->itemstartstop( item => $item );

  # Skip cancelled
  next if $cancel;

  # Skip deleted if not completed
  next if $item->{_deleted} and not $stop;

  #printf "*** %s\n", $item->{Title};
  # Find stop
  #   or completed
  #   or start
  my $completed;
  unless ( $stop ) {
    ($completed) = map { $_/100 }
                   grep s/^.*?(\d+)\%.*/$1/,
                   grep { defined $_ }
                   map $item->{$_},
                   keys %{$F{completed}};
  }

  # Find queuename
  # Find queueposition
  my $name = join ', ', grep { defined $_ } map $item->{$_}, keys %{$F{queue}};
  my($position) = grep { defined $_ } map $item->{$_}, keys %{$F{position}};

  # Find label
  # Find color
  my $label = join ', ', grep { defined $_ } map $item->{$_}, keys %{$F{label}};
  my $color = join ', ', grep { defined $_ } map $item->{$_}, keys %{$F{color}};

  # Find id
  my $id = $item->{_id}{value};

  # Add to jobs
  #printf "       id=%s start=%s stop=%s completed=%s name=%s pos=%s color=%s label=%s\n", $id, $start, $stop, $completed, $name, $position, $color, $label;
  $jobs->item_add( item => {
    id => $id,
    label => $label,
    start => $start,
    stop => $stop,
    completed => $completed,
    queuename => $name,
    color => $color,
  });
}
#x 'jibs', $jobs;

for my $queuename ( sort $jobs->queue_list ) {
  $jobs->queue_sort( queuename => $queuename );
  $jobs->estimated_item_stop( queuename => $queuename );

  my %avg = $jobs->queue_stats( queuename => $queuename );
  print "=== Queuename: $queuename ===\n";
  printf "    Average Duration: %s days, Averages interval: %s days\n", int($avg{averageduration}/(24*3600)), int($avg{averagestoprate}/(24*3600));
  for my $j ( $jobs->queue_get( queuename => $queuename ) ) {
    printf("%s, %s%% %s\n", scalar(localtime($j->{etastop}||'')), 100*($j->{completed}||''), $j->{label}) if $j->{etastop} > (time()-180*24*3600);
  }
}
