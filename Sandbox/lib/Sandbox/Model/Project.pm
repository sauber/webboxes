package Sandbox::Model::Project;
use Moose;
use YAML::Syck;
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
  Str :$searchq,
  Str :$groupby,
  Str :$orderby,
  Str :$filterby
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







no Moose;
__PACKAGE__->meta->make_immutable;
1;
