#!/usr/bin/env perl

package ListOfThings::Project;

use Moose;
use Getopt::Long;
use MooseX::Method::Signatures;
BEGIN { extends 'ListOfThings' }


########################################################################
### Settings and cache
########################################################################

# How old a list can be without activity before deleting
#has 'collection' => (is => 'rw', isa => 'Str');
#has 'database'   => (is => 'rw', isa => 'Ref');
#has 'username'   => (is => 'rw', isa => 'Str', default => getlogin() );
#has 'listname'   => (is => 'rw', isa => 'Str');
#has 'itemhx'     => (is => 'rw', isa => 'Ref');
#has 'confighx'   => (is => 'rw', isa => 'Ref');


########################################################################
### Managing List of Projects
########################################################################

# Get names of available lists
#
method project_collections {
  $self->LOT_names;
}


########################################################################
### Run library as command line
########################################################################

sub usage {
  <<EOF;
Usage: $0 -collection <collectionname> [<args>]

View list of things
  # Summary, complete list
  -summary
  -expanded
  # Grouping, ordering, filtering
  -groupby <fieldname>
  -orderby <fieldname>
  -filterby <fieldname=value>
  # View single item, update values
  -item <indexvalue>
  -item <indexvalue> -set <fieldname=value>

Examples:
  -collection
  -collection TeamProjects -summary
  -collection TeamProjects -groupby country

EOF
}

sub run {
  my($test);
  my($collection);
  my($eta);
  my($summary,$expanded,$item,%set);
  my($groupby,$orderby,$filterby,$searchq);

  GetOptions(
    "test"         => \$test,
    "eta"          => \$eta,
    "collection:s" => \$collection,
    "summary"      => \$summary,
    "expanded"     => \$expanded,
    "groupby=s"    => \$groupby,
    "orderby=s"    => \$orderby,
    "filterby=s"   => \$filterby,
    "searchq=s"    => \$searchq,
    "item=s"       => \$item,
    "set=s{,}"     => \%set,
  );

  #return print configexample if $test;
  return print usage() unless defined $collection;
  return print __PACKAGE__->textlist( __PACKAGE__->LOT_names() ) unless $collection =~ /./;

  my $L = __PACKAGE__->(listname=>$collection);

  # Test something
  return print $L->texteta() if $test;
  return print $L->texteta() if $eta;

  my %options;
  $options{groupby}  = $groupby  if $groupby;
  $options{orderby}  = $orderby  if $orderby;
  $options{filterby} = $filterby if $filterby;
  $options{searchq}  = $searchq  if $searchq;
  # Default to summary if no other option is given
  #return print textsummary listsummary($list,%options) if $summary;
  #return print textexpanded listexpanded($list,%options) if $expanded;
  #return itemsave( $list, $item, %set ) if %set;
  return print textsummary( $L->list_summary(%options) ) if $summary;
  return print textexpanded( $L->listexpanded(%options) ) if $expanded;
  return $L->itemsave( $item, %set ) if %set;

}


########################################################################
### End of Package. UnMoose back to normal perl.
########################################################################

__PACKAGE__->run() unless caller;
no Moose;
__PACKAGE__->meta->make_immutable;
1;

