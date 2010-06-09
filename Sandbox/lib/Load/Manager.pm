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
#   id:          optional, A uniq identifier of the item
#   category:    optional, list of categories this item belongs to
#   start:       optional, start time (since epoch) if item already started
#   stop:        optional, end time (since epoch) if item already completed
#   completed:   optional, how completed (0.0-1.0) if already started
#   duration:    optional, compared to average duration (1.0) how large is item
#   queuename:   optional, if already assigned to a queue
#   queueposition: optional, if already assigned position in queue
#
method item_add ( HashRef :$item ) {
  my $queuename = $item->{queuename} || '';
  push @{ $self->{queue}{$queuename} }, $item;
}

method item_remove ( HashRef :$item ) {
  my $queuename = $item->{queuename} || '';
  if ( my $id = $item->{id} ) {
    for my $i ( 0 .. $#{ $self->{queue}{$queuename} } ) {
      next unless $self->{queue}{$queuename}[$i]{id};
      if ( $self->{queue}{$queuename}[$i]{id} eq $id ) {
        #warn "Removing item $id from position $i\n";
        splice @{ $self->{queue}{$queuename} }, $i, 1;
        return;
      }
    }
  }
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


########################################################################
### ESTIMATES
########################################################################

# Find out average duration of item
#
method average_item_duration ( Str :$queuename? ) {
  $queuename ||= '';

  my($sum,$count);
  for my $item ( @{ $self->{queue}{$queuename} } ) {
    next unless $item->{start} and $item->{stop};
    $sum += ( $item->{stop} - $item->{start} );
    ++$count;
  }
  return undef unless $count;
  return $sum / $count;
}

method estimated_item_stop ( Str :$queuename? ) {
  $queuename ||= '';

  my @list;
  my $duration = $self->average_item_duration( queuename => $queuename );
  my $cursor = time;
  for my $item ( @{ $self->{queue}{$queuename} } ) {
    next if $item->{stop};
    my $completed = $item->{completed} || 0;
    my $remaining = $duration - ( $completed * $duration );
    my $eta = $cursor + $remaining;
    $cursor += $remaining;
    push @list, { item => $item, duration=>$remaining, eta => $eta };
  }
  return @list;
}


########################################################################
### QUEUES
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
