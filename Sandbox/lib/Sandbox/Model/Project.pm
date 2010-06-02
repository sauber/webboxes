package Sandbox::Model::Project;
use Moose;
use YAML::Syck;
use Sort::Maker;
use MooseX::Method::Signatures;
BEGIN { extends 'Catalyst::Model::MongoDB' };


########################################################################
### Database Connection
########################################################################

has 'listname' => ( isa => 'Str', is => 'rw' );

after 'listname' => sub {
  my ($self) = @_;
  $self->clear_dbname;
  $self->clear_schema;
  $self->clear_items;
  $self->clear_dbh;
};

has 'dbname'   => (
  isa => 'Str',
  is => 'rw',
  lazy_build => 1,
);

sub _build_dbname {
  my ($self) = @_;
  return '_LOT_' . $self->listname;
}

has 'items' => (
  isa => 'MongoDB::Collection',
  is => 'rw',
  lazy_build => 1,
);

sub _build_items {
  my ($self) = @_;
  $self->dbh()->get_collection('items');
}

has 'schema' => (
  isa => 'MongoDB::Collection',
  is => 'rw',
  lazy_build => 1,
);

sub _build_schema {
  my ($self) = @_;
  $self->dbh()->get_collection('config');
}

method project_collections {
  my @list;
  for my $dbn ( grep { s/^_LOT_// } $self->dbnames() ) {
    $self->listname( $dbn );
    # The shortname and the long name
    push @list, { id => $dbn, title => $self->schema->query->next->{name} };
  }
  use Data::Dumper;
  warn Dumper \@list;
  return @list;
}


########################################################################
### Configuration Options
########################################################################

method fieldlist {
  my $config = $self->schema->query->next;
  return () unless ref $config->{fieldlist};
  return @{ $config->{fieldlist} };
}

# A YAML formatter string of field definitions
#
method field_definition {
  Dump [ $self->fieldlist ] || '';
}

# Generate list of visible summary fields in a list
#
method summaryfields {
  return
    map $_->{field},
    grep { $_->{showsummary} or $_->{editsummary} }
    $self->fieldlist;
}

# Find out the type of a particular named field
#
method fieldtype ( Str :$field ) {
  return (
    map { $_->{type} || 'text' }
    grep { $_->{field} eq $field }
    $self->fieldlist
  )[0];
}


# All field names of a list
#
method allfields {
  return map $_->{field}, $self->fieldlist;
}

# Put in new definition, or update existing
#
method saveconfig( Str :$fielddef, Str :$name ) {
  # Parse the YAML formatted string
  my $fieldlist = Load $fielddef;
  return undef unless length $fieldlist;

  # Delete old config (if any)
  $self->schema->drop;
  # Insert new config
  $self->schema->insert({
    name => $name,
    fieldlist => [ @$fieldlist ],
  });
}

# Delete a Project Collection
#
method collection_delete ( Str :$listname ) {
  $self->dbh->drop;
}



########################################################################
### Operations on whole lists
########################################################################

# Get a summary of all items
#
method list_summary(
  Str :$searchq?,
  Str :$groupby?,
  Str :$orderby?,
  Str :$filterby?
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
  warn "*** There are " . scalar(@list) . " items in summary ***\n";
  $groupby ||= 'Title';
  $orderby ||= 'Engineer';
  return [
    [ @fieldlist, qw(Delete Index Groupby Orderby Filterby) ],
    @{
      $self->sortsummary( groupby => $groupby, orderby => $orderby, list => \@list)
    }
  ];
}

# Sort a list first by groupby and then by sortby
#
method sortsummary( Str :$groupby?, Str :$orderby?, ArrayRef :$list )  {
  # Identify the type of field used for sorted
  my $groupfieldtype = $self->fieldtype( field => $groupby);
  my $orderfieldtype = $self->fieldtype( field => $orderby);

  # Identify if should sort by string or number
  my $groupsorttypename = $groupfieldtype . "_sorttype";
  my $ordersorttypename = $orderfieldtype . "_sorttype";
  my $grouptypesubref = \&$groupsorttypename ;
  my $ordertypesubref = \&$ordersorttypename ;
  my $groupsorttype = &$grouptypesubref();
  my $ordersorttype = &$ordertypesubref();

  # Make a reference to the sub that produces a value for the type of field
  my $groupsortcodename = $groupfieldtype . "_sortcode";
  my $ordersortcodename = $orderfieldtype . "_sortcode";
  my $groupsortsubref = \&$groupsortcodename;
  my $ordersortsubref = \&$ordersortcodename;

  # Create sorting code
  my $sorter = make_sorter(
    qw( orcish ),
    'closure',
    #init_code => 'warn "make_sorter:";',
    # First by group
    $groupsorttype => {
      code => sub { &$groupsortsubref($_->[-3], $_) }
    },
    # Then by order
    $ordersorttype => {
      code => sub { &$ordersortsubref($_->[-2], $_) }
    },
  );

  # Do the sorting, and return ordered list
  return [ $sorter->(@$list) ];
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
### Sorting according to field type
########################################################################

sub text_sorttype { 'string' }
sub text_sortcode { shift }

sub textarea_sorttype { 'string' }
sub textarea_sortcode { shift }

sub select_sorttype { 'string' }
sub select_sortcode { shift }

sub journal_sorttype { 'number' }
sub journal_sortcode {
  my $_value = shift;
  # The timestamp of last entry
  my $timestamp;
  if ( ref $_value eq 'ARRAY' ) {
    $_value->[-1] =~ /^(\d+)/ and $timestamp = $1;
  } else {
    $_value =~ /^(\d+)/ and $timestamp = $1;
  }
  return $timestamp;
}

sub activity_sorttype { 'number' } 
sub activity_sortcode {
  my $_logdata = shift;
  my $level = 0;
  $level -= exp(-(((time()-($_->{time}))/86400)**2)/100) for @$_logdata;
  return $level;
}

sub cycle_sorttype { 'number' }
sub cycle_sortcode { shift || 5 }


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







no Moose;
__PACKAGE__->meta->make_immutable;
1;
