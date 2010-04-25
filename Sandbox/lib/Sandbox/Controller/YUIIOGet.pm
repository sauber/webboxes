package Sandbox::Controller::YuiIoGet;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sandbox::Controller::YuiIoGet - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  #$c->response->body('Matched Sandbox::Controller::YuiIoGet in YuiIoGet.');
  $c->detach( $c->view("TT") );
}

=head2 assets

=cut

sub assets :Local :Args(1) {
  my ( $self, $c ) = @_;
  $c->response->body('Matched Sandbox::Controller::YuiIoGet::assets in YuiIoGet.');
}


=head1 AUTHOR

Soren Dossing

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
