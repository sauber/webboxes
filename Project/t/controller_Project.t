use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Project' }
BEGIN { use_ok 'Project::Controller::Project' }

ok( request('/project')->is_success, 'Request should succeed' );
done_testing();
