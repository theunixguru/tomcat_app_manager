package Tomcat::AppManager::Exceptions;

use strict;
use warnings;

use Exception::Class (
    'Tomcat::AppManager::Exception',

    'Tomcat::AppManager::ArgumentException' => {
        isa => 'Tomcat::AppManager::Exception',
        description => 'Bad argument exception'
    },

    'Tomcat::AppManager::OpFailException' => {
        isa => 'Tomcat::AppManager::Exception',
        description => 'Manager operation failure exception'
    }
);

1;
