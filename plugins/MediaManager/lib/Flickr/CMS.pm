# Media Manager Movable Type Plugin
# This software is licensed under the GPL
# Copyright (C) 2005-2007, Six Apart, Ltd.

package Flickr::CMS;

use strict;
use base qw( MT::App );

sub plugin {
    return MT->component('MediaManagerFlickr');
}

use MT::Util qw( format_ts offset_time_list encode_url );
use MT::ConfigMgr;
use XML::Simple;

sub id { 'flickr_cms' }

sub init {
    my $app = shift;
    my %param = @_;
    return $app->error($@) if $@;
    $app;
}

sub _get_auth_url {
    use Flickr::API;
    my $api = new Flickr::API({
	'key'    => _creds()->{flickr_apikey},
	'secret' => _creds()->{flickr_secret},
    });
    return $api->request_auth_url('read');
}

sub trim {
    my($string)=@_;
    for ($string) {
	s/^\s+//;
	s/\s+$//;
    }
    return $string;
}

sub _creds {
    my $config = MT::Request->instance->stash('FlickrConfig');
    return $config if (defined($config));
    my $sys_config = plugin()->get_config_hash('system');
    foreach my $key (keys %$sys_config) {
	if (defined($sys_config->{$key} && $sys_config->{$key} ne '')) {
	    $config->{$key} = trim($sys_config->{$key});
	}
    }
    MT::Request->instance->stash('FlickrConfig', $config);
    return $config;
}

sub auth {
    my $app = shift;
    my $q = $app->{query};
    my $tmpl = $app->load_tmpl('flickr/auth.tmpl');

    my $token = $app->user->flickr_auth_token();
    # if user is already authed, display them a message to that effect. allow them to renew auth token
    # TODO - check token

    $tmpl->param( auth_url => _get_auth_url() );
    $tmpl->param( token => $token );
    return $app->build_page($tmpl);
}

sub authed {
    my $app = shift;
    my $q = $app->{query};
    my $tmpl = $app->load_tmpl('flickr/auth.tmpl');

    my $frob = $q->param('frob');

    use Flickr::API;
    use Flickr::API::Request;
    my $api = new Flickr::API({
	'key'    => _creds()->{flickr_apikey},
	'secret' => _creds()->{flickr_secret},
    });
    my $request = new Flickr::API::Request({
	'method' => 'flickr.auth.getToken',
	'args' => { frob => $frob },
    });
    my $r = $api->execute_request($request);
    require XML::Simple;
    my $xml = $r->content;
    my $response = XMLin($xml);

    if ($r->{success}) {  
	my $token   = $response->{auth}->{token};
	my $user_id = $response->{auth}->{user}->{nsid};
	$tmpl->param( token => $token );
	$app->user->flickr_auth_token($token);
	$app->user->flickr_user_id($user_id);
	$app->user->save;
    }

    $tmpl->param( auth_url => _get_auth_url() );
    $tmpl->param( frob => $frob );
    return $app->build_page($tmpl);
}

# This handler is responsible for displaying the initial search form
# so that a user can search amazon.
sub find {
    my $app = shift;
    my $q = $app->{query};
    my $blog = $app->blog;
    my $tmpl = $app->load_tmpl('flickr/dialog/find.tmpl');

    my $token = $app->user->flickr_auth_token();
    if ($token) {
	use Flickr::API;
	use Flickr::API::Request;
	my $api = new Flickr::API({
	    'key'    => _creds()->{flickr_apikey},
	    'secret' => _creds()->{flickr_secret},
	});
	my $request = new Flickr::API::Request({
	    'method' => 'flickr.photos.search',
	    'args' => { 'user_id' => $app->user->flickr_user_id() },
	});
	my $r = $api->execute_request($request);
	use Data::Dumper;
	print STDERR Dumper($r);
	if ($r->{success}) {  
	    require XML::Simple;
	    my $xml = $r->content;
	    my $response = XMLin($xml);
	    my $photos = $response->{photos}->{photo};
	    my @photo_data;
	    foreach my $key (reverse sort keys %$photos) {
		my $p = $photos->{$key};
		my $thumb = 'http://farm' . $p->{farm} . '.static.flickr.com/'.$p->{server}.'/'.$key.'_'.$p->{secret}.'_t.jpg';
		my $row = {
		    blog_id      => $blog->id,
		    photo_id     => $key,
		    title        => $p->{title},
		    thumbnail    => $thumb,
		};
		push @photo_data, $row;
	    }
	    $tmpl->param(entry_loop => \@photo_data);
	}
    } else {
	# no token display message
    }

    $tmpl->param(blog_id => $blog->id);
    return $app->build_page($tmpl);
}

sub _get_photo_info {
    my ($photo_id) = @_;

    use Flickr::API;
    use Flickr::API::Request;
    my $api = new Flickr::API({
	'key'    => _creds()->{flickr_apikey},
	'secret' => _creds()->{flickr_secret},
    });
    my $request = new Flickr::API::Request({
	'method' => 'flickr.photos.getInfo',
	'args' => { 'photo_id' => $photo_id },
    });
    my $r = $api->execute_request($request);
    if ($r->{success}) {  
	require XML::Simple;
	my $xml = $r->content;
	my $response = XMLin($xml);
	return $response->{photo};
    }
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
    my $pid = $q->param('selected');

    my $photo = _get_photo_info( $pid );

    my $title = $photo->{title};
    require MT::Asset::Flickr;
    my $asset = MT::Asset::Flickr->new;
    $asset->blog_id($q->param('blog_id'));
    $asset->photo_id($pid);
    $asset->label($title);
    $asset->url('http://www.flickr.com/photos/'.$photo->{owner}.'/'.$pid);
    $asset->photo_id($pid);
    $asset->photo_server($photo->{server});
    $asset->photo_farm($photo->{farm});
    $asset->photo_secret($photo->{secret});
    $asset->photo_owner($photo->{owner});
    $asset->photo_is_public($photo->{ispublic});
    $asset->original_title($title);

    $asset->created_by( $app->user->id );

    $asset->original_title($title);

    my $original = $asset->clone;
    $asset->save;
    $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

    return $app->complete_insert( 
        asset       => $asset,
        photo_id    => $pid,
#        title       => $title,
        description => $asset->description,
	thumbnail   => $asset->thumbnail_url,
	is_youtube  => 1,
    );
}

1;

__END__
