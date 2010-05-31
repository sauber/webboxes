#!/usr/bin/perl -I../lib

use strict;
use warnings;
use Data::Dumper;
use Job::Assign;

our $assign = new Job::Assign;

# Add a bunch of jobs
for my $j ( 0 .. 99 ) {
  $assign->job_add( summary => "test $j", _id=>$j );
}

# Add a bunch of queues
for my $q ( qw(John-1 John-2 Jack-1 Jack-2) ) {
  $assign->queue_add( name => $q );
}

# Add unassigned jobs to queues

# Reorder pending jobs in queues

