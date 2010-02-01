#!/usr/bin/perl -w
#
# This software is licensed under the Artistic License
# 
# Copyright 2005-2007, Six Apart, Ltd.

# TODO:
# * prune out unnecessary code
# * create widget
# * fix bug: Loading template 'dialog/asset_options_amazon.tmpl' failed.
# * insert book button on editor toolbar
# * amazon list filter

package MT::Plugin::MediaManager;

use MT;
use MT::Util qw( mark_odd_rows format_ts);
use Cwd qw/cwd chdir abs_path/;
use File::Basename qw/dirname/;
use File::Spec;
use XML::Simple;

use strict;
use base qw( MT::Plugin );
use constant DEBUG => 0;
our $VERSION = '2.1.1';

require MT::Asset::Amazon;

my $plugin = MT::Plugin::MediaManager->new({
    key         => 'MediaManager',
    id          => 'MediaManager',
    name        => 'Media Manager',
    description => "Maintain and review a list of items pulled from Amazon's product catalog.",
    version     => $VERSION,
    author_name => "Byrne Reese",
    author_link => "http://www.majordojo.com/",
    plugin_link => "http://www.majordojo.com/projects/mediamanager.php",
    object_classes => [ 'MediaManager::Entry','MediaManager::Review' ],
    schema_version => 3.03,
});

sub instance { $plugin; }

MT->add_plugin($plugin);

sub init_registry {
    my $plugin = shift;
    $plugin->registry({
        tags => '$MediaManager::MediaManager::Template::ContextHandlers::mm_tags',
#        upgrade_functions => \&load_upgrade_fns,
        object_types => {
            'asset.amazon' => 'MT::Asset::Amazon',
#            'mediamanager' => 'MediaManager::Entry',
#            'mediamanager_reviews' => 'MediaManager::Review',
        },
        applications => {
            cms => {
                methods => {
                    amazon_find => '$MediaManager::MediaManager::CMS::find',
                    amazon_find_results => '$MediaManager::MediaManager::CMS::find_results',
		    asset_options => '$MediaManager::MediaManager::CMS::asset_options',
		    insert_options => '$MediaManager::MediaManager::CMS::insert_options',
		    insert => '$MediaManager::MediaManager::CMS::insert',

#		    'save'              => \&save_entry,
#		    'edit'              => \&edit_entry,
#		    'edit_dialog'       => \&edit_dialog,
#		    'delete'            => \&delete_entry,
#		    'add'               => \&add_item,
#		    'update_list_prefs' => \&update_list_prefs,
#		    'import'            => \&import_items,
#		    'find_list'         => \&search_lists,
#		    'widget'            => \&create_widget,
#		    'save_widget'       => \&save_widget,
                },
                menus => {
                    'create:amazon' => {
                        label  => 'Amazon Asset',
                        order  => 302,
                        dialog => 'amazon_find',
                        view   => "blog",
                    },
                },
            },
        },
    });
}

#sub load_upgrade_fns {
#    require MediaManager::Upgrade;
#    return MediaManager::Upgrade->core_upgrade_functions;
#}

#sub load_tags {
#    require MediaManager::Template::ContextHandlers;
#    return MediaManager::Template::Context::mm_tags();
#}

1;
__END__

