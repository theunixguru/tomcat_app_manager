#!/usr/bin/env perl

use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test::More;

use Tomcat::AppManager;

# Test data

my %test_data = (
    host => 'localhost',
    port => 8080,
    app_path => '/test_app',
    app_location => '/var/tests/test_app.war'
);

# Monkey patching the _send_http_request method - no need
# to actually send the request

*Tomcat::AppManager::_send_http_request = sub {
    my $self = shift;
    my $headers = HTTP::Headers->new();
    $headers->header('Content-Type' => 'text/plain');
    return HTTP::Response->new(200, 'OK', $headers, 'OK - All good');
};

my $app_manager = Tomcat::AppManager->new(
    host => $test_data{host},
    password => $test_data{port}
);

# Test - deploy() method

$app_manager->deploy(
    app_path => $test_data{app_path},
    app_location => $test_data{app_location}
);
is(
    $app_manager->get_last_request_object()->uri(),
    'http://localhost:8080/manager/text/deploy?'.
        'path=%2Ftest_app&war=file%3A%2Fvar%2Ftests%2Ftest_app.war',
    'OK - deploy'
);

# Test - undeploy() method

$app_manager->undeploy(
    app_path => $test_data{app_path}
);
is(
    $app_manager->get_last_request_object()->uri(),
    'http://localhost:8080/manager/text/undeploy?path=%2Ftest_app',
    'OK - undeploy'
);

# Test - start() method

$app_manager->start(app_path => $test_data{app_path});
is(
    $app_manager->get_last_request_object()->uri(),
    'http://localhost:8080/manager/text/start?path=%2Ftest_app',
    'OK - start'
);

# Test - stop() method

$app_manager->stop(app_path => $test_data{app_path});
is(
    $app_manager->get_last_request_object()->uri(),
    'http://localhost:8080/manager/text/stop?path=%2Ftest_app',
    'OK - stop'
);

# Test - save_config() method

my $config_file = $$.'_test_tmp_config.yml';
$app_manager->save_config($config_file);
ok(-f $config_file, 'OK - config file exists');

my $saved_config = YAML::LoadFile($config_file);
is_deeply(
    $saved_config,
    { host => $test_data{host}, port => $test_data{port} },
    'OK - saved configuration matches'
);
unlink($config_file);

# Let's run all methods tests again against values from a config file and
# utilizing app_tag

$app_manager = Tomcat::AppManager->new(config => 'test_config.yml');

# Test - deploy() method

$app_manager->deploy(app_tag => 'test');
is(
    $app_manager->get_last_request_object()->uri(),
    'http://localhost:8080/manager/text/deploy?'.
        'path=%2Ftest_app&war=file%3A%2Fvar%2Ftests%2Ftest_app.war',
    'OK - deploy via app_tag'
);

# Test - undeploy() method

$app_manager->undeploy(app_tag => 'test');
is(
    $app_manager->get_last_request_object()->uri(),
    'http://localhost:8080/manager/text/undeploy?path=%2Ftest_app',
    'OK - undeploy via app_tag'
);

# Test - start() method

$app_manager->start(app_tag => 'test');
is(
    $app_manager->get_last_request_object()->uri(),
    'http://localhost:8080/manager/text/start?path=%2Ftest_app',
    'OK - start via app_tag'
);

# Test - stop() method

$app_manager->stop(app_tag => 'test');
is(
    $app_manager->get_last_request_object()->uri(),
    'http://localhost:8080/manager/text/stop?path=%2Ftest_app',
    'OK - stop via app_tag'
);

done_testing();

