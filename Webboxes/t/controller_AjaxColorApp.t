use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'Webboxes' }
BEGIN { use_ok 'Webboxes::Controller::AjaxColorApp' }

ok( request('/ajaxcolorapp')->is_success, 'Request should succeed' );
done_testing();
