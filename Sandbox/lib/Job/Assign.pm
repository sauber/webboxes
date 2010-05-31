package Job::Assign;
use Moose;
use MooseX::Method::Signatures;

# This will take a list of jobs and assign them into queues
# Moving already assign job from queue to another, or shift position
# within the queue will result in new ETA for all affected jobs.

########################################################################
### JOBS
########################################################################

# Add a job definition
#   _id:       A uniq identifier of the job
#   title:     Summary description of the job
#   category:  optional, list of categories this job belongs to
#   start:     optional, start time (since epoch) if job already started
#   stop:      optional, end time (since epoch) if job already completed
#   completed: optional, percentage completed if already started
#   size:      optional, compared to average size (1.0) how large is job
#   queuename: optional, if already assigned to a queue
#   queuepos:  optional, if already assigned position in queue
#
method job_add(
    Str :$_id,
    Str :$summary,
    Int :$start?,
    Int :$stop?,
    Num :$completed?,
    Num :$size?,
    Str :$queuename?,
    Int :$queuepos?,
    ArrayRef :$category?
  ) {
  push @{ $self->{jobs} }, {
    _id       => $_id,
    summary   => $summary,
    start     => $start,
    stop      => $stop,
    completed => $completed,
    size      => $size,
    queuename => $queuename,
    queuepos  => $queuepos,
    category  => $category,
  };
}

# List all jobs
#
method job_list {
  @{ $self->{jobs} };
}


########################################################################
### QUEUES
########################################################################

# Add a new queue
#   name: Name of queue
#
method queue_add (Str :$name) {
  $self->{queue}{$name} = {}
}

method queue_list {
  %{ $self->{queue} };
}

# Add a job to a queue
#
method queue_append ( Str :$queuename, Str :$job_id ) {
  # Find all jobs in this queue
  my @existing = grep { $_->{queuename} eq $queuename }
                 $self->job_list;

  # Make sure job not already in queue
  for my $job ( @ existing ) {
    return if $job->{_id} eq $job_id;
  }

  # Position is largest + 1
  # XXX: Make sure all jobs in queue already has a position.
  my $last = 0;
  for my $job ( @existing ) {
    $last = $job->{queuepos} if $job->{queuepos} > $last;
  }
  $self->{job}{queuename} = $queuename;
  $self->{job}{queuepos} = 1 + $last;
}

#method add(Str :$color) {
#    # XXX: Figure out and add hex code for color automatically
#    $self->color_collection->insert({ name => $color });
#}

#method remove(Str :$color) {
#    $self->color_collection->remove({ name => $color });
#}

#method remove_all {
#    $self->color_collection->drop;
#}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
