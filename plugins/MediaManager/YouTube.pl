#!/usr/bin/perl -w

# Description: This is the Media Manager handler for importing Flickr photos
#              into your Movable Type blog.
#
# This software has been donated to the Movable Type Open Source Project
# Copyright 2007, Six Apart, Ltd.
#
# $Id: $

package MT::Plugin::MediaManager::YouTube;

use MT;

use strict;
use base qw( MT::Plugin );
use constant DEBUG => 0;
our $VERSION = '1.0';

my $plugin = MT::Plugin::MediaManager::YouTube->new({
    id              => 'MediaManagerYouTube',
    key             => 'MediaManagerYouTube',
    name            => 'YouTube',
    version         => $VERSION,
    author_name     => "Byrne Reese",
    author_link     => "http://www.majordojo.com/",
    plugin_link     => "http://www.majordojo.com/projects/MediaManager/",
    description     => "A YouTube handler for allowing users to import YouTube videos into their Movable Type blog via the Media Manager plugin.",
    schema_version => 2,
});

sub instance { $plugin; }

MT->add_plugin($plugin);

sub init_registry {
    my $plugin = shift;
    $plugin->registry({
        object_types => {
            'asset.youtube' => 'MT::Asset::YouTube',
        },
        applications => {
            cms => {
                methods => {
                    youtube_find => '$MediaManager::YouTube::CMS::find',
                    youtube_find_results => '$MediaManager::YouTube::CMS::find_results',
		    youtube_asset_options => '$MediaManager::YouTube::CMS::asset_options',
#		    insert_options => '$MediaManager::MediaManager::CMS::insert_options',
#		    insert => '$MediaManager::MediaManager::CMS::insert',
                },
                menus => {
                    'create:youtube' => {
                        label  => 'YouTube Asset',
                        order  => 303,
                        dialog => 'youtube_find',
                        view   => "blog",
                    },
                },
            },
        },
     });
}

1;
__END__

