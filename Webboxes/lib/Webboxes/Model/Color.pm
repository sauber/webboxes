package Webboxes::Model::Color;
use Moose;
use MooseX::Method::Signatures;
BEGIN { extends 'Catalyst::Model::MongoDB' };

# Connect to a MongoDB database. Use collection named colors.
#
method color_collection {
  my $db  = $self->dbh;
  return $db->get_collection('colors');
  #return $db->get_collection('');
}

# Get all documents from collection. For each document only return color.
method colors($query = {}) {
  my @data = $self->color_collection->query($query)->all;
  #use Data::Dumper;
  #warn Dumper $query;
  #warn Dumper \@data;
  return map $_->{color}, @data;
}

method add(Str :$color) {
    $self->color_collection->insert({ color => $color });
}

method remove(Str :$color) {
    $self->color_collection->remove({ color => $color });
}

method remove_all {
    $self->color_collection->drop;
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
