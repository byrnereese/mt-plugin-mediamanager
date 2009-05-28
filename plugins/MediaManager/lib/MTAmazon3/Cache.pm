# MTAmazon Movable Type Plugin
#
# $Id: $
#
# Copyright (C) 2006 Byrne Reese
#

package MTAmazon3::Cache;
use strict;
use MTAmazon3::Item;

sub new {
    my($class)  = shift;
    my(%params) = @_;
    bless {
        "foo" => "bar"
    }, $class;
}

sub is_stale {

}

sub clear {

}

sub find_item {

}

sub store_item {

}

1;
