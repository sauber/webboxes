package Load::Manager;
use Moose;
use MooseX::Method::Signatures;

# Debug
sub x {
 use Data::Dumper;
 warn Data::Dumper->Dump([$_[1]], ["*** dump $_[0]"]);
}

# This will take a list of items and assign them into queues
# Moving already assign items from queue to another, or shift position
# within the queue will result in new ETA for all affected items.

########################################################################
### ITEMS
########################################################################

# Add a job definition
#   id:        optional, A uniq identifier of the item
#   category:  optional, list of categories this item belongs to
#   start:     optional, start time (since epoch) if item already started
#   stop:      optional, end time (since epoch) if item already completed
#   completed: optional, how completed (0.0-1.0) if already started
#   duration:  optional, compared to average duration (1.0) how large is item
#   queuename: optional, if already assigned to a queue
#   queue:     optional, if already assigned position in queue
#
method item_add ( HashRef :$item ) {
  my $queuename = $item->{queuename} || '';
  push @{ $self->{queue}{$queuename} }, $item;
  $self->clear_averages();
}

method item_remove ( HashRef :$item ) {
  my $queuename = $item->{queuename} || '';
  if ( my $id = $item->{id} ) {
    for my $i ( 0 .. $#{ $self->{queue}{$queuename} } ) {
      next unless $self->{queue}{$queuename}[$i]{id};
      if ( $self->{queue}{$queuename}[$i]{id} eq $id ) {
        #warn "Removing item $id from position $i\n";
        splice @{ $self->{queue}{$queuename} }, $i, 1;
        $self->clear_averages();
        return;
      }
    }
  }
}

# Get all items in queue, or only more recent that some time ago
#
method items_get ( Str :$queuename?, Num :$recent? ) {
  $queuename ||= '';
  return grep {
      if ( $recent and $_->{stop} and time()-$recent > $_->{stop} ) {
        undef;
      } else {
        1;
      }
    }
    @{ $self->{queue}{$queuename} };
}

########################################################################
### QUEUES
########################################################################

# Add a new queue
#   name: Name of queue
#
method queue_add (Str :$queuename) {
  $self->{queue}{$queuename} = [];
}

method queue_list {
  keys %{ $self->{queue} };
}

method queue_get ( Str :$queuename? ) {
  $queuename ||= '';

  return @{ $self->{queue}{$queuename} };
}


########################################################################
### ESTIMATES
########################################################################

# Average of numbers
#
sub average {
  my @n = sort { $a <=> $b } @_;
  return undef unless @n;
  my $avg;
  $avg += $_ for @n; $avg /= @n;
  return $avg;
}

# The middle number
sub median {
  my @n = sort { $a <=> $b } @_;
  return undef unless @n;
  return $n[ int(@n/2) ];
}

# Given a list of intervals, calculate
#  Average duration
#  Average rate of start
#  Average rate of stop
#  Median duration
#  Median rate of start
#  Median rate of stop
#
sub averages {
  my @n = @_;

  my($avgdur,$avgstart,$avgstop,$meddur,$medstart,$medstop);
  my(@durs,@starts,@stops);
  for ( @n ) {
    push @durs, ( $_->{stop} - $_->{start} ) if $_->{stop} and $_->{start};
    push @starts, $_->{start} if $_->{start};
    push @stops, $_->{stop} if $_->{stop};
  }
  if ( $#starts >= 1 ) {
    @starts = sort { $a <=> $b } @starts;
    @starts = map { $starts[$_+1] - $starts[$_] } 0..($#starts-1);
  } else {
    @starts = ();
  }
  if ( $#stops >= 1 ) {
    @stops = sort { $a <=> $b } @stops;
    @stops = map { $stops[$_+1] - $stops[$_] } 0..($#stops-1);
  } else {
    @stops = ();
  }
  #x 'durations', \@durs;
  #x 'starts', \@starts;
  #x 'stops', \@stops;
  return (
    averageduration => average(@durs),
    medianduration => median(@durs),
    averagestartrate => average(@starts),
    medianstartrate => median(@starts),
    averagestoprate => average(@stops),
    medianstoprate => median(@stops),
  );
}

method clear_averages {
  delete $self->{q_avg};
}

# Calculate averages for all queues. Cache the results.
# Use averages of other queues, if queue does not have own.
#
method build_averages {

  return if $self->{q_avg};
  # Collect for all queues
  for my $queuename ( $self->queue_list ) {
    $self->{q_avg}{$queuename} = { averages( @{ $self->{queue}{$queuename} } ) };
  }
  #x 'Queue average', $self->{q_avg};

  my %S;
  for my $stat ( qw(averageduration medianduration
                    averagestartrate medianstartrate
                    averagestoprate medianstoprate) ) {
    # Calculate averages of averages
    for my $queuename ( $self->queue_list ) {
      push @{ $S{$stat} }, $self->{q_avg}{$queuename}{$stat}
        if $self->{q_avg}{$queuename}{$stat}
    }
    $S{$stat} = average( @{ $S{$stat} } );
    # Use overall average in queues that don't have own average
    for my $queuename ( $self->queue_list ) {
      $self->{q_avg}{$queuename}{$stat} = $S{$stat}
        unless $self->{q_avg}{$queuename}{$stat}
    }
  }
  #x 'Avererage average', \%S;
  #x 'Queue average', $self->{q_avg};
}

# Get the average stats for a queue 
#
method queue_stats ( Str :$queuename? ) {
  $queuename ||= '';
  $self->build_averages();
  return %{ $self->{q_avg}{$queuename} };
}
 

# Find out average duration of item
# XXX:  TODO
#   - Find both average duration of a project and closing rate
#   - If cannot find for current queue, then calculate for all queues, and choose average.
#   - Cache the results.
#
method average_item_duration ( Str :$queuename? ) {
  $queuename ||= '';

  my %avg = $self->queue_stats( queuename => $queuename );
  #x "Averages for $queuename", \%avg;
  return ( $avg{averagestoprate}, $avg{averageduration} );
}

# Find etastart, etastop for one item
# XXX: TODO
#   - Calculate up from all incomplete/pending items
#   - Cache results
method estimated_item_stop ( Str :$queuename? ) {
  $queuename ||= '';

  my @list;
  my($rate,$duration) = $self->average_item_duration( queuename => $queuename );
  my $cursor = time;
  for my $item ( @{ $self->{queue}{$queuename} } ) {
    $item->{etastop} = $item->{stop};
    next if $item->{stop};
    my $completed = $item->{completed} || 0;
    my $remaining = $rate - ( $completed * $rate );
    my $eta = $cursor + $remaining;
    $cursor += $remaining;
    push @list, { item => $item, duration=>$remaining, eta => $eta };
    $item->{etaduration} = $remaining;
    $item->{etastop} = int $eta;
  }
  return @list;
}

# Sort a queue
#  All completed, by stop date
#  All not completed, by position, by how completed, and then by starttime
#  All not started, by position then by starttime
#
method queue_sort ( Str :$queuename? ) {
  $queuename ||= '';

  # Categorize items
  my @finished;
  my @incomplete;
  my @pending;
  for my $item ( @{ $self->{queue}{$queuename} } ) {
    if ( $item->{stop} ) {
      push @finished, $item;
    } elsif ( $item->{completed} ) {
      push @incomplete, $item;
    } else {
      push @pending, $item;
    }
  }

  # Sort finished items
  @finished = sort { ( $a->{stop} || 0+"Infinity" ) <=> ( $b->{stop}|| 0+"Infinity" )  } @finished;

  # Sort incomplete items
  @incomplete = sort {
    ( $a->{position} || 0+"Infinity" ) <=> ( $b->{position} || 0+"Infinity" )   # First position first
    ||
    ( $b->{completed} || 0 ) <=> ( $a->{completed} || 0 ) # Most completed first
    ||
    ( $a->{start} || 0+"Infinity" ) <=> ( $b->{start} || 0+"Infinity" )         # Oldest first
  } @incomplete;

  # Sort pending items
  @pending = sort {
    ( $a->{position} || 0+"Infinity" ) <=> ( $b->{position} || 0+"Infinity" )   # First position first
    ||
    ( $a->{start} || 0+"Infinity" ) <=> ( $b->{start} || 0+"Infinity" )         # Oldest first
  } @pending;

  # Rearrange the queue
  my $position = 1;
  @{ $self->{queue}{$queuename} } =
    map { $_->{position} = $position++; $_ }
    @finished, @incomplete, @pending;

  $self->clear_averages();
}


########################################################################
### Move Item Within Queue
########################################################################

# Move an item to different position in queue
# 
method move_first ( HashRef :$item ) {
  $self->item_remove( item => $item );
  my $queuename = $item->{queuename} || '';
  unshift @{ $self->{queue}{$queuename} }, $item;
}

method move_last ( HashRef :$item ) {
  $self->item_remove( item => $item );
  my $queuename = $item->{queuename} || '';
  push @{ $self->{queue}{$queuename} }, $item;
}

method move_before ( HashRef :$item, HashRef :$before ) {
  $self->item_remove( item => $item );
  my $queuename = $item->{queuename} || '';
  # Scan for position of $before
  my $list = $self->{queue}{$queuename};
  for my $i ( 0 .. $#$list ) {
    next unless $list->[$i]{id};
    if ( $list->[$i]{id} eq $before->{id} ) {
      splice @$list, $i, 0, $item;
      return $i;
    }
  }
  push @$list, $before; # Insert at end if cannot find before
  return scalar $#$list;
}

method move_after ( HashRef :$item, HashRef :$after ) {
  $self->item_remove( item => $item );
  my $queuename = $item->{queuename} || '';
  # Scan for position of $after
  my $list = $self->{queue}{$queuename};
  for my $i ( 0 .. $#$list ) {
    next unless $list->[$i]{id};
    if ( $list->[$i]{id} eq $after->{id} ) {
      splice @$list, $i+1, 0, $item;
      return $i+1;
    }
  }
  push @$list, $after; # Insert at end if cannot find before
  return scalar $#$list;
}




no Moose;

__PACKAGE__->meta->make_immutable;

1;
