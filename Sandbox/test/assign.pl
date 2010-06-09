#!/usr/bin/perl -I../lib

use strict;
use warnings;
use Data::Dumper;
use Load::Manager;

our $jobs = new Load::Manager;

# Add a bunch of items, that are completed
for my $j ( 0 .. 9 ) {
  my $start = int( time-rand(10000) );
  my $stop = $start + int( rand(10000) );
  $jobs->item_add( item => {
    id=>$j,
    start=>$start,
    stop=>$stop,
  });
}

# Add some items, that are incompleted
for my $j ( 10 .. 19 ) {
  $jobs->item_add( item => {
    id=>$j,
    start=>int( time-rand(10000) ),
    completed=>rand,
  });
}

# Display average duration:
printf "Average time: %f\n", $jobs->average_item_duration();

# Move item #19 first
$jobs->move_first( item => {
  id=>19, start=>int( time-rand(10000) ), completed=>rand,
});

# Move item #10 last
$jobs->move_last( item => {
  id=>10, start=>int( time-rand(10000) ), completed=>rand,
});

# Move item #12 before #11
$jobs->move_before(
  item => { id=>12, start=>int( time-rand(10000) ), completed=>rand },
  before => { id=>11 }
);

# Move item #17 after #18
$jobs->move_after(
  item => { id=>17, start=>int( time-rand(10000) ), completed=>rand },
  after => { id=>18 }
);

# Display eta for none-completed items
for my $job ( $jobs->estimated_item_stop() ) {
  printf "ETA for %s (%02.1f%% completion): %i (duration: %i)\n", $job->{item}{id}, 100*$job->{item}{completed}, $job->{eta}, $job->{duration};
}
