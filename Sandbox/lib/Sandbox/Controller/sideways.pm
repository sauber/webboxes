package Sandbox::Controller::sideways;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sandbox::Controller::sideways - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  # $c->response->body('Matched Sandbox::Controller::sideways in sideways.');
  #$c->model('Projects')->project_list();
  $c->stash->{projects} = [ $c->model('Projectdemo')->project_list() ];
  $c->stash->{assignment} = [ $c->model('Projectdemo')->assignment() ];
  #use Data::Dumper;
  #warn Dumper $c->stash->{projects};
  #$c->stash->{colors} = [$c->model('Color')->colors()];
  $c->detach( $c->view("TT") );

}


=head1 AUTHOR

Soren Dossing

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
