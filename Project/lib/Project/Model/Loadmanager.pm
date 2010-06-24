package Project::Model::Loadmanager;
use base 'Catalyst::Model::Factory::PerRequest';
__PACKAGE__->config( class => 'Load::Manager' );
