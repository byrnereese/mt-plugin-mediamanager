# Media Manager Movable Type Plugin
# This software is licensed under the GPL
# Copyright (C) 2005-2007, Six Apart, Ltd.

package MediaManager::CMS;

use strict;
use base qw( MT::App );

sub plugin {
    return MT->component('MediaManager');
}

use MT::Util qw( format_ts offset_time_list );
use MT::ConfigMgr;
use MediaManager::Entry;
use MediaManager::Util;
use XML::Simple;

sub id { 'mediamanager_cms' }

sub init {
    my $app = shift;
    my %param = @_;
#    $app->SUPER::init(%param) or return;
    require MTAmazon3::Util;
    eval {
	$app->{mmanager_cfg} = MTAmazon3::Util::readconfig($app->{query}->param('blog_id'));
    };
    return $app->error($@) if $@;
    $app;
}

# Dialog Flow:
# 1) Search form (find)
# 2) Search results (find_results)
# 3) Asset Options (asset_options)
# If "insert into post" then 4a) Insert Options (insert_options)
# Else 4b) DO INSERT

# This handler is responsible for displaying the initial search form
# so that a user can search amazon.
sub find {
    my $app = shift;
    my $q = $app->{query};
    my $blog = $app->blog;
    my $tmpl = $app->load_tmpl('amazon/dialog/find.tmpl');
    $tmpl->param(blog_id      => $blog->id);
    $tmpl->param(catalog_loop => _catalog_loop('Blended'));
    $tmpl->param(breadcrumbs  => $app->{breadcrumbs});
    return $app->build_page($tmpl);
}

# This handler is responsible for displaying a list of search results.
# The user will select an item in this list and then select continue, taking
# them to a screen to tag the item, rename the item, etc.
sub find_results {
    my $app = shift;
    init($app);

    my $q = $app->{query};
    my $blog = $app->blog;

    my $blog_id  = $q->param('blog_id');
    my $keywords = $q->param('kw');
    my $page     = $q->param('page') || 1;
    my $catalog  = $q->param('catalog') || 'Books';

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
	    amzn_img_url => MediaManager::Util::format_img_url($item,'Medium'),
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
        push @entry_data, $row;
    }

    my $tmpl = $app->load_tmpl('amazon/dialog/find_results.tmpl');

    my $limit = 10;
    my $offset = $limit * ($page - 1);
    $tmpl->param(return_args => "__mode=results&blog_id=".$blog->id."&catalog=".$catalog."&kw=".$keywords);
    $tmpl->param(list_start => $offset + 1);
    $tmpl->param(list_end => $offset + (scalar @entry_data));
    $tmpl->param(list_total => $n_results);
    $tmpl->param(next_max => ($tmpl->param('list_total') - $limit));
    $tmpl->param(next_max => (($tmpl->param('next_max') || 0) < $offset + 1) ? 0 : 1);
    $tmpl->param(PREV_OFFSET => $offset > 0);
    $tmpl->param(prev_offset_val => $page - 1);
    $tmpl->param(next_offset => $offset + $limit < $tmpl->param('list_total'));
    $tmpl->param(next_offset_val => $page + 1);

    $tmpl->param(blog_id => $blog->id);
    $tmpl->param(blog_name => $blog->name);
    $tmpl->param(entry_loop => \@entry_data);
    $tmpl->param(empty => !$n_results);
    $tmpl->param(page => $page);
    $tmpl->param(paginate => $n_pages > 1 ? 1 : 0);
    $tmpl->param(keywords => $keywords);
    $tmpl->param(n_results => $n_results);
    $tmpl->param(n_pages => $n_pages);
    $tmpl->param(show_all_options => 0);

    $tmpl->param(breadcrumbs  => $app->{breadcrumbs});

    return $app->build_page($tmpl);
}

# This handler is responsible for saving the asset and also for presenting
# the user with a list of options for inserting it into a post.
# Saving however should take place one step earlier because a user may
# decide NOT to insert it into a post.
sub asset_options {
    my $app = shift;
    init($app);
    my $q = $app->{query};
    my $blog = $app->blog;
    my $asin = $q->param('selected');

    my $content_tree;
    eval {
	require MTAmazon3::Plugin;
	$content_tree = MTAmazon3::Plugin::ItemLookupHelper(
            $app->{mmanager_cfg},{
		itemid => $asin,
		responsegroup => 'Small,Images,OfferSummary',
	    });
    };
    if ($@) {
	return $app->error($@);
    }
    my $item = $content_tree->{'Items'}->{'Item'};

    require MT::Asset::Amazon;
    my $asset = MT::Asset::Amazon->new;
    $asset->blog_id($q->param('blog_id'));
    $asset->label($q->param('label'));
    $asset->url($item->{DetailPageURL});
    $asset->created_by( $app->user->id );

    $asset->asin($asin);
    $asset->product_group($item->{ItemAttributes}->{ProductGroup});
    $asset->original_title($item->{ItemAttributes}->{Title});

    if ($item->{ItemAttributes}->{Author}) {
	$asset->artist(ref $item->{ItemAttributes}->{Author} eq "ARRAY"
			? join(", ", @{ $item->{ItemAttributes}->{Author} })
			: $item->{ItemAttributes}->{Author});
    } elsif ($item->{ItemAttributes}->{Artist}) {
	$asset->artist(ref $item->{ItemAttributes}->{Artist} eq "ARRAY"
			? join(", ", @{ $item->{ItemAttributes}->{Artist} })
			: $item->{ItemAttributes}->{Artist});
    }

    my $original = $asset->clone;
    $asset->save;
    $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

    return $app->complete_insert( 
        asset => $asset,
        asin => $asin,
	thumbnail => $asset->thumbnail_url,
    );
}

#####################################################################
# UTILITY SUBROUTINES
#####################################################################

sub _catalog_loop {
    my ($cat) = @_;
    my @catalogs = qw(DVD Photo Electronics OfficeProducts HealthPersonalCare Toys Baby VideoGames MusicTracks OutdoorLiving Blended MusicalInstruments PetSupplies Magazines DigitalMusic Jewelry Video Tools PCHardware SportingGoods Classical Software Books VHS Wireless Restaurants Music GourmetFood Miscellaneous Kitchen WirelessAccessories Merchants Beauty Apparel);
    my @catalog_data;
    foreach my $c (sort @catalogs) {
	my $phrase = $c;
	$phrase =~ s/([a-z])([A-Z])/$1 $2/g;
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
__END__
