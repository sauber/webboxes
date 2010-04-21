use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sandbox' }
BEGIN { use_ok 'Sandbox::Controller::BootstrapYUI' }

ok( request('/bootstrapyui')->is_success, 'Request should succeed' );
done_testing();
