package Sandbox::Controller::Project;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sandbox::Controller::Project - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;

  #$c->response->body('Matched Sandbox::Controller::Project in Project.');
  $c->forward('list');
}

sub base :Chained('/') :PathPart('project') :CaptureArgs(0) {
  my ($self, $c) = @_;
  # Print a message to the debug log
  $c->log->debug("*** INSIDE BASE METHOD ***");
}

sub create :Chained('base') :PathPart('create') :Args(0) {
  my ($self, $c) = @_;

  $c->stash(
    projname => '<New Project>',
    template => 'project/update.tt',
  );
  $c->detach( $c->view("TT") );
}

sub read :Chained('base') :PathPart('read') :Args(1) {
  my ($self, $c, $listname) = @_;
  $c->model('Project')->listname( $listname );
  my ($fieldlist, $data ) = $c->model('Project')->list_summary();
  $c->stash(
    template  => 'project/summary.tt',
    title     => $listname,
    listname  => $listname,
    list      => $data,
    fieldlist => $fieldlist,
  );
  $c->detach( $c->view("TT") );
}

sub update :Chained('base') :PathPart('update') :Args(1) {
  my ($self, $c, $listname) = @_;

  $c->log->debug("*** read $listname ***");
  $c->model('Project')->listname( $listname );
  $c->stash(
    projname => $listname,
    fielddef => $c->model('Project')->field_definition(),
  );
  $c->detach( $c->view("TT") );
}

sub update_do :Chained('base') :PathPart('update_do') :Args(0) {
  my ($self, $c, $listname) = @_;

  my $name     = $c->request->params->{projname};
  my $fielddef = $c->request->params->{fielddef};

  unless ( $listname ) {
    $c->log->debug("*** create new database $listname ***");
    ( $listname = $name ) =~ s/\W+//g;
  }
  $c->model('Project')->listname( $listname );
  my $saved = 
    $c->model('Project')->saveconfig( fielddef => $fielddef, name => $name );
  if ( $saved ) {
    $c->stash->{status_msg} = "Project Definition Saved.";
    $c->log->debug("*** $name saved ***");
    #$c->forward('list');
    $c->stash(
      template => 'project/update.tt',
      projname => $name,
      fielddef => $fielddef,
    );
    $c->response->redirect($c->uri_for($self->action_for('list')));
  } else {
    $c->stash->{status_msg} = "Project Definition Not Saved Due to Errors";
    $c->log->debug("*** $name not saved ***");
    $c->stash(
      template => 'project/update.tt',
      projname => $name,
      fielddef => $fielddef,
    )

  }
  $c->detach( $c->view("TT") );
}

sub delete :Chained('base') :PathPart('delete') :Args(1) {
  my ($self, $c, $listname) = @_;

  $c->model('Project')->listname( $listname );
  $c->model('Project')->collection_delete();
  $c->response->redirect($c->uri_for($self->action_for('list')));
}

# List existing collections
sub list :Local {
  my ($self, $c) = @_;

  $c->stash(
    collections => [ $c->model('Project')->project_collections ]
  );
  $c->stash( template => 'project/list.tt' );
  $c->detach( $c->view("TT") );
}

# Handle ajax calls
sub ajax :Chained('base') :PathPart('ajax') :CaptureArgs(1) {
  my($self, $c, $listname) = @_;

  $c->model('Project')->listname( $listname );
}

sub expand :Chained('ajax') :PathPart('expand') :Args(1) {
  my($self, $c, $item) = @_;
  my $record = $c->model('Project')->item_expanded( item_id => $item);
  $c->stash(
    template   => 'project/itemexpand.tt',
    record     => $record,
    no_wrapper => 1,
  );
  $c->detach( $c->view("TT") );
}

#sub get :Chained('ajax') :PathPart('get') :Args(2) {
#  my($self, $c, $item, $field) = @_;
#  $c->response->body(
#    $c->model('Project')->field_getvalue( item_id => $item, fieldname => $field )
#  );
#}

sub field :Chained('ajax') :PathPart('field') :Args(2) {
  my($self, $c, $item, $field) = @_;

  my $value;
  if ( $value = $c->request->params->{value} ) {
    #$c->log->debug("*** ajax save field $field value $value ***");
    $c->model('Project')->item_update(
      item_id => $item,
      updates => { $field => $value },
    );
  } else {
    $value =
      $c->model('Project')->field_getvalue( item_id => $item, fieldname => $field );
    #$c->log->debug("*** ajax load field $field value $value ***");
  }
  $c->response->body( $value );
  
}


=head1 AUTHOR

Soren Dossing

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
