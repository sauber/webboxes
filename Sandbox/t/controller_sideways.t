use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Sandbox' }
BEGIN { use_ok 'Sandbox::Controller::sideways' }

ok( request('/sideways')->is_success, 'Request should succeed' );
done_testing();
