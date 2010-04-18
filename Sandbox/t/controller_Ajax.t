use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sandbox' }
BEGIN { use_ok 'Sandbox::Controller::Ajax' }

ok( request('/ajax')->is_success, 'Request should succeed' );
done_testing();
