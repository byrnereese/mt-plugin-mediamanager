# This software is licensed under the GPL
# Copyright (C) 2005-2007, Six Apart, Ltd.

package MTAmazon3::CMS;

use strict;
use base qw( MT::App );

sub plugin {
    return MT->component('MTAmazon');
}

sub clear_cache {
    my $app = shift;
    my $q = $app->{query};
    my $blog = $app->blog;
    my $tmpl = $app->load_tmpl('amazon/clear_cache.tmpl');
    require MTAmazon3::Item;
    MTAmazon3::Item->remove_all;
    return $app->build_page($tmpl);
}

1;
