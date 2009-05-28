# Media Manager Movable Type Plugin
#
# $Id: $
#
# Copyright (C) 2005 Byrne Reese
#

package MediaManager::App;

use vars qw( $DEBUG );
use strict;

@MediaManager::App::ISA = qw( MT::App );

use MT::App;
use MT::App::CMS;

$DEBUG = 0;

use MT::Util qw( format_ts offset_time_list );
use MT::ConfigMgr;
use MediaManager::Entry;
use MediaManager::Util;
use XML::Simple;

sub init {
    my $app = shift;
    my %param = @_;
    $app->SUPER::init(%param) or return;

    MediaManager::Util::debug("Initializing Media Manager");
    $app->add_methods(
		      'search'            => \&search,
		      'results'           => \&search_results,
		      'view'              => \&list_items,
		      'save'              => \&save_entry,
		      'edit'              => \&edit_entry,
		      'edit_dialog'       => \&edit_dialog,
		      'delete'            => \&delete_entry,
		      'add'               => \&add_item,
		      'update_list_prefs' => \&update_list_prefs,
		      'import'            => \&import_items,
		      'find_list'         => \&search_lists,
		      'widget'            => \&create_widget,
		      'save_widget'       => \&save_widget,
    );

    $app->{default_mode}   = 'view';
    $app->{user_class}     = 'MT::Author';
    $app->{requires_login} = 1;
    $app->{mtscript_url}   = ($app->{cfg}->AdminCGIPath ? $app->{cfg}->AdminCGIPath : $app->{cfg}->CGIPath) . 
	$app->{cfg}->AdminScript;
    $app->{mmscript_url}   = $app->path . $app->{cfg}->AdminScript;

    require MTAmazon3::Util;
    eval {
      $app->{mmanager_cfg}   = MTAmazon3::Util::readconfig($app->{query}->param('blog_id'));
    };
    return $app->error($@) if $@;

    MediaManager::Util::debug("Finished initializing Media Manager.");
    $app;
}

sub init_tmpl {
    my $app = shift;
    MediaManager::Util::debug("Initializing template file.","  >");
    MediaManager::Util::debug("Calling MT::App::load_tmpl(".join(", ",@_).")","    >");
    my $tmpl = $app->load_tmpl(@_);
    if (!$tmpl) {
	my $err = $app->translate("Loading template '[_1]' ".
				  "failed: [_2]",
				  $_[0], $@);
	MediaManager::Util::debug($err,"    >");
	return $app->error($err);
    } else {
	MediaManager::Util::debug("Template file successfully loaded.","    >");
    }

    MT::App::CMS::is_authorized($app);
    if (my $perms = $app->{perms}) {
        $tmpl->param(can_post => $perms->can_post);
        $tmpl->param(can_upload => $perms->can_upload);
        $tmpl->param(can_edit_entries =>
            $perms->can_post || $perms->can_edit_all_posts);
        $tmpl->param(can_search_replace => $perms->can_edit_all_posts);
        $tmpl->param(can_edit_templates => $perms->can_edit_templates);
        $tmpl->param(can_edit_authors => $perms->can_administer_blog);
        $tmpl->param(can_edit_config => $perms->can_edit_config);
        # FIXME: once we have edit_commenters permission
        $tmpl->param(can_edit_commenters => $perms->can_edit_config());
        $tmpl->param(can_rebuild => $perms->can_rebuild);
        $tmpl->param(can_edit_categories => $perms->can_edit_categories);
        $tmpl->param(can_edit_notifications => $perms->can_edit_notifications);
        $tmpl->param(has_manage_label =>
            $perms->can_edit_templates  || $perms->can_administer_blog ||
            $perms->can_edit_categories || $perms->can_edit_config);
        $tmpl->param(has_posting_label =>
            $perms->can_post  || $perms->can_edit_all_posts ||
            $perms->can_upload);
        $tmpl->param(has_community_label =>
            $perms->can_post  || $perms->can_edit_config ||
            $perms->can_edit_notifications || $perms->can_edit_all_posts);
        $tmpl->param(can_view_log => $perms->can_view_blog_log);
    }

    my $apppath = $app->{__path} || "";

    my $spath = $app->{cfg}->StaticWebPath || $apppath;
    $spath =~ s/\/*$/\//g;

    my $enc = $app->{cfg}->PublishCharset ||
              $app->language_handle->encoding;

    $tmpl->param(plugin_name       => "Media Manager");
    $tmpl->param(plugin_version    => $MT::Plugin::MediaManager::VERSION);
    $tmpl->param(plugin_author     => "Byrne Reese");
    $tmpl->param(mt_url            => $app->{mtscript_url});
    $tmpl->param(mtscript_url      => $app->{mtscript_url});
    $tmpl->param(mmscript_url      => $app->{mmscript_url});
    $tmpl->param(static_uri        => $spath);
    $tmpl->param(script_url        => File::Spec->catdir($apppath,"mmanager.cgi"));

    $tmpl->param(script_path       => $apppath);
    $tmpl->param(script_full_url   => $app->base . $app->uri);
    $tmpl->param(mt_version        => MT->VERSION);
    $tmpl->param(language_tag      => $app->current_language);
    $tmpl->param(language_encoding => $enc);
    $tmpl->param(author_name       => $app->{author}->name);
    $tmpl->param(page_titles       => [ reverse @{ $app->{breadcrumbs} } ]);
    $tmpl->param(nav_mediamanager  => 1);

    MediaManager::Util::debug("MT Script URL: ".$tmpl->param('mtscript_url'),"    >");

    MediaManager::Util::debug("Finished initializing template file.","  >");
    return $tmpl;
}

sub list_items
{
    MediaManager::Util::debug("Calling list_items...");
    my $app = shift;
    my $q = $app->{query};

    my $blog_id = $q->param('blog_id');

    unless (defined($blog_id)) {
	return $app->error("You are attempting to access Media Manager, but Media Manager is not able to determine which blog's media queue you are trying to access. Please return to the MAIN MENU and select the blog you would like to view and then click the \"Edit Media Queue\" link at the bottom of the page.");
    }    

    my $list_pref = MT::App::CMS::list_pref($app,'mm_entry');
    my $limit     = $list_pref->{rows};
    my $offset    = $limit eq 'none' ? 0 : ($q->param('offset') || 0);
    my $view      = $list_pref->{view} || 'expanded';

    my $show    = $q->param('show')    || 'all';
    my $sort    = $q->param('sort')    || 'created_on';
    my $acs     = $q->param('acs')     || 0;
    my $catalog = $q->param('catalog') || 'Blended';

    my $blog = $app->blog;

    my %constraints;
    $constraints{blog_id} = $blog_id;
    $constraints{status}  = $show if $show ne 'all';
    $constraints{catalog} = $catalog if $catalog ne 'Blended';

    my %options;
    $options{sort}      = $sort;
    $options{direction} = $acs ? 'ascend' : 'descend';
    $options{limit}     = $limit if $limit ne 'none';
    $options{offset}    = $offset;

    my $total = MediaManager::Entry->count( \%constraints );
    my $iter  = MediaManager::Entry->load_iter( \%constraints, \%options );
    my $i         = 0; # loop iteration counter
    my $count     = 0; # the total number of entries retrieved and displayed
    my @entry_data;

    while (my $entry = $iter->()) {
        $count++;

	my $fin_on_display;
	my $fin_year  = "null";
	my $fin_month = "null";

        $fin_on_display = $entry->finished_on();
	if ($fin_on_display =~ m!^(\d{4})-0?(\d{2})-(\d{2})$!) {
	    $fin_month = "'".$2."'";
	    $fin_year = "'$1'";
	} elsif ($fin_on_display =~ m!^(\d{4})-(\d{2})-(\d{2})!) {
	    $fin_on_display = "$2-$3-$1";
	}

        my $mod_on_display = format_ts("%Y-%m-%d %H:%M:%S",
                                       $entry->modified_on(),
                                       $blog);
	$mod_on_display = "" if $mod_on_display eq '-- ::';
        my $create_on_display = format_ts("%Y-%m-%d %H:%M:%S",
					  $entry->created_on(),
					  $blog);
	$create_on_display = "" if $create_on_display eq '-- ::';

	my $content_tree;
	eval {
	    require MTAmazon3::Plugin;
	    $content_tree = MTAmazon3::Plugin::ItemLookupHelper(
                $app->{mmanager_cfg},{
		    ItemId => $entry->isbn,
		    ResponseGroup => 'Small,Images,OfferSummary',
            });
        };
	if ($@) {
	    return $app->error($@);
	}
	my $item = $content_tree->{'Items'}->{'Item'};

	my $tags;
	my $tag_delim = chr($app->user->entry_prefs->{tag_delim});
	require MT::Tag;
	$tags = MT::Tag->join($tag_delim, $entry->tags);

        my $row = {
            blog_id      => $blog_id,
            key          => $entry->id,
            catalog      => $entry->catalog || 'Books',
            icon         => _gen_icon_url($entry->catalog()),
            isbn         => $entry->isbn,
            status       => $entry->status,
            entry_id     => $entry->entry_id,
            modified_on  => $mod_on_display,
            created_on   => $create_on_display,
            finished_on  => $entry->finished_on_str,
            fin_month    => $fin_month,
            fin_year     => $fin_year,
            entry_odd    => $count % 2 ? 1 : 0,
            title        => $entry->title,
            title_short  => $entry->title_short,
	    tags         => $tags,
            item_url     => $item->{DetailPageURL},
	    authors      => ref $item->{ItemAttributes}->{Author} eq "ARRAY"
		? join(", ", @{ $item->{ItemAttributes}->{Author} })
		: $item->{ItemAttributes}->{Author},
            artists      => ref $item->{ItemAttributes}->{Artist} eq "ARRAY"
		? join(", ", @{ $item->{ItemAttributes}->{Artist} })
		: $item->{ItemAttributes}->{Artist},
            amzn_info    => $item,
	    amzn_img_url => MediaManager::Util::format_img_url($item,"Medium"),
	    amzn_img_tag => MediaManager::Util::format_img_tag($item),
        };
	MediaManager::Util::debug("Entry Id for ".$entry->id." is: ".$entry->entry_id());
        my @status_data;
        for (qw( unread reading read )) {
            push @status_data, { status => $_ };
            $status_data[-1]{checked} = 1 if $entry->status() eq $_;
        }
        $row->{status_loop} = \@status_data;
	$row->{catalog_loop} = _catalog_loop($row->{catalog});
        push @entry_data, $row;
    }
    
    $i = 0;
    foreach my $e (@entry_data) {
	$e->{entry_odd} = ($i++ % 2 ? 0 : 1);
    }

    my $filter_str = ($show eq 'all' ? "Showing <i>$show</i> items" : "Showing items with a status of <i>$show</i>") . " in <i>".($catalog eq 'all' ? 'all catalogs' : $catalog)."</i>, sorted by <i>$sort</i> in <i>".($acs == 0 ? 'descending' : 'ascending')."</i> order.";

    my $param = {
	nav_items       => 1,
	object_type     => 'mm_entry',
        entry_loop      => \@entry_data,
        empty           => !$count,
	filter_str      => $filter_str,
	limit           => $limit,
        "limit_".$limit => 1,
        rows            => $limit,
	offset          => $offset,
	catalog         => $catalog,
        show            => $show,
	sort            => $sort,
        acs             => $acs,
        blog_id         => $blog_id,
        blog_name       => $blog->name,
        blog_url        => $blog->site_url,
        rebuild         => $q->param('rebuild') ? 1 : 0,
	message         => $app->{message},
	start           => $offset + 1,
	end             => $count < $limit ? 
	    $offset + $count 
	         : $offset + $limit,
    };

    $param->{list_start} = $offset + 1;
    $param->{list_end} = $offset + (scalar @entry_data);
    $param->{list_total} = $total;
    $param->{next_max} = $param->{list_total} - ($limit eq 'none' ? 0 : $limit);
    $param->{next_max} = 0 if ($param->{next_max} || 0) < $offset + 1;

    $param->{return_args}     = "blog_id=".$blog->id."&asc=".$acs."&sort=".$sort."&catalog=".$catalog."&show=".$show;
    $param->{view_expanded}   = ($view eq 'expanded');

    if ($limit ne 'none') {
	$param->{PREV_OFFSET}     = $offset > 0;
	$param->{prev_offset_val} = $offset - $limit;
	$param->{next_offset}     = $offset + $limit < $total;
	$param->{next_offset_val} = $offset + $limit;
    }

    SWITCH: {
        $param->{show_all}     = 1, last SWITCH if $show eq 'all';
        $param->{show_unread}  = 1, last SWITCH if $show eq 'unread';
        $param->{show_reading} = 1, last SWITCH if $show eq 'reading';
        $param->{show_read}    = 1, last SWITCH if $show eq 'read';
    }
    SWITCH: {
        $param->{sort_title}       = 1, last SWITCH if $sort eq 'title';
        $param->{sort_status}      = 1, last SWITCH if $sort eq 'status';
        $param->{sort_created_on}  = 1, last SWITCH if $sort eq 'created_on';
        $param->{sort_modified_on} = 1, last SWITCH if $sort eq 'modified_on';
        $param->{sort_finished_on} = 1, last SWITCH if $sort eq 'finished_on';
    }

    $param->{catalog_loop} = _catalog_loop($catalog);
      
    # find author's blogs
    if (my $auth = $app->{author}) {
        require MT::Permission;
        my @perms = MT::Permission->load({ author_id => $auth->id });
        my @data;
        for my $perms (@perms) {
            next unless $perms->role_mask;
            my $blog = MT::Blog->load($perms->blog_id);
            push @data, { top_blog_id   => $blog->id,
                          top_blog_name => $blog->name };
            $data[-1]{top_blog_selected} = 1
                if $blog_id && $blog->id == $blog_id;
        }
        @data = sort { $a->{top_blog_name} cmp $b->{top_blog_name} } @data;
        $param->{top_blog_loop} = \@data;
    }

    my @limit_data;
    my %limits = ( "01-1"    => "1", 
		   "02-5"    => "5",  
		   "03-10"   => "10", 
		   "04-20"   => "20",
		   "05-50"   => "50",
		   "06-100"  => "100",
		   "07-All"  => "99999",
		   );
    for (sort keys %limits) {
	my ($idx,$label) = ($_ =~ /(..)-(.*)/);
	push @limit_data, { 
	    limit_label => $label,
	    limit       => $limits{$_} 
	};
	$limit_data[-1]{checked} = 1 if $param->{limit} == $limits{$_};
    }
    $param->{limit_loop} = \@limit_data;


    $app->add_breadcrumb("Main Menu",$app->{mtscript_url});
    $app->add_breadcrumb($blog->name,$app->{mtscript_url}.'?__mode=menu&blog_id='.$blog->id);
    $app->add_breadcrumb("Media Manager");
    $param->{breadcrumbs} = $app->{breadcrumbs};
    $param->{breadcrumbs}[-1]{is_last} = 1;

    $param->{show_all_option} = 1;

    my $tmpl = $app->init_tmpl('list.tmpl');
    for my $key (keys %$param) {
        $tmpl->param($key, $param->{$key});
    }
    MediaManager::Util::debug("Finished calling list_items.");
    $app->l10n_filter($tmpl->output);
}

sub add_item {
    MediaManager::Util::debug("Calling add_item...");
    my $app = shift;
    my $q = $app->{query};

    my $catalog = $q->param('catalog');
    my $blog    = $app->blog;
    my $blog_id = $blog->id;

    $app->{message} = 'Item added to your queue.';

    my @asins = $app->{query}->param('asin');
    foreach my $asin (@asins) {
	#$asin = _decue($1)    if $asin =~ /^\.[^.]+\.[^.]+\.([^.]+)/;
	#$asin = _ean2isbn($1) if $asin =~ /^978(\d{9})\d$/;

	my $content_tree;
	eval {
	    require MTAmazon3::Plugin;
	    $content_tree = MTAmazon3::Plugin::ItemLookupHelper(
                $app->{mmanager_cfg},{
		    ItemId => $asin,
		    ResponseGroup => 'Small,Images,OfferSummary',
            });
        };
	if ($@) {
	    return $app->error($@);
	}
	my $item = $content_tree->{'Items'}->{'Item'};

	my $entry;
	$entry = MediaManager::Entry->new;
	$entry->isbn($asin);
	$entry->blog_id($blog->id);
	$entry->catalog($item->{ItemAttributes}->{ProductGroup});
	$entry->status('unread');
	$entry->title($item->{ItemAttributes}->{Title});
	$entry->save or
	    return $app->error("Error adding entry: " . $entry->errstr);
    }

    $q->param('rebuild', 1);
    MediaManager::Util::debug("Finished calling add_item.");
    $app->redirect($app->{cfg}->CGIPath.'plugins/MediaManager/mmanager.cgi?blog_id='.$blog_id);
}

sub import_items {
    MediaManager::Util::debug("Calling import_items...");
    my $app = shift;
    my $q = $app->{query};

    my $wishlist = $q->param('wishlist');
    my $blog     = $app->blog;
    my $blog_id  = $blog->id;

    $app->{message} = 'Your wishlist has been imported.';
    my $total_pages = my $current_page = 1;
    require MTAmazon3::Util;
    while ($current_page <= $total_pages) {
	my $xml = MTAmazon3::Util::CallAmazon("ListLookup",$app->{mmanager_cfg},{
	    ListId        => $wishlist,
	    ProductPage   => $current_page,
	    ListType      => 'WishList',
	    ResponseGroup => 'ListItems,ItemAttributes',
	});
	my $results = XMLin($xml);

	if (my $msg = $results->{Lists}->{Request}->{Errors}->{Error}->{Message}) {
	    $app->{message} = $msg;
	    return search($app);
	}
	$total_pages = $results->{Lists}->{List}->{TotalPages};
	MediaManager::Util::debug("There are $total_pages pages for this wishlist.");
	my $items = $results->{Lists}->{List}->{ListItem};
	$items = [ $items ] if (ref($items) ne "ARRAY");
	foreach my $item (@$items) {
	    my $asin  = $item->{Item}->{ASIN};
	    my $title = $item->{Item}->{ItemAttributes}->{Title};
	    my $catalog = $item->{Item}->{ItemAttributes}->{ProductGroup};
	    MediaManager::Util::debug("Found the following wishlist item: ASIN $asin, $title, $catalog");
	my $entry;
	$entry = MediaManager::Entry->new;
	$entry->isbn($asin);
	$entry->blog_id($blog->id);
	$entry->catalog($catalog);
	$entry->status('unread');
	$entry->title($title);
	$entry->save or
	    return $app->error("Error adding entry: " . $entry->errstr);
	}
	$current_page++;
    }

    $q->param('rebuild', 1);
    MediaManager::Util::debug("Finished calling import_items.");
    list_items($app);
}

sub save_entry
{
    MediaManager::Util::debug("Calling save_entry...");
    my $app = shift;
    my $q = $app->{query};

    my $offset      = $q->param('offset');
    my $key         = $q->param('key');
    my $isbn        = $q->param('isbn');
    my $title       = $q->param('title');
    my $finished_on = $q->param('finished_on');
    my $entry_id    = $q->param('entry_id');
    my $catalog     = $q->param('catalog');
    my $tags        = $q->param('tags');
    my $status      = $q->param('status')  || 'unread';

    my $blog    = $app->blog;
    my $blog_id = $blog->id;

    my $entry;
    unless ( $key && ($entry = MediaManager::Entry->load({ id => $key })) ) {
	MediaManager::Util::debug("Adding item to queue","  > ");
        $entry = MediaManager::Entry->new;
	$app->{message} = 'Item added to your queue.';
    } else {
	MediaManager::Util::debug("Updating item on queue","  > ");
	$app->{message} = 'Item in queue updated.';
    }

    if ($q->param('submit') && $q->param('submit') eq 'delete' && $entry) {
        $entry->remove or return $app->error("Error: " . $entry->errstr);
	my $review;
	if ($review = MediaManager::Review->load({ entry_id => $key })) {
	    $review->remove;
	}
	$app->{'message'} = 'Item removed from queue.';
        return list_items($app);
    }

#    $isbn = _decue($1)    if $isbn =~ /^\.[^.]+\.[^.]+\.([^.]+)/;
#    $isbn = _ean2isbn($1) if $isbn =~ /^978(\d{9})\d$/;

    if ($finished_on =~ m!^(\d{2})-(\d{2})-(\d{4})$!) {
	$finished_on = $3.$1.$2."000000";
    }

    my $content_tree;
    eval {
	require MTAmazon3::Plugin;
	$content_tree = MTAmazon3::Plugin::ItemLookupHelper(
            $app->{mmanager_cfg},{
		ItemId => $entry->isbn,
		ResponseGroup => 'Small,Images,OfferSummary',
	    });
    };
    if ($@) {
	return $app->error($@);
    }
    my $item = $content_tree->{'Items'}->{'Item'};
      
    $entry->finished_on($finished_on);
    $entry->title($title);
    $entry->isbn($isbn);
    $entry->status($status);
    $entry->blog_id($blog_id);
    $entry->entry_id($entry_id);
    $entry->catalog($catalog);

    if (defined $tags) {
	MediaManager::Util::debug("Adding tags $tags.");
        require MT::Tag;
        my $tag_delim = chr($app->user->entry_prefs->{tag_delim});
        my @tags = MT::Tag->split($tag_delim, $tags);
        $entry->set_tags(@tags);
    }

    $entry->save or
        return $app->error("Error saving entry with id $key: " . $entry->errstr);

    MediaManager::Util::debug("Finished calling save_entry.");
    $app->redirect($app->{cfg}->CGIPath.'plugins/MediaManager/mmanager.cgi?blog_id='.$blog_id.'&offset='.$offset);
}

sub delete_entry
{
    MediaManager::Util::debug("Calling delete_entry...");
    my $app = shift;
    my $q = $app->{query};

    my $blog_id     = $q->param('blog_id');

    my $blog = $app->blog;

    my @ids = $q->param('id');
    foreach my $key (@ids) {
	MediaManager::Util::debug("Deleting id $key");
	require MediaManager::Entry;
	my $entry;
	if ($entry = MediaManager::Entry->load({ id => $key })) {
	    $entry->remove;
	}
	require MediaManager::Review;
	my $review;
	if ($review = MediaManager::Review->load({ entry_id => $key })) {
	    $review->remove;
	}
    }
    $app->{message} = 'Item(s) removed from queue.';
    $q->param('rebuild', 1);
    MediaManager::Util::debug("Finished calling delete_entry.");
    list_items($app);
}

sub edit_entry_init {
    my ($app,$blog) = @_;

    my $q       = $app->{query};
    my $key     = $q->param('key');
    my $offset  = $q->param('offset');
    my $limit   = $q->param('limit');
    my $sort    = $q->param('sort');
    my $show    = $q->param('show');
    my $acs     = $q->param('acs');

    my $entry = MediaManager::Entry->load({ id => $key });

    my $content_tree;
    eval {
	require MTAmazon3::Plugin;
	$content_tree = MTAmazon3::Plugin::ItemLookupHelper(
            $app->{mmanager_cfg},{
		ItemId => $entry->isbn,
		ResponseGroup => 'Small,Images,OfferSummary',
	    });
    };
    if ($@) {
	return $app->error($@);
    }
    my $amzn_info = $content_tree->{'Items'}->{'Item'};
    my $fin_year  = "null";
    my $fin_month = "null";
    
    my $fin_on_display = $entry->finished_on_str();
    my $mod_on_display = $entry->modified_on_str();
    my $create_on_display = $entry->created_on_str();

    if ($fin_on_display =~ m!^0?(\d{1,2})-0?(\d{1,2})-(\d{4})$!) {
	$fin_month = "'".($1 - 1)."'";
	$fin_year = "'$3'";
    }

    my $tags;
    my $tag_delim = chr($app->user->entry_prefs->{tag_delim});
    require MT::Tag;
    $tags = MT::Tag->join($tag_delim, $entry->tags);
    MediaManager::Util::debug("Loading tags: $tags.");

    my $param = {
        blog_id      => $blog->id,
        blog_name    => $blog->name,
	acs          => $acs,
	sort         => $sort,
	show         => $show,
	offset       => $offset,
	limit        => $limit,
	view         => 'list',
	title        => $entry->title,
	authors      => ref $amzn_info->{ItemAttributes}->{Author} eq "ARRAY"
	    ? join(", ", @{ $amzn_info->{ItemAttributes}->{Author} })
	    : $amzn_info->{Authors}->{Author},
        artists      => ref $amzn_info->{ItemAttributes}->{Artist} eq "ARRAY"
	    ? join(", ", @{ $amzn_info->{ItemAttributes}->{Artist} })
	    : $amzn_info->{Artists}->{Artist},
	item_url     => $amzn_info->{url},
	key          => $entry->id,
	isbn         => $entry->isbn,
	asin         => $entry->isbn,
	entry_id     => $entry->entry_id,
	catalog      => $entry->catalog || 'Books',
	status       => $entry->status,
        tags         => $tags,
	finished_on  => $fin_on_display,
	fin_year     => $fin_year,
	fin_month    => $fin_month,
	created_on   => $create_on_display,
	modified_on  => $mod_on_display,
	amzn_img_url => MediaManager::Util::format_img_tag($amzn_info,"Medium"),
	img_rot      => 0,
    };
    my @status_data;
    for (qw( unread reading read )) {
	push @status_data, { status => $_ };
	$status_data[-1]{checked} = 1 if $entry->status eq $_;
    }
    $param->{status_loop} = \@status_data;
    $param->{status} = $entry->status;

    $param->{catalog_loop} = _catalog_loop($param->{catalog});

    return $param;
}

sub edit_entry {
    MediaManager::Util::debug("Calling edit_entry...");
    my $app = shift;

    my $q       = $app->{query};
    my $blog    = $app->blog;

    my $param = edit_entry_init($app,$blog);
    $param->{icon} = _gen_icon_url($param->{catalog});

    $app->add_breadcrumb("Main Menu",$app->{mtscript_url});
    $app->add_breadcrumb($blog->name,$app->{mtscript_url}.'?__mode=menu&blog_id='.$blog->id);
    $app->add_breadcrumb("Media Manager",$app->uri.'?__mode=view&blog_id='.$blog->id);
    $app->add_breadcrumb("Edit Item");
    $param->{breadcrumbs} = $app->{breadcrumbs};
    $param->{breadcrumbs}[-1]{is_last} = 1;

    my $tmpl = $app->init_tmpl('edit.tmpl');
    for my $key (keys %$param) {
        $tmpl->param($key, $param->{$key});
    }
    MediaManager::Util::debug("Finished calling edit_entry.");
    $app->l10n_filter($tmpl->output);
}

sub edit_dialog {
    MediaManager::Util::debug("Calling edit_dialog...");
    my $app = shift;

    my $q       = $app->{query};
    my $blog    = $app->blog;

    my $param = edit_entry_init($app,$blog);
    $param->{icon} = _gen_icon_url($param->{catalog});

    my $tmpl = $app->init_tmpl('edit_dialog.tmpl');
    for my $key (keys %$param) {
        $tmpl->param($key, $param->{$key});
    }
    MediaManager::Util::debug("Finished calling edit_dialog.");
    $app->l10n_filter($tmpl->output);
}

sub create_widget {
    MediaManager::Util::debug("Calling create_widget...");
    my $app = shift;

    my $q       = $app->{query};
    my $blog    = $app->blog;

    my $param = {
	nav_new_item => 1,
        blog_id      => $blog->id,
        blog_name    => $blog->name,
	catalog_loop => _catalog_loop('Blended'),
    };

    $app->add_breadcrumb("Main Menu",$app->{mtscript_url});
    $app->add_breadcrumb($blog->name,$app->{mtscript_url}.'?__mode=menu&blog_id='.$blog->id);
    $app->add_breadcrumb("Media Manager",$app->uri.'?__mode=view&blog_id='.$blog->id);
    $app->add_breadcrumb("Create Widget");
    $param->{breadcrumbs} = $app->{breadcrumbs};
    $param->{breadcrumbs}[-1]{is_last} = 1;

    $param->{blog_name} = $blog->name;

    my $tmpl = $app->init_tmpl('create_widget.tmpl');
    for my $key (keys %$param) {
        $tmpl->param($key, $param->{$key});
    }
    MediaManager::Util::debug("Finished calling create_widget.");
    $app->l10n_filter($tmpl->output);
}

sub save_widget {
    MediaManager::Util::debug("Calling save_widget...");
    my $app = shift;

    my $q           = $app->{query};
    my $blog        = $app->blog;
    my $widget_name = $q->param('widget_name');
    my $sort_type   = $q->param('sort_type');
    my $sort        = $q->param('sort_by');
    my $catalog     = $q->param('catalog');
    my $lastn       = $q->param('lastn');
    my $thumbnail   = $q->param('thumb_size');
    my $tags_str    = $q->param('tags');

    my $tag_delim = chr($app->user->entry_prefs->{tag_delim});
    my @tags = MT::Tag->split($tag_delim, $tags_str);
    require MT::Tag;
    $tags_str = MT::Tag->join(' AND ', @tags);

    my $code = "<div class=\"mediamanager-module\">\n";
    $code = "<h2 class=\"module-header\">$widget_name</h2>\n";
    $code .= "<div class=\"module-content\">\n";

    $code .= "<ul class=\"module-list\">\n<MTMediaManagerItems\n    sort_order=\"$sort_type\"\n    sort_by=\"$sort\"";
    $code .= "\n    catalog=\"$catalog\"" if ($catalog ne '' && $catalog ne 'All');
    $code .= "\n    tags=\"$tags_str\"" if ($tags_str);
    $code .= "\n    lastn=\"$lastn\"" if ($lastn);
    $code .= ">\n";
    $code .= "<li class=\"mediamanager-item module-list-item\">\n";
    $code .= "  <MTAmazonItemLookup ItemId=\"[MTItemASIN]\">\n";
    $code .= "    <MTAmazonImageTag size=\"$thumbnail\"><br />\n" if $thumbnail;
    $code .= "    <a href=\"<\$MTAmazonDetailPageURL\$>\"><\$MTAmazonTitle\$></a>\n";
    $code .= "  </MTAmazonItemLookup>\n";
    $code .= "</li>\n";
    $code .= "</MTMediaManagerItems></div>\n</ul>\n</div>\n";

    require MT::Template;
    my $widget = MT::Template->new;
    $widget->build_dynamic(0);
    $widget->blog_id($blog->id);
    $widget->text($code);
    $widget->name('Widget: ' . $widget_name);
    $widget->type('custom');
    MediaManager::Util::debug("Saving: ". $widget->name);
    $widget->save or
	return $app->error($app->translate(
					   "Populating blog with default templates failed: [_1]",
					   $widget->errstr));

    my $param = {
	nav_new_item => 1,
        blog_id      => $blog->id,
        blog_name    => $blog->name,
	tmpl_code    => $code,
    };

    $app->add_breadcrumb("Main Menu",$app->{mtscript_url});
    $app->add_breadcrumb($blog->name,$app->{mtscript_url}.'?__mode=menu&blog_id='.$blog->id);
    $app->add_breadcrumb("Media Manager",$app->uri.'?__mode=view&blog_id='.$blog->id);
    $app->add_breadcrumb("Create Widget");
    $param->{breadcrumbs} = $app->{breadcrumbs};
    $param->{breadcrumbs}[-1]{is_last} = 1;

    my $tmpl = $app->init_tmpl('widget_created.tmpl');
    for my $key (keys %$param) {
        $tmpl->param($key, $param->{$key});
    }
    MediaManager::Util::debug("Finished calling save_widget.");
    $app->l10n_filter($tmpl->output);
}

sub search {
    MediaManager::Util::debug("Calling search...");
    my $app = shift;
    my $q = $app->{query};
    my $blog = $app->blog;

    my $param = {
	nav_new_item => 1,
        blog_id      => $blog->id,
        blog_name    => $blog->name,
	catalog_loop => _catalog_loop('Blended'),
    };

    $app->add_breadcrumb("Main Menu",$app->{mtscript_url});
    $app->add_breadcrumb($blog->name,$app->{mtscript_url}.'?__mode=menu&blog_id='.$blog->id);
    $app->add_breadcrumb("Media Manager",$app->uri.'?__mode=view&blog_id='.$blog->id);
    $app->add_breadcrumb("Add Item");
    $param->{breadcrumbs} = $app->{breadcrumbs};
    $param->{breadcrumbs}[-1]{is_last} = 1;

    my $tmpl = $app->init_tmpl('add.tmpl');
    for my $key (keys %$param) {
        $tmpl->param($key, $param->{$key});
    }
    $tmpl->param("message",$app->{message}) if $app->{message};
    MediaManager::Util::debug("Finished calling search.");
    $app->l10n_filter($tmpl->output);
}

sub search_results {
    MediaManager::Util::debug("Calling search_results...");
    my $app = shift;
    my $q = $app->{query};

    my $blog_id  = $q->param('blog_id');
    my $keywords = $q->param('kw');
    my $page     = $q->param('page') || 1;
    my $catalog  = $q->param('catalog') || 'Books';

    my $blog = MT::Blog->load($blog_id);

    my @entry_data;
      
    require MTAmazon3::Util;
    my $xml = MTAmazon3::Util::CallAmazon("ItemSearch",$app->{mmanager_cfg},{
	ItemPage      => $page,
	SearchIndex   => $catalog,
	Keywords      => $keywords,
	ResponseGroup => 'Request,Small,Images',
    });
    my $results = XMLin($xml);

    my $n_pages = $results->{Items}->{TotalPages};
    my $n_results = $results->{Items}->{TotalResults};
    my $items = $results->{Items}->{Item};
    my $count = 0;
    $items = [ $items ] if (ref($items) ne "ARRAY");
    foreach my $item (@$items) {
        my $row = {
            blog_id      => $blog_id,
            asin         => $item->{ASIN},
            isbn         => $item->{ISBN},
	    catalog      => $item->{ItemAttributes}->{ProductGroup},
            entry_odd    => $count++ % 2 ? 1 : 0,
            title        => $item->{ItemAttributes}->{Title},
            amzn_attr    => $item->{ItemAttributes},
	    amzn_img_url => MediaManager::Util::format_img_url($item),
	    item_url     => $item->{DetailPageURL},
	    icon         => _gen_icon_url($item->{ItemAttributes}->{ProductGroup}),
	    authors      => ref $item->{ItemAttributes}->{Author} eq "ARRAY"
		? join(", ", @{ $item->{ItemAttributes}->{Author} })
		: $item->{ItemAttributes}->{Author},
	    artists      => ref $item->{ItemAttributes}->{Artist} eq "ARRAY"
	        ? join(", ", @{ $item->{ItemAttributes}->{Artist} })
		: $item->{ItemAttributes}->{Artist},
        };
        # hack, but it fixes a problem when the catalog returned by amazon 
	# is "Book" and not "Books"
	if ($row->{catalog} eq "Book") { $row->{catalog} = "Books"; } 
	MediaManager::Util::debug("Found item in catalog: '".$item->{ItemAttributes}->{ProductGroup}."'");
        push @entry_data, $row;
    }

    my $param = {
	nav_new_item => 1,
        entry_loop   => \@entry_data,
        empty        => !$n_results,
        blog_id      => $blog_id,
        blog_name    => $blog->name,
        page         => $page,
        keywords     => $keywords,
	n_results    => $n_results,
	n_pages      => $n_pages,
    };

    my $limit = 10;
    my $offset = $limit * ($page - 1);
    $param->{return_args} = "__mode=results&blog_id=".$blog->id."&catalog=".$catalog."&kw=".$keywords;
    $param->{list_start} = $offset + 1;
    $param->{list_end}   = $offset + (scalar @entry_data);
    $param->{list_total} = $n_results;
    $param->{next_max}   = $param->{list_total} - $limit;
    $param->{next_max}   = 0 if ($param->{next_max} || 0) < $offset + 1;

    $param->{PREV_OFFSET}     = $offset > 0;
    $param->{prev_offset_val} = $page - 1;
    $param->{next_offset}     = $offset + $limit < $param->{list_total};
    $param->{next_offset_val} = $page + 1;

    $param->{catalog_loop} = _catalog_loop($catalog);

    # paginate
    $param->{paginate}  = $n_pages > 1 ? 1 : 0;

    $app->add_breadcrumb("Main Menu",$app->{mtscript_url});
    $app->add_breadcrumb($blog->name,$app->{mtscript_url}.'?__mode=menu&blog_id='.$blog->id);
    $app->add_breadcrumb("Media Manager",$app->uri.'?__mode=view&blog_id='.$blog->id);
    $app->add_breadcrumb("Search Results");
    $param->{breadcrumbs} = $app->{breadcrumbs};
    $param->{breadcrumbs}[-1]{is_last} = 1;

    $param->{show_all_option} = 0;

    my $tmpl = $app->init_tmpl('search.tmpl');
    for my $key (keys %$param) {
        $tmpl->param($key, $param->{$key});
    }
    MediaManager::Util::debug("Finished calling search_results.");
    $app->l10n_filter($tmpl->output);
}

sub search_lists {
    MediaManager::Util::debug("Calling search_lists...");
    my $app = shift;
    my $q = $app->{query};

    my $blog_id  = $q->param('blog_id');
    my $type     = $q->param('list_type') || 'WishList';
    my $email    = $q->param('email');
    my $fname    = $q->param('fname');
    my $lname    = $q->param('lname');
    my $page     = $q->param('page') || 1;
    my $blog     = MT::Blog->load($blog_id);

    my $args = {
        ListPage      => $page,
        ListType      => $type,
        ResponseGroup => 'Request,ListInfo',
    };
    $args->{Email}     = $email if $email;
    $args->{FirstName} = $fname if $fname;
    $args->{LastName}  = $lname if $lname;

    my @entry_data;
    require MTAmazon3::Util;
    my $xml = MTAmazon3::Util::CallAmazon("ListSearch",
			 $app->{mmanager_cfg},
			 $args);
    use Data::Dumper;
    print STDERR Dumper($xml);
    my $results = XMLin($xml);

    my $n_pages   = $results->{Lists}->{TotalPages};
    my $n_results = $results->{Lists}->{TotalResults};
    my $items     = $results->{Lists}->{List};
    my $count     = 0;
    $items        = [ $items ] if (ref($items) ne "ARRAY");
    foreach my $item (@$items) {
        my $row = {
            blog_id      => $blog_id,
            list_name    => $item->{ListName},
            list_type    => $item->{ListType},
            list_id      => $item->{ListId},
            customer     => $item->{CustomerName},
            list_url     => $item->{ListURL},
        };
        push @entry_data, $row;
    }

    my $param = {
	nav_new_item => 1,
        entry_loop   => \@entry_data,
        empty        => !$n_results,
        blog_id      => $blog_id,
        blog_name    => $blog->name,
        page         => $page,
        email        => $email,
	n_results    => $n_results,
	n_pages      => $n_pages,
    };

    my $limit = 10;
    my $offset = $limit * ($page - 1);
    $param->{return_args} = "__mode=find_list&blog_id=".$blog->id."&list_type=".$type;
    $param->{return_args} .= "&fname=".$fname if $fname;
    $param->{return_args} .= "&lname=".$lname if $lname;
    $param->{return_args} .= "&email=".$email if $email;

    $param->{list_start} = $offset + 1;
    $param->{list_end}   = $offset + (scalar @entry_data);
    $param->{list_total} = $n_results;
    $param->{next_max}   = $param->{list_total} - $limit;
    $param->{next_max}   = 0 if ($param->{next_max} || 0) < $offset + 1;

    $param->{PREV_OFFSET}     = $offset > 0;
    $param->{prev_offset_val} = $page - 1;
    $param->{next_offset}     = $offset + $limit < $param->{list_total};
    $param->{next_offset_val} = $page + 1;

    # paginate
    $param->{paginate}  = $n_pages > 1 ? 1 : 0;

    $app->add_breadcrumb("Main Menu",$app->{mtscript_url});
    $app->add_breadcrumb($blog->name,$app->{mtscript_url}.'?__mode=menu&blog_id='.$blog->id);
    $app->add_breadcrumb("Media Manager",$app->uri.'?__mode=view&blog_id='.$blog->id);
    $app->add_breadcrumb("Search Results");
    $param->{breadcrumbs} = $app->{breadcrumbs};
    $param->{breadcrumbs}[-1]{is_last} = 1;

    $param->{show_all_option} = 0;

    my $tmpl = $app->init_tmpl('search_lists.tmpl');
    for my $key (keys %$param) {
        $tmpl->param($key, $param->{$key});
    }
    MediaManager::Util::debug("Finished calling search_lists.");
    $app->l10n_filter($tmpl->output);
}

sub list_pref; *list_pref = \&MT::App::CMS::list_pref;
sub update_list_prefs; *update_list_prefs = \&MT::App::CMS::update_list_prefs;

#####################################################################
# UTILITY SUBROUTINES
#####################################################################

sub _catalog_loop {
    my ($cat) = @_;
    my @catalogs = qw(DVD Photo Electronics OfficeProducts HealthPersonalCare Toys Baby VideoGames MusicTracks OutdoorLiving Blended MusicalInstruments PetSupplies Magazines DigitalMusic Jewelry Video Tools PCHardware SportingGoods Classical Software Books VHS Wireless Restaurants Music GourmetFood Miscellaneous Kitchen WirelessAccessories Merchants Beauty Apparel);
    my @catalog_data;
    foreach my $c (sort @catalogs) {
	my $phrase = $c;
	$phrase =~ s/([a-z])([A-Z])/\1 \2/g;
	push @catalog_data, {
	    key => $c,
	    name => ($phrase eq 'Blended' ? 'All' : $phrase),
	};
	$catalog_data[-1]{selected} = 1 if ($cat eq $c || ($c eq 'Books' && $cat eq 'Book'));
    }
    return \@catalog_data;
}

sub _gen_icon_url {
    my ($c) = @_;
    my $app = MT->instance;
    my $icon = $app->{cfg}->StaticWebPath . "/plugins/MediaManager/images/icon-" . lc($c) . ".gif";
    $icon =~ s/ //g;
    return $icon;
}

1;
