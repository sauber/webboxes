package Sandbox::Model::Project;
use Moose;
use YAML::Syck;
use Sort::Maker;
use MooseX::Method::Signatures;
BEGIN { extends 'Catalyst::Model::MongoDB' };

sub x {
 use Data::Dumper;
 warn Data::Dumper->Dump([$_[1]], ["*** dump $_[0]"]);
}


########################################################################
### Database Connection
########################################################################

has 'listid' => ( isa => 'Str', is => 'rw', );

before 'listid' => sub {
  my ($self) = @_;
  $self->reset();
};

has 'dbname'   => (
  isa => 'Str',
  is => 'rw',
  lazy_build => 1,
);

sub _build_dbname {
  my ($self) = @_;
  return '_LOT_' . $self->listid;
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

# If listid changes, the unset all db values
method reset {
  $self->clear_dbname;
  $self->clear_schema;
  $self->clear_items;
  $self->clear_dbh;
}

# Get a list of all ListOfThings tables
#
method alllists {
  my @list;
  for my $dbn ( grep { s/^_LOT_// } $self->dbnames() ) {
    next unless $dbn;
    $self->listid( $dbn );
    next unless $self->schema->query->next;
    #warn "*** alllists: dbn=$dbn, self=$self\n";
    # The shortname and the long name
    push @list, {
      listid   => $dbn,
      listname => $self->schema->query->next->{name} || "unknown",
    };
  }
  return @list;
}


########################################################################
### Configuration Options
########################################################################

# Put in new definition, or update existing
#
method saveconfig( Str :$fieldlist, Str :$listname ) {
  # Parse the YAML formatted string
  my $fieldref = Load $fieldlist;
  return undef unless ref $fieldref;

  # Delete old config (if any)
  $self->schema->drop;
  # Insert new config
  $self->schema->insert({
    name => $listname,
    fieldlist => [ @$fieldref ],
  });
}

# Delete a Project Collection
#
method collection_delete ( Str :$listid ) {
  $self->dbh->drop;
}

method config_example {
  return Dump [
    {
       fieldname => 'Title',
    },
    {
       fieldname => 'Description',
       fieldtype => 'textarea',
       size => '40x2',
    },
    {
       fieldname => 'Category',
       fieldtype => 'select',
       choices => [ qw( Low Medium High ) ],
    },
  ];
}



########################################################################
### Field Operations
########################################################################

method fieldlist {
  my $config = $self->schema->query->next;
  return () unless ref $config->{fieldlist};
  return @{ $config->{fieldlist} };
} 

method listname {
  my $config = $self->schema->query->next;
  return unless ref $config->{fieldlist};
  return $config->{name};
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
    #map $_->{field},
    grep { $_->{showsummary} or $_->{editsummary} }
    $self->fieldlist;
}

# Generate list of visible summary fields in a list
#
method expandedfields {
  return
    #map $_->{field},
    grep { $_->{showexpanded} or $_->{editexpanded} }
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

# Decide if a field can be edited or nor
#
method field_canedit ( Str :$field ) {
  for my $f ( $self->fieldlist ) {
    next unless $f->{field} eq $field;
    return 1 if $f->{editsummary} or $f->{editexpanded};
  }
  return undef;
}

# Get all attributes for a named field
#
method field_attributes ( Str :$fieldname ) {
  for my $f ( $self->fieldlist ) {
    return $f if $f->{fieldname} eq $fieldname;
  }
  return {};
}

# All field names of a list
#
method allfields {
  return map $_->{fieldname}, $self->fieldlist;
}

# All fields that can be used for sorting
method orderbyfields {
  return map $_->{fieldname}, grep $_->{orderby}, $self->fieldlist;
}

# All fields that can be used for grouping
method groupbyfields {
  return map $_->{fieldname}, grep $_->{groupby}, $self->fieldlist;
}

method filterbyfields {
  my @fieldlist = map $_->{fieldname}, grep $_->{filterby}, $self->fieldlist;
  my @filters;
  for my $field ( @fieldlist ) {
    for my $value ( $self->fieldvalues( fieldname => $field ) ) {
      push @filters, { fieldname => $field, value => $value };
    }
  }
  return @filters;
}

# All values for a given field
#
method _old_fieldvalues ( Str :$fieldname ) {
  my %values;
  my $result = $self->items->query({});
  while ( my $item = $result->next ) {
    ++$values{$item->{$fieldname}} if $item->{$fieldname};
  }
  return sort keys %values;
}

# using mapreduce - woohoo!
#
method fieldvalues ( Str :$fieldname ) {
  my $m = "function() { emit(this.$fieldname, 1); }";
  my $r = 'function(k,vals) { return 1; }';
  my $cmd = Tie::IxHash->new("mapreduce" => "items", "map" => $m, "reduce" => $r, out => "distinct_$fieldname");
  my $result = $self->dbh->run_command($cmd);
  my @values = map $_->{_id}, 
    $self->dbh()->get_collection("distinct_$fieldname")->query->all;
  return @values;
}



########################################################################
### Operations on whole lists
########################################################################

# Get a summary of all items
#
method list_summary(
  Str :$searchq?,
  Str :$deleteq?,
  Str :$groupby?,
  Str :$orderby?,
  Str :$filterfield?,
  Str :$filtervalue?
) {
  # Get a list of summary fields from config
  my @fieldlist = $self->summaryfields();
  #my %attr = map { $_ => $self->field_attributes( fieldname => $_) } @fieldlist;
  my %list;

  # Read all summary fields from all items
  # Append the fields qw(Delete Index Groupby Orderby Filterby) ];
  # Only keep matching fields
  # First line is field names

  my $filter = {};
  $filter = { $filterfield => $filtervalue } if $filterfield and $filtervalue;
  my $allitems = $self->items->query( $filter );

  warn sprintf "*** list_summary: searchq = %s ***\n",     ($searchq     || '');
  warn sprintf "*** list_summary: deleteq = %s ***\n",     ($deleteq     || '');
  warn sprintf "*** list_summary: orderby = %s ***\n",     ($orderby     || '');
  warn sprintf "*** list_summary: groupby = %s ***\n",     ($groupby     || '');
  warn sprintf "*** list_summary: filterfield = %s ***\n", ($filterfield || '');
  warn sprintf "*** list_summary: filtervalue = %s ***\n", ($filtervalue || '');

  while ( my $r = $allitems->next ) {
    next unless $self->item_match( item=>$r, keyword=>$searchq );
    next if not $deleteq and $r->{_deleted};
    my $groupname = ( $groupby and $r->{$groupby} ) ? $r->{$groupby} : '';
    push @{ $list{$groupname} }, {
      itemid => $r->{_id}{value},
      _deleted => $r->{_deleted},
      map { $_->{fieldname} => $r->{$_->{fieldname}} } @fieldlist
    };
  }
  #warn "*** There are " . scalar(@list) . " items in summary ***\n";
  $orderby ||= 'Title';

  # Sort the groups depending on name of group
  # Sort each of the lists in each group depending on orderby field
  # XXX: Should sort the group by number where applicable
  # XXX: Sorting doesn't actually work at the moment
  #return  (
  #  [ @fieldlist, qw(Delete Index Groupby Orderby Filterby) ],
  #  [ map {{
  #      groupname => $_,
  #      items     => $self->sortsummary( orderby=>$orderby, list=>$list{$_} ),
  #    }}
  #  sort keys %list ]
  #);
  return \%list;
}

# Sort a list first by groupby and then by sortby
#
method sortsummary( Str :$orderby?, ArrayRef :$list )  {
  # Identify the type of field used for sorted
  my $orderfieldtype = $self->fieldtype( field => $orderby);

  # Identify if should sort by string or number
  my $ordersorttypename = $orderfieldtype . "_sorttype";
  my $ordertypesubref = \&$ordersorttypename ;
  my $ordersorttype = &$ordertypesubref();

  # Make a reference to the sub that produces a value for the type of field
  my $ordersortcodename = $orderfieldtype . "_sortcode";
  my $ordersortsubref = \&$ordersortcodename;

  # Create sorting code
  my $sorter = make_sorter(
    qw( orcish ),
    'closure',
    #init_code => 'warn "make_sorter:";',
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
method item_read( Str :$itemid ) {
  #my $objid = MongoDB::OID->new($itemid);
  my $objid = $self->oid($itemid);
  my $matches = $self->items->query({ _id => $objid });
  return $matches->next;
}

# Write a new record into database
#
method item_create( HashRef :$item ) {
  #use Data::Dumper;
  #warn "*** item_create: item = " . Dumper($item) . " ***\n";
  my %insert;
  for my $field ( $self->fieldlist ) {
    my $fieldname = $field->{fieldname};
    #warn "*** item_create: fieldname = $fieldname ***\n";
    my $fieldtype = $field->{type};
    #warn "*** item_create: fieldtype = $fieldtype ***\n";
    next unless my $value = $item->{$fieldname};
    #warn "*** item_create: value = $value ***\n";

    ## Identify type of field
    #my $typefuncname = $fieldtype . "_datatype";
    #my $datatypesubref = \&$typefuncname ;
    #my $datatype = &$datatypesubref();
    #next unless $datatype eq 'scalar' or $datatype eq 'array';
    ##warn "*** item_create: datatype = $datatype ***\n";

    ## scalar<->array conversion if required
    #$value = pop @$value if $datatype eq 'scalar' and     ref $value;
    #$value = [ $value ]  if $datatype eq 'array'  and not ref $value;
    ##warn "*** item_create: value converted = $value ***\n";

    $value = $self->valueconvert( fieldtype => $fieldtype, value => $value );
    next unless $value;

    $insert{$fieldname} = $value;
  }
  #use Data::Dumper;
  #warn "*** item_create: insert = " . Dumper(\%insert) . " ***\n";
  x "item_create: insert", \%insert;
  # Returns the oid
  $self->items->insert(\%insert)->{value};
}

# Update one or more fields for an item
#
method item_update( Str :$itemid, HashRef :$updates ){
  my $objid = $self->oid($itemid);
  my $matches = 0;
  while ( my ($key,$value) = each %$updates ) {
    warn "*** item_update $objid set $key = $value ***\n";
    if ( ref $value ) {
      $matches += $self->items->update(
        { _id => $objid }, { '$push', { $key => shift @$value } }
      );
    } elsif ( $value ) {
      $matches += $self->items->update(
        { _id => $objid }, { '$set', { $key => $value } }
      );
    } else {
      $matches += $self->items->update(
        { _id => $objid }, { '$unset', { $key => 1 } }
      );
    }
  }
  return $matches;
}

#method item_delete( Str :$itemid ) {
#}
#method item_undelete( Str :$itemid ) {
#}


########################################################################
### Operations on a single Item
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

method item_expanded( Str :$itemid ) {
  my $item = $self->item_read( itemid => $itemid );
  my @fieldlist = $self->expandedfields();
  my @list;
  for my $fieldname ( @fieldlist ) {
    #push @list, {
    #  fieldname => $fieldname,
    #  fieldtype => $self->fieldtype( field => $fieldname),
    #  value     => $item->{$fieldname},
    #  canedit   => $self->field_canedit( field => $fieldname),
    #}
    push @list, $self->field_get( item => $item, fieldname => $fieldname );
  }
  return \@list;
}

# Get all values and all field attributes for a record
#
method item_get ( Str :$itemid ) {
  $self->item_read( itemid => $itemid );
}

# Update an item, overwrite/append/delete fields
#
method item_set ( Str :$itemid, HashRef :$item ) {
  my %fieldlist = ( map { $_->{fieldname} => $_ } $self->fieldlist );
  my %update;
  for my $fieldname ( keys %$item ) {
    next unless $fieldlist{$fieldname};
    my $fieldtype = $fieldlist{$fieldname}{type};
    my $value = $item->{$fieldname};
    $value = $self->valueconvert( fieldtype => $fieldtype, value => $value );
    $update{$fieldname} = $value;
  }
  x "item_set: update", \%update;
  $self->item_update( itemid => $itemid, updates => \%update );
}

# Find start and stop time for an item
#
method itemstartstop ( HashRef :$item ) {
  my %T;
  my $log = $item->{auditlog};
  my $sec;
  for my $entry ( @$log ) {
    $sec = $entry->{time};
    # Start/stop time
    $T{defined} ||= $sec;
    if ( $entry->{message} =~ /State \w+ to: (\S+)/ ) {
      my $status = $1;
      $T{init}      = $sec, next if $status eq 'Initiation';
      $T{closed}    = $sec, next if $status eq 'Closed';
      $T{canceled}  = $sec, next if $status eq 'Canceled';
      # Unclose/uncancel in case project is ongoing again.
      delete $T{closed};
      delete $T{canceled};
      # Anything else than Init/Close/Cancel means project is going on
      $T{started} ||= $sec;
    }
  }
  $T{started} ||= ( $T{init}   || $T{closed}   );
  $T{stopped} ||= ( $T{closed} || $T{canceled} );

  # There are cases of items being deleted without properly stoped.
  # This is same as canceled.
  $T{canceled} = $sec if $item->{_deleted} and not $T{stopped};

  return (
    $T{started},
    $T{stopped},
    $T{canceled},
  );
}


########################################################################
### Operations on a single field
########################################################################

method field_get( Str :$fieldname ) {
  #return {
  #  fieldname => $fieldname,
  #  value     => $item->{$fieldname},
  #  %{ $self->field_attributes( field => $fieldname ) },
  #};
  for my $f ( $self->{fieldlist} ) {
    return $f if $f->{fieldname} eq $fieldname;
  }
  return undef;
}

method field_getvalue ( Str :$itemid, Str :$fieldname ) {
  my $item = $self->item_read( itemid => $itemid );
  return $item->{$fieldname};
}


########################################################################
### Operations on a single value
########################################################################

# Convert value to correct type: undef, scalar or array
#
method valueconvert ( Any :$fieldtype, Any :$value ) {
  $fieldtype ||= 'text';
  # Identify type of field
  my $typefuncname = $fieldtype . "_datatype";
  my $datatypesubref = \&$typefuncname ;
  my $datatype = &$datatypesubref();
  return undef unless $datatype eq 'scalar' or $datatype eq 'array';
  #warn "*** item_create: datatype = $datatype ***\n";

  # scalar<->array conversion if required
  $value = pop @$value if $datatype eq 'scalar' and     ref $value;
  $value = [ $value ]  if $datatype eq 'array'  and not ref $value;
  #warn "*** item_create: value converted = $value ***\n";

  return $value;
}


########################################################################
### Sorting according to field type
########################################################################

sub text_datatype { 'scalar' }
sub text_sorttype { 'string' }
sub text_sortcode { shift }

sub textarea_datatype { 'scalar' }
sub textarea_sorttype { 'string' }
sub textarea_sortcode { shift }

sub select_datatype { 'scalar' }
sub select_sorttype { 'string' }
sub select_sortcode { shift }

sub journal_datatype { 'array' }
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

sub activity_datatype { 'none' } 
sub activity_sorttype { 'number' } 
sub activity_sortcode {
  my $_logdata = shift;
  my $level = 0;
  $level -= exp(-(((time()-($_->{time}))/86400)**2)/100) for @$_logdata;
  return $level;
}

sub cycle_datatype { 'scalar' }
sub cycle_sorttype { 'number' }
sub cycle_sortcode { shift || 5 }



########################################################################
### Project Items
########################################################################

# Generate items that are suitable as Load::Manager objects
#
method loadmanager_items ( Str :$category? ) {
  # Identify which fields to use for load manager
  my %F;
  for my $field ( $self->fieldlist() ) {
    for my $l ( qw(label color queuename position completed) ) {
      ++$F{$l}{$field->{fieldname}}
        if defined $field->{loadmanager} and $field->{loadmanager} eq $l;
    } 
  } 

  my $items = $self->items->query();
  my @jobs;
  while ( my $item = $items->next ) {
    my($start,$stop,$cancel) = $self->itemstartstop( item => $item );
    next if $cancel;

    my $completed;
    unless ( $stop ) {
      ($completed) = map { $_/100 }
                     grep s/^.*?(\d+)\%.*/$1/,
                     grep { defined $_ }
                     map $item->{$_},
                     keys %{$F{completed}};
    }

    # Find queuename  # Find queueposition
    my $name;
    if ( $category ) {
      $name = $self->loadmanager_items_by( category=>$category, item=> $item );
    } else {
      $name = join ', ', grep { defined $_ } map $item->{$_}, keys %{$F{queuename}};
    }

    # Find queueposition
    my($position) = grep { defined $_ } map $item->{$_}, keys %{$F{position}};

    # Find label
    # Find color
    my $label = join ', ', grep { defined $_ } map $item->{$_}, keys %{$F{label}};
    my $color = join ', ', grep { defined $_ } map $item->{$_}, keys %{$F{color}};

    # Find id
    my $id = $item->{_id}{value};

    push @jobs, {
      id => $id,
      label => $label,
      start => $start,
      stop => $stop,
      completed => $completed,
      queuename => $name,
      position => $name,
      color => $color,
    };
  }
  return @jobs;
}

method loadmanager_items_by ( Str :$category, Ref :$item )  {
  my $name = 'Other';
  if ( $category eq 'country' ) {
    $name = 'India' if $item->{Title} =~ /\bIN\b/;
    $name = 'Japan' if $item->{Title} =~ /\bJP\b/;
    $name = 'Hong Kong' if $item->{Title} =~ /\bHK\b/;
    $name = 'Singapore' if $item->{Title} =~ /\bSG\b/;
  }
  return $name;
}

########################################################################
### Change Log
########################################################################

# Add an audit log item to an item
#
method logging( Str :$message, Str :$itemid ) {
  my $objid = MongoDB::OID->new($itemid);

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
