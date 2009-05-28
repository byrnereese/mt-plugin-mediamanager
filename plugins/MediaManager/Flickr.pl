#!/usr/bin/perl -w

# Description: This is the Media Manager handler for importing Flickr photos
#              into your Movable Type blog.
#
# This software has been donated to the Movable Type Open Source Project
# Copyright 2007, Six Apart, Ltd.
#
# $Id: $

package MT::Plugin::MediaManager::Flickr;

use MT;

use strict;
use base qw( MT::Plugin );
use constant DEBUG => 0;
our $VERSION = '1.0';

my $plugin = MT::Plugin::MediaManager::Flickr->new({
    id              => 'MediaManagerFlickr',
    key             => 'MediaManagerFlickr',
    name            => 'Flickr',
    version         => $VERSION,
    author_name     => "Byrne Reese",
    author_link     => "http://www.majordojo.com/",
    plugin_link     => "http://www.majordojo.com/projects/MediaManager/",
    description     => "A Flickr handler for allowing users to import Flickr images into their Movable Type blog via the Media Manager plugin.",
    system_config_template => \&sysconf_template,
    settings        => new MT::PluginSettings([
					       ['flickr_apikey', { Default => '' }],
					       ['flickr_secret', { Default => '' }], 
					       ]),
    schema_version => 4,
});

sub instance { $plugin; }

MT->add_plugin($plugin);

sub init_app {
    MT::Author->install_meta( { columns => [ 'flickr_auth_token', 'flickr_user_id' ] } );
}

sub init_registry {
    my $plugin = shift;
    $plugin->registry({
        object_types => {
            'asset.flickr' => 'MT::Asset::Flickr',
        },
	callbacks => {
	    'MT::App::CMS::template_source.users_content_nav' => sub {
		$plugin->insert_profile_link( @_ );
	    },
	},
        applications => {
            cms => {
                methods => {
                    flickr_auth => '$MediaManager::Flickr::CMS::auth',
                    flickr_authed => '$MediaManager::Flickr::CMS::authed',
                    flickr_find => '$MediaManager::Flickr::CMS::find',
		    flickr_asset_options => '$MediaManager::Flickr::CMS::asset_options',
#		    insert_options => '$MediaManager::MediaManager::CMS::insert_options',
#		    insert => '$MediaManager::MediaManager::CMS::insert',
                },
                menus => {
                    'create:flickr' => {
                        label  => 'Flickr Asset',
                        order  => 304,
                        dialog => 'flickr_find',
                        view   => "blog",
                    },
                },
            },
        },
     });
}

sub insert_profile_link {
    my $plugin = shift;
    my( $cb, $app, $html_ref ) = @_;
    my $base_uri = $app->uri;
    my $mode = $app->mode;
    my $active = $mode =~ /flickr_auth/  ? ' class="active"' : '';
    if ( $active ) {
        $$html_ref =~ s/<li class="active">/<li>/g;
    }
    $$html_ref =~ s/(<li[^>]*>.*?author_id=.*?<__trans phrase="Permissions"><\/a><\/li>)/$1\n<li$active><a href="$base_uri?__mode=flickr_auth">Flickr Auth<\/a><\/li>/g;
}

sub sysconf_template {
    my $tmpl = <<'EOT';
    <div class="setting">
      <div class="label">
        <label for="flickr_apikey">Flickr API Key:</label>
      </div>
      <div class="field">
        <p><input type="text" size="50" name="flickr_apikey" value="<TMPL_VAR NAME=FLICKR_APIKEY>" /><br />
        <a target="_new" href="http://flickr.com/services/api/keys/apply/">Register for an API Key</a> | 
        <a target="_new" href="http://flickr.com/services/api/keys/">What is an API Key?</a></p>
      </div>
      <div class="label">
        <label for="devtoken">Flickr Secret:</label>
      </div>
      <div class="field">
        <p><input type="text" size="30" name="flickr_secret" value="<TMPL_VAR NAME=FLICKR_SECRET>" /></p>
      </div>
    </div>
EOT
}

1;
__END__

