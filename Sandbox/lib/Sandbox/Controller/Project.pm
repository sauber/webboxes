package Sandbox::Controller::Project;
use Moose;
use Text::MultiMarkdown;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

# = Naming =
# == Data structure ==
# Number of lists, identified by listid ( cleaned listid )
#     listid =>
#     listname =>
#     config =>
#     fieldlist => [ field ]
#     items =>
# Number of items, identified by itemid ( mongo oid of record )
#     itemid =>
#     fieldname => value
#     fieldname => value
#     ...
# Fieldlist has number of fields, identified by fieldname (from config)
#     fieldname =>
#     type =>
#     size =>
#     showsummary =>
# == URL parts ==
#   control:    action viewonly append
#   dataitems:  listid itemid fieldname
#   filter:     groupby orderby filterfield filtervalue searchq deleteq
#   fieldvalue: value


=head1 NAME

Sandbox::Controller::Project - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path {
  my ( $self, $c, %param ) = @_;

  #warn "*** index: param = " . Dumper(\%param). " ***\n";;
  $self->linkparse($c,\%param); # Extract valid data from URL
  #$c->log->debug("*** index: linkparse done ***");
  $self->loaddata($c,\%param);  # Load relevant data
  #$c->log->debug("*** index: loaddata done ***");

  #$c->log->debug("*** index: trying field actions ***");
  if ( $c->stash->{fieldname} ) {
    $self->field_actions($c,\%param);
    $c->detach( $c->view("TT") );
  }

  #$c->log->debug("*** index: trying item actions ***");
  if ( $c->stash->{itemid} ) {
    $self->item_actions($c,\%param);
    $c->detach( $c->view("TT") );
  }

  #$c->log->debug("*** index: trying list actions ***");
  if ( $c->stash->{listid} ) {
    $self->list_actions($c,\%param);
    $c->detach( $c->view("TT") );
  }

  #$c->log->debug("*** index: trying global actions ***");
  $self->global_actions($c,\%param);
  $c->detach( $c->view("TT") );
}

# Parse URL link
#
sub linkparse {
  my($self,$c,$param) = @_;

  #use Data::Dumper;
  #warn "linkparse index args:" . Dumper $param;
  # Keep all the parameters in the url
  my %urlparts;
  for my $part ( qw(action viewonly append listid itemid fieldname groupby orderby filterfield filtervalue searchq deleteq value) ) {
    my $value = $param->{$part}
             || $c->request->params->{$part}
             || undef;
    $urlparts{$part} = $value if $value;
  }

  #use Data::Dumper;
  #$c->log->debug("*** linkparse: urlparts = " . Dumper(\%urlparts) . " ***\n");
  $c->stash( %urlparts );
}

# Load list, item or field data
#
sub loaddata {
  my($self, $c, $param) = @_;

  use Data::Dumper;
  #$c->log->debug("*** loaddata: param = " . Dumper($param) . " ***\n");
  # Load list information
  my $listid;
  if ( $param->{listid} ) {
    $listid = $param->{listid};
    $c->model('Project')->listid( $listid );
    $c->stash(
      listid    => $listid,
      fieldlist => [ $c->model('Project')->fieldlist ],
      listname  => $c->model('Project')->listname,
    );
  } else {
    $c->model('Project')->reset();
  }

  # Load item values
  my $itemid;
  if ( $param->{itemid} ) {
    $itemid = $param->{itemid};
    $c->stash(
      itemid => $itemid,
      item => $c->model('Project')->item_get( itemid => $itemid ),
    );
  }

  # Load field information
  my $fieldname;
  if ( $param->{fieldname} ) {
    $fieldname = $param->{fieldname};
    $c->stash(
      fieldname => $fieldname,
      field => $c->model('Project')->field_get( fieldname => $fieldname ),
    );
  }

  #$c->log->debug("*** loaddata: listid    = " .($listid   ||'')." ***");
  #$c->log->debug("*** loaddata: itemid    = " .($itemid   ||'')." ***");
  $c->log->debug("*** lodddata: fieldname = " .($fieldname||'')." ***");
}


# Global actions when no list is defined
#
sub global_actions {
  my ( $self, $c, $param ) = @_;

  $c->log->debug("*** globalactions: start ***");

  $param->{action} ||= '';
  if ( $param->{action} eq 'create' ) {
    $c->log->debug("*** globalactions: calling create ***");
    $c->stash(
      template  => 'project/update.tt',
      fieldlist => $c->model('Project')->config_example(),
    );
  } elsif ( $param->{action} eq 'updateconf' ) {
    my $listname = $c->request->params->{listname};
    my $listid   = $listname;
    $listid =~ s/\W+//g; # Remove odd chars
    my $fieldlist = $c->request->params->{fieldlist};
    $c->log->debug("*** globalactions: create new database $listid ***");
    $c->model('Project')->listid( $listid );
    my $saved = $c->model('Project')->saveconfig(
      fieldlist => $fieldlist, listname => $listname
    );
    # XXX: Deal with errors
    $c->stash(
      lists => [ $c->model('Project')->alllists ],
      template => 'project/list.tt',
    );
  } else {
    $c->log->debug("*** globalactions: calling list ***");
    $c->stash(
      lists => [ $c->model('Project')->alllists ],
      template => 'project/list.tt',
    );
  }
  $c->log->debug("*** globalactions: end ***");
}

# Various operations on one list
#
sub list_actions {
  my ( $self, $c, $param ) = @_;

  if ( $param->{action} eq 'editconf' ) {
    $c->stash(
      template  => 'project/update.tt',
      fieldlist => $c->model('Project')->field_definition,
    );
  } elsif ( $param->{action} eq 'summary' ) {
    my $items = $c->model('Project')->list_summary(
      map { $c->stash->{$_} ? ( $_=>$c->stash->{$_} ) : () }
      qw(searchq deleteq groupby orderby filterfield filtervalue)
    );
    $c->stash(
      template       => 'project/summary.tt',
      items          => $items,
      listname       => $c->stash->{listname},
      listid         => $c->stash->{listid},
      fieldlist      => [ $c->model('Project')->summaryfields ],
      orderbyfields  => [ $c->model('Project')->orderbyfields ],
      groupbyfields  => [ $c->model('Project')->groupbyfields ],
      filterbyfields => [ $c->model('Project')->filterbyfields ],
    );
  } elsif ( $param->{action} eq 'createitem' ) {
    if ( $c->request->param('save') ) {
      $c->log->debug("*** list_actions: save new object ***");
      my $itemid = $c->model('Project')->item_create(
        item => $c->request->parameters
      );
      # Load the item
      $c->stash(
        itemid => $itemid,
        item => $c->model('Project')->item_get( itemid => $itemid ),
      );
    } 
    $c->stash(
      template       => 'project/itemedit.tt',
    );
  } elsif ( $param->{action} eq 'loadmanager' ) {
    for my $job ( $c->model('Project')->loadmanager_items() ) {
      $c->model('Loadmanager')->item_add( item => $job );
    }
    $c->stash(
      active => { $c->model('Loadmanager')->active_queues },
      no_wrapper => 1,
      template => 'project/loadmanager.tt',
    );
  }
}

# Actions on one item
#
sub item_actions {
  my ( $self, $c, $param ) = @_;

  if ( $param->{action} eq 'ajaxexpand' ) {
    $c->stash(
      fieldlist => [ $c->model('Project')->expandedfields ],
      template   => 'project/itemexpand.tt',
      no_wrapper => 1,
      markdown   => Text::MultiMarkdown->new(),
    );
  } elsif ( $param->{action} eq 'edit' ) {
    if ( $c->request->param('save') ) {
      $c->log->debug("*** list_actions: save old object ***");
      $c->model('Project')->item_set(
        itemid => $c->stash->{itemid}, item => $c->request->parameters
      );
      # Load the item
      $c->stash(
        item => $c->model('Project')->item_get( itemid => $c->stash->{itemid} ),
      );
    }
    $c->stash(
      template       => 'project/itemedit.tt',
    );
  } elsif ( $param->{action} eq 'view' ) {
    $c->stash(
      template       => 'project/itemedit.tt',
      viewonly       => 1,
      markdown       => Text::MultiMarkdown->new(),
    );
  }
}

# Find out what is being request to be done on the field, and then execute it
#
sub field_actions {
  my ( $self, $c, $param ) = @_;

  my $fieldname = $param->{fieldname};
  if ( $param->{action} eq 'ajaxdata' ) {
    my $value;
    if ( $value = $c->request->params->{value} ) {
      $c->log->debug("*** fieldactions: ajaxdata save field $fieldname value $value ***");
      $c->model('Project')->item_update(
        itemid  => $param->{itemid},
        updates => { $fieldname => $value },
      );
    } else {
      $value =
        $c->stash( 'item' )->{ $fieldname };
      $c->log->debug("*** fieldactions: ajaxdata load field $fieldname value $value ***");
    }
    $c->response->body( $value );
  }
}

#sub oldindex {
#  my ( $self, $c, %param ) = @_;
#  # Display configuration editor to create new configuration
#  if ( $action eq 'create' ) {
#    $c->stash(
#      template  => 'project/update.tt',
#      projname => '',
#      fielddef => $c->model('Project')->field_definition(),
#    );
#
#  # Display configuration editor and edit existing configuration
#  } elsif ( $action eq 'editconf' ) {
#    $c->stash(
#      template  => 'project/update.tt',
#      projname => $listid,
#      fielddef => $c->model('Project')->field_definition(),
#    );
#
#  # Receive configuration from form and save to database
#  } elsif ( $action eq 'updateconf' ) {
#    my $name     = $c->request->params->{projname};
#    my $fielddef = $c->request->params->{fielddef};
#  
#    unless ( $listid ) {
#      $c->log->debug("*** create new database $listid ***");
#      ( $listid = $name ) =~ s/\W+//g;
#    }
#    $c->model('Project')->listid( $listid );
#    my $saved = 
#      $c->model('Project')->saveconfig( fielddef => $fielddef, name => $name );
#    if ( $saved ) {
#      $c->stash->{status_msg} = "Project Definition Saved.";
#      $c->log->debug("*** $name saved ***");
#      #$c->forward('list');
#      $c->stash(
#        template => 'project/update.tt',
#        projname => $name,
#        fielddef => $fielddef,
#      );
#      $c->response->redirect($c->uri_for($self->action_for('list')));
#    } else {
#      $c->stash->{status_msg} = "Project Definition Not Saved Due to Errors";
#      $c->log->debug("*** $name not saved ***");
#      $c->stash(
#        template => 'project/update.tt',
#        projname => $name,
#        fielddef => $fielddef,
#      )
#  
#    }
#  
#  # Delete a configuration and all data with it
#  } elsif ( $action eq 'delete' ) {
#    $c->model('Project')->listid( $listid );
#    $c->model('Project')->collection_delete();
#    $c->stash(
#      template => 'project/list.tt',
#    )
#
#  } elsif ( $action eq 'summary' ) {
#    my ($fieldlist, $data ) = $c->model('Project')->list_summary();
#    $c->stash(
#      template  => 'project/summary.tt',
#      title     => $listid,
#      listid  => $listid,
#      list      => $data,
#      fieldlist => $fieldlist,
#    );
#  } elsif ( $action eq 'expanded' ) {
#    my ($fieldlist, $data ) = $c->model('Project')->list_summary();
#    $c->stash(
#      template  => 'project/summary.tt',
#      title     => $listid,
#      listid  => $listid,
#      list      => $data,
#      fieldlist => $fieldlist,
#      expanded  => 1,
#    );
#  } elsif ( $action eq 'edititem' ) {
#    my $record = $c->model('Project')->item_get( itemid => $param{item});
#    $c->stash(
#      template  => 'project/edititem.tt',
#      record    => $record,
#    );
#  } elsif ( $action eq 'viewitem' ) {
#    my $record = $c->model('Project')->item_expanded( itemid => $param{item});
#    $c->stash(
#      template  => 'project/edititem.tt',
#      record    => $record,
#      viewonly=>1,
#    );
# } elsif ( $action eq 'ajaxexpand' ) {
#  my $record = $c->model('Project')->item_expanded( itemid => $param{item});
#  $c->stash(
#    template   => 'project/itemexpand.tt',
#    record     => $record,
#    no_wrapper => 1,
#  );
#  } elsif ( $action eq 'ajaxdata' ) {
#  my $value;
#  if ( $value = $c->request->params->{value} ) {
#    #$c->log->debug("*** ajax save field $field value $value ***");
#    $c->model('Project')->item_update(
#      itemid => $param{item},
#      updates => { $param{field} => $value },
#    );
#  } else {
#    $value =
#      $c->model('Project')->field_getvalue( itemid => $param{item}, fieldname => $param{field} );
#    #$c->log->debug("*** ajax load field $field value $value ***");
#  }
#  $c->response->body( $value );
#  } else {
#    #$c->response->body("<p>Dhandler exception:</p><pre>" . Dumper(\%params) . "</pre>" )
#  $c->stash(
#    collections => [ $c->model('Project')->alllists ],
#    template => 'project/list.tt',
#  );
#  }
#  $c->detach( $c->view("TT") );
#}

#sub base :Chained('/') :PathPart('project') :CaptureArgs(0) {
#  my ($self, $c) = @_;
#  # Print a message to the debug log
#  $c->log->debug("*** INSIDE BASE METHOD ***");
#}

#sub create :Chained('base') :PathPart('create') :Args(0) {
#  my ($self, $c) = @_;
#
#  $c->stash(
#    projname => '<New Project>',
#    template => 'project/update.tt',
#  );
#  $c->detach( $c->view("TT") );
#}

#sub read :Chained('base') :PathPart('read') :Args(1) {
#  my ($self, $c, $listid) = @_;
#  $c->model('Project')->listid( $listid );
#  my ($fieldlist, $data ) = $c->model('Project')->list_summary();
#  $c->stash(
#    template  => 'project/summary.tt',
#    title     => $listid,
#    listid  => $listid,
#    list      => $data,
#    fieldlist => $fieldlist,
#  );
#  $c->detach( $c->view("TT") );
#}

#sub update :Chained('base') :PathPart('update') :Args(1) {
#  my ($self, $c, $listid) = @_;
#
#  $c->log->debug("*** read $listid ***");
#  $c->model('Project')->listid( $listid );
#  $c->stash(
#    projname => $listid,
#    fielddef => $c->model('Project')->field_definition(),
#  );
#  $c->detach( $c->view("TT") );
#}

#sub update_do :Chained('base') :PathPart('update_do') :Args(0) {
#  my ($self, $c, $listid) = @_;
#
#  my $name     = $c->request->params->{projname};
#  my $fielddef = $c->request->params->{fielddef};
#
#  unless ( $listid ) {
#    $c->log->debug("*** create new database $listid ***");
#    ( $listid = $name ) =~ s/\W+//g;
#  }
#  $c->model('Project')->listid( $listid );
#  my $saved = 
#    $c->model('Project')->saveconfig( fielddef => $fielddef, name => $name );
#  if ( $saved ) {
#    $c->stash->{status_msg} = "Project Definition Saved.";
#    $c->log->debug("*** $name saved ***");
#    #$c->forward('list');
#    $c->stash(
#      template => 'project/update.tt',
#      projname => $name,
#      fielddef => $fielddef,
#    );
#    $c->response->redirect($c->uri_for($self->action_for('list')));
#  } else {
#    $c->stash->{status_msg} = "Project Definition Not Saved Due to Errors";
#    $c->log->debug("*** $name not saved ***");
#    $c->stash(
#      template => 'project/update.tt',
#      projname => $name,
#      fielddef => $fielddef,
#    )
#
#  }
#  $c->detach( $c->view("TT") );
#}

#sub delete :Chained('base') :PathPart('delete') :Args(1) {
#  my ($self, $c, $listid) = @_;
#
#  $c->model('Project')->listid( $listid );
#  $c->model('Project')->collection_delete();
#  $c->response->redirect($c->uri_for($self->action_for('list')));
#}

# List existing collections
#sub list :Local {
#  my ($self, $c) = @_;
#
#  $c->stash(
#    collections => [ $c->model('Project')->project_collections ],
#    template => 'project/list.tt',
#  );
#  $c->detach( $c->view("TT") );
#}

# Handle ajax calls
#sub ajax :Chained('base') :PathPart('ajax') :CaptureArgs(1) {
#  my($self, $c, $listid) = @_;
#
#  $c->model('Project')->listid( $listid );
#}

#sub expand :Chained('ajax') :PathPart('expand') :Args(1) {
#  my($self, $c, $item) = @_;
#  my $record = $c->model('Project')->item_expanded( itemid => $item);
#  $c->stash(
#    template   => 'project/itemexpand.tt',
#    record     => $record,
#    no_wrapper => 1,
#  );
#  $c->detach( $c->view("TT") );
#}

#sub get :Chained('ajax') :PathPart('get') :Args(2) {
#  my($self, $c, $item, $field) = @_;
#  $c->response->body(
#    $c->model('Project')->field_getvalue( itemid => $item, fieldname => $field )
#  );
#}

#sub field :Chained('ajax') :PathPart('field') :Args(2) {
#  my($self, $c, $item, $field) = @_;
#
#  my $value;
#  if ( $value = $c->request->params->{value} ) {
#    #$c->log->debug("*** ajax save field $field value $value ***");
#    $c->model('Project')->item_update(
#      itemid => $item,
#      updates => { $field => $value },
#    );
#  } else {
#    $value =
#      $c->model('Project')->field_getvalue( itemid => $item, fieldname => $field );
#    #$c->log->debug("*** ajax load field $field value $value ***");
#  }
#  $c->response->body( $value );
#  
#}

=head1 AUTHOR

Soren Dossing

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
