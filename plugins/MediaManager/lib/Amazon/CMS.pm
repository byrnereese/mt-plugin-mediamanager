# This software is licensed under the GPL
# Copyright (C) 2005-2007, Six Apart, Ltd.
# Copyright (C) 2009, Byrne Reese.

package Amazon::CMS;

use strict;
use base qw( MT::App );
use Amazon::Util qw(readconfig);

sub clear_cache {
    my $app = shift;
    my $q = $app->{query};
    my $blog = $app->blog;
    my $tmpl = $app->load_tmpl('amazon/clear_cache.tmpl');

    my $config = readconfig( $app->blog->id );

    require Cache::File;
    my $cache = Cache::File->new(
        cache_root        => $config->{cache_path},
        namespace         => 'MTAmazon',
        );
    $cache->clear();

    return $app->build_page($tmpl);
}

1;
