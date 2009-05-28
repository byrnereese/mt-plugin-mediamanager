# Media Manager Movable Type Plugin
#
# $Id: $
#
# Copyright (C) 2005 Byrne Reese
#

package MediaManager::Review;
use strict;

use MT::Object;
@MediaManager::Review::ISA = qw( MT::Object );
__PACKAGE__->install_properties({
    column_defs => {
		'id'                => 'integer not null auto_increment', 
		'entry_id'          => 'integer not null', 
		'rating'            => 'integer', 
		'layout'            => 'string(20) not null',
		'image_drop_shadow' => 'string(10) not null', 
		'image_rotation'    => 'integer', 
		'image_blur'        => 'integer', 
		'image_size'        => 'string(20)', 
		'image_url'         => 'string(150)', 
		'show_buynow'       => 'integer',
		'show_price'        => 'integer',
		'show_rating'       => 'integer'
    },
    indexes => {
	rating => 1,
	entry_id => 1
    },
    datasource => 'mediamanager_reviews',
    primary_key => 'id',
});

1;
