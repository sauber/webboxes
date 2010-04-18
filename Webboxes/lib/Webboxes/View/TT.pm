package Webboxes::View::TT;

use strict;

use parent 'Catalyst::View::TT';

use Scalar::Util qw(blessed);
use DateTime::Format::DateParse;

__PACKAGE__->config({
  INCLUDE_PATH => [
    Webboxes->path_to( 'root' )
  ],
  #PRE_PROCESS  => 'config/main',
  #WRAPPER      => 'site/wrapper',
  ERROR        => 'error.tt2',
  TIMER        => 0
});

=head1 NAME

Webboxes::View::TT - Catalyst TTSite View

=head1 SYNOPSIS

See L<Webboxes>

=head1 DESCRIPTION

Catalyst TT::Bootstrap::YUI View.

=head1 AUTHOR

Soren Dossing

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
