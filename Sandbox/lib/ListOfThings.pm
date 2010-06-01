#!/usr/bin/env perl

package ListOfThings;

use Moose;
use Getopt::Long;
use Data::Dumper; # XXX: Debug
use Text::Table;
use Date::Format;
use YAML::Syck;
use MooseX::Method::Signatures;
use MongoDB;


########################################################################
### Settings and cache
########################################################################

# How old a list can be without activity before deleting
has 'collection' => (is => 'rw', isa => 'Str');
has 'database'   => (is => 'rw', isa => 'Ref');
has 'username'   => (is => 'rw', isa => 'Str', default => getlogin() );
has 'listname'   => (is => 'rw', isa => 'Str');
has 'itemhx'     => (is => 'rw', isa => 'Ref');
has 'confighx'   => (is => 'rw', isa => 'Ref');


########################################################################
### Database Handler
########################################################################

# Connection to datatabase
#
method connection {
  unless ( $self->database ) {
    $self->database( MongoDB::Connection->new );
  }
  $self->database;
}

# Handler of items
#
method items {
  unless ( $self->itemhx ) {
    my $db = $self->connection()->get_database( '_LOT_' . $self->listname );
    $self->itemhx( $db->get_collection('items') );
  }
  $self->itemhx;
}

# Handler of configs
#
method configs {
  unless ( $self->confighx ) {
    my $db = $self->connection()->get_database( '_LOT_' . $self->listname );
    $self->confighx( $db->get_collection('config') );
  }
  $self->confighx;
}


########################################################################
### Managing List of Lists
########################################################################

# Get names of available lists
#
sub LOT_names {
  grep { s/^_LOT_// }
  MongoDB::Connection->new->database_names();
}


########################################################################
### Configuration Options
########################################################################

method fieldlist {
  my $config = $self->configs->query->next;
  return @{ $config->{fieldlist} };
}

# Generate list of visible summary fields in a list
#
method summaryfields {
  return
    map $_->{field},
    grep { $_->{showsummary} or $_->{editsummary} }
    $self->fieldlist;
}

# Generate list of visible fields for expanded view
#
method expandedfields {
  return
    map $_->{field},
    grep { $_->{showexpanded} or $_->{editexpanded} }
    $self->fieldlist;
}

# All field names of a list
#
method allfields {
  return map $_->{field}, $self->fieldlist;
}


########################################################################
### Operations on whole lists
########################################################################

# Get a summary of all items. Include all the option fields.
#
method list_summary(
  Str :$groupby,
  Str :$orderby,
  Str :$filterby,
  Str :$searchq
) {
  # Get a list of summary fields from config
  my @fieldlist = $self->summaryfields();
  my @list = [ @fieldlist, qw(Delete Index Groupby Orderby Filterby) ];

  # Read all summary fields from all items
  # Append the fields qw(Delete Index Groupby Orderby Filterby) ];
  # Only keep matching fields
  # First line is field names

  my $allitems = $self->items->query;
  while ( my $r = $allitems->next ) {
    next unless $self->item_match( item=>$r, keyword=>$searchq );

    push @list, [
      $self->item_selectfields( item=>$r, fieldlist=>\@fieldlist),
      $r->{_deleted},
      $r->{_id}{value},
      ( $groupby  ? $r->{$groupby} : undef ),
      ( $orderby  ? $r->{$orderby} : undef ),
      ( $filterby ? $r->{filterby} : undef ),

    ];
  }
  return \@list;
}

# Get the summary and expanded information of all items.
#
method list_expanded (
  Str :$searchq
) {
  my @fieldlist = ( $self->summaryfields, $self->expandedfields );
  my @list;

  my $allitems = $self->items->query;
  while ( my $r = $allitems->next ) {
    next unless $self->item_match( item=>$r, keyword=>$searchq );
    my @table = [ 'Index', $r->{_id}{value} ];
    for my $f ( @fieldlist ) {
      push @table, [ $f, $r->{$f} ];
    }
    push @list, \@table;
  }
  return \@list;
}



########################################################################
### Item I/O
########################################################################

# Read a single item
#
method item_read( Str :$item_id ) {
  my $objid = MongoDB::OID->new($item_id);
  my $matches = $self->items->query({ _id => $objid });
  return $matches->next;
}

method item_save( Str :$item_id, HashRef :$item ) {
  my $objid = MongoDB::OID->new($item_id);
  $self->items->update();
}
method item_delete( Str :$item_id ) {
}
method item_undelete( Str :$item_id ) {
}



########################################################################
### Operations on a single read Item
########################################################################

# Check if a keyword appears in any of the fields of an item
# XXX: Only checks scalars
#
method item_match( HashRef :$item, Any :$keyword? ) {
#method item_match( $item, $keyword? ) {
  return 1 unless $keyword;
  for my $field ( $self->allfields ) {
    next unless $item->{$field};
    return 1 if $item->{$field} =~ /$keyword/i;
  }
  return undef;
}

method item_selectfields( HashRef :$item, ArrayRef :$fieldlist ) {
  return map $item->{$_}, @$fieldlist;
}


########################################################################
### Change Log
########################################################################

# Add an audit log item to an item
#
method logging( Str :$message, Str :$item_id ) {
  my $objid = MongoDB::OID->new($item_id);

  my $logentry = {
    time    => time(),
    message => $message,
    user    => $self->username(),
  };

  $self->items->update(
    { '_id'    => $objid                      },
    { '$push'  => { 'auditlog' => $logentry } },
    { 'upsert' => 1                           },
  );
}

########################################################################
### FORMATTING
########################################################################

# Render a pretty summary text table
# Use first row for headers
# Skip last three columns; Index, Groupby, Orderby
# XXX: Respect Groupby, Orderby
# Using pop three times is excessive
#
sub textsummary {
  my $data = shift;

  #my $tb = Text::Table->new( @{ $data->[0] });
  #$tb->load( map $data->[$_], 1 .. $#$data );
  my @header = @{ $data->[0] };
  pop @header; pop @header; pop @header;
  my $tb = Text::Table->new( @header );
  for my $n ( 1 .. $#$data ) {
    #my @row = @{ $data->[$n] }; shift @row;
    my @row = @{ $data->[$n] };
    pop @row; pop @row; pop @row;
    $tb->add( @row );
  }
  return scalar($tb->title())
       . scalar($tb->rule('-'))
       . scalar($tb->body());
}

# Show a simple list of items
#
sub textlist {
  #warn "textlist: " . Dumper \@_;
  return join '', map  "$_\n", @_;
}

# Render expanded view
#
sub textexpanded {
  my $data = shift;

  my $output = '';
  for my $item ( @$data ) {
    my $tb = Text::Table->new( qw(Field Value) );
    $tb->load( @$item[ 1 .. $#$item ] );
    $output
       .= scalar($tb->title())
       .  scalar($tb->rule('-'))
       .  scalar($tb->body())
       .  scalar($tb->rule('-'))
       .  "\n";
      

  }
  return $output;
}

# Display eta for projects
sub texteta {
  my $self = shift;

  $self->listcompletion();
  for my $index ( 
    sort { $self->{eta}{$a}{eta} <=> $self->{eta}{$b}{eta} }
    grep $self->{eta}{$_}{eta},
    keys %{ $self->{eta} }
  ) {
    print prettytime($self->{eta}{$index}{eta}) . "\t$index\n";
  }
}



########################################################################
### Run library as command line
########################################################################

sub usage {
  <<EOF;
Usage: $0 -list <listname> [<args>]

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
  -list
  -list Projects -summary
  -list Projects -groupby country

EOF
}

sub run {
  my($test);
  my($list);
  my($eta);
  my($summary,$expanded,$item,%set);
  my($groupby,$orderby,$filterby,$searchq);

  GetOptions(
    "test"       => \$test,
    "eta"        => \$eta,
    "list:s"     => \$list,
    "summary"    => \$summary,
    "expanded"   => \$expanded,
    "groupby=s"  => \$groupby,
    "orderby=s"  => \$orderby,
    "filterby=s" => \$filterby,
    "searchq=s"  => \$searchq,
    "item=s"     => \$item,
    "set=s{,}"   => \%set,
  );

  #return print configexample if $test;
  return print usage() unless defined $list;
  return print __PACKAGE__->textlist( __PACKAGE__->LOT_names() ) unless $list =~ /./;

  my $L = new ListOfThings(listname=>$list);

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
  return print textexpanded( $L->list_expanded() ) if $expanded;
  return $L->itemsave( $item, %set ) if %set;

}


########################################################################
### End of Package. UnMoose back to normal perl.
########################################################################

__PACKAGE__->run() unless caller;

no Moose;

__PACKAGE__->meta->make_immutable;

1;

