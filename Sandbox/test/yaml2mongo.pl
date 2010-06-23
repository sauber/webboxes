#!/usr/bin/env perl

use strict;
use warnings;
use YAML::Syck;
use Data::Dumper;
use MongoDB;

# Read in data from YAML file
our $yamlfile = 'list-Unix%20Projects.yaml';
our $data     = LoadFile $yamlfile;

# Rename field to fieldname
$_->{fieldname} = $_->{field}, delete $_->{field}
  for @{ $data->{config}{fieldlist} };

# Insert some loadmanager data
for my $f ( @{ $data->{config}{fieldlist} } ) {
  $f->{loadmanager} = 'label'     if $f->{fieldname} eq 'Title';
  $f->{loadmanager} = 'label'     if $f->{fieldname} eq 'PipelineID';
  $f->{loadmanager} = 'queuename' if $f->{fieldname} eq 'Engineer';
  $f->{loadmanager} = 'queuename' if $f->{fieldname} eq 'Atn';
  $f->{loadmanager} = 'completed' if $f->{fieldname} eq 'Status';
  $f->{loadmanager} = 'color'     if $f->{fieldname} eq 'Pipeline';
}
push @{ $data->{config}{fieldlist} },
  {
  fieldname   => 'qpos',
  loadmanager => 'position',
  };

# Dump data found in YAML
#print Dumper $data->{config};
#print Dumper $data->{data};
#print Dumper $data->{log};
#exit;

# Open connection to Mongo DB
our $conn = MongoDB::Connection->new;
our $db   = $conn->get_database("_LOT_UnixProjects");

# Store the config
our $config = $db->get_collection("config");
$config->drop;
$config->insert( $data->{config} );

# Dump config from mongo
my $r = $config->query();
while ( my $doc = $r->next ) {
  print Dumper $doc;
}

# Merge the audit log into each project
my $log = $data->{log};
for my $project ( keys %$log ) {
  if ( $data->{data}{$project} ) {
    $data->{data}{$project}{auditlog} = $log->{$project};

    #print "+";
  } else {

    #print "-";
  }

  #print " $project\n";
}

# Save all projects to mongo
our $projects = $db->get_collection("items");
$projects->drop;
my $proj = $data->{data};
while ( my ( $item, $value ) = each %$proj ) {
  next unless length $item;
  $projects->insert($value);
}

# Dump information found in mongo
my $s = $projects->query();
while ( my $doc = $s->next ) {

  #print Dumper $doc;
}

