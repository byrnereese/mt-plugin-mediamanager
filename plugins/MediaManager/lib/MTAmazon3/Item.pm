# MTAmazon Movable Type Plugin
#
# $Id: $
#
# Copyright (C) 2006 Byrne Reese
#

package MTAmazon3::Item;
use strict;

use base qw( MT::Object );

__PACKAGE__->install_properties({
    column_defs => {
		'id'              => 'integer not null auto_increment', 
		'response_groups' => 'string(150) not null',
		'asin'            => 'string(50) not null', 
		'data'            => 'text', 
    },
    indexes => {
	created_on => 1,
	asin => 1,
    },
    audit => 1,
    datasource => 'mtamazon',
    primary_key => 'id',
});

sub eval_data {
    my $self = shift;
    require MTAmazon3::Util;
    my $VAR1;
    eval('$VAR1 = ' . $self->data);
    return $VAR1;
}

1;
