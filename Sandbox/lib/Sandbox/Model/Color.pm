package Sandbox::Model::Color;
use Moose;
use MooseX::Method::Signatures;
BEGIN { extends 'Catalyst::Model::MongoDB' };

# Connect to a MongoDB database. Use collection named colors.
#
method color_collection {
  my $db  = $self->dbh;
  return $db->get_collection('colors');
}

# Get all documents from collection. For each document only return color.
method colors($query = {}) {
  my @data = $self->color_collection->query($query)->all;
  return map $_->{name}, @data;
}

method add(Str :$color) {
    # XXX: Figure out and add hex code for color automatically
    $self->color_collection->insert({ name => $color });
}

method remove(Str :$color) {
    $self->color_collection->remove({ name => $color });
}

method remove_all {
    $self->color_collection->drop;
}

no Moose;

__PACKAGE__->meta->make_immutable;

1;
