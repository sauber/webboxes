package Sandbox::Controller::Ajax;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sandbox::Controller::Ajax - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

#sub index :Path :Args(0) {
#    my ( $self, $c ) = @_;
#
#    $c->response->body('Matched Sandbox::Controller::Ajax in Ajax.');
#}

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->detach( $c->view("TT") );
}

my @fake_model =
    (
      "OH HAI, I CAN HAZ AJAKS?",
      "I haz a buckit.",
      "They be stealin' my bucket!",
      "I can has cheezburger?",
      "IZ LOLCATALIST!",
      "<a href='http://docs.jquery.com/Ajax'>docs.jquery.com/Ajax</a>",
      "You better getz <a href='http://getfirebug.com/'>BUGZEZ ON FIRE</a>",
      "Ashly rulz!",
     );

sub ajax :Local {
    my ( $self, $c ) = @_;
    my $quote = $fake_model[rand @fake_model];
    $c->stash(quote => $quote);
    $c->detach( $c->view("JSON") );
}


=head1 AUTHOR

Soren Dossing

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
