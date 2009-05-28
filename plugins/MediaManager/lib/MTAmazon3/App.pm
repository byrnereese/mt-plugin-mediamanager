package MTAmazon3::App;

use strict;
@MTAmazon3::App::ISA = qw( MT::App );

use MT::App;
use MT::App::CMS;
use MT::ConfigMgr;
use MT::Template;
use MT::Blog;

use MTAmazon3::Item;
use MTAmazon3::Util;

sub init {
    my $app = shift;
    my %param = @_;
    $app->SUPER::init(%param) or return;

    $app->add_methods(
            'init' => \&initialize_plugin,
	    'clear_cache' => \&clear_cache,
    );

    $app->{default_mode}   = 'init';
    $app->{requires_login} = 1;
    $app;
}

sub clear_cache {
    my $app = shift;
    my $tmpl = $app->init_tmpl('clear_cache.tmpl');
    require MTAmazon3::Item;
    MTAmazon3::Item->remove_all;
    $app->l10n_filter($tmpl->output);
}

sub initialize_plugin {
    my $app = shift;
    my $tmpl = $app->init_tmpl('init.tmpl');
    $tmpl->param('blog_id'  => $app->{query}->param('blog_id'));

    require MTAmazon3::Item;
    my $diff = $app->repair_class("MTAmazon3::Item");

    $tmpl->param('diff' => $diff);

    $app->add_breadcrumb("Main Menu",$app->{mtscript_url});
    $app->add_breadcrumb("MTAmazon Initialization");

    $app->{breadcrumbs}[-1]{is_last} = 1;
    $tmpl->param(breadcrumbs    => $app->{breadcrumbs});
    $tmpl->param(plugin_version => $MT::Plugin::MTAmazon3::VERSION);

    $app->l10n_filter($tmpl->output);
}

sub repair_class {
    my $app = shift;
    my ($class) = @_;
    require MT::Upgrade;
    my $driver = MT::Object->driver;
    my $diff = MT::Upgrade->class_diff($class);
    print STDERR "diff=$diff\n";
    if ($diff) {
        my @stmt;
        if ($diff->{fix}) {
            @stmt = $driver->fix_class($class);
        } else {
            if ($diff->{add}) {
                push @stmt, $driver->add_column($class, $_->{name})
                    foreach @{$diff->{add}};
            }
            if ($diff->{alter}) {
                push @stmt, $driver->alter_column($class, $_->{name})
                    foreach @{$diff->{alter}};
            }
            if ($diff->{drop}) {
                push @stmt, $driver->drop_column($class, $_->{name})
                    foreach @{$diff->{drop}};
            }
        }
        if (@stmt) {
            $driver->sql(\@stmt) or return $app->error($driver->errstr);
        }
    }
    return $diff;
}

sub init_tmpl {
    my $app = shift;
    MTAmazon3::Util::debug("Initializing template file.","  >");
    MTAmazon3::Util::debug("Calling MT::App::load_tmpl(".join(", ",@_).")","    >");
    my $tmpl = $app->load_tmpl(@_);
    if (!$tmpl) {
	my $err = $app->translate("Loading template '[_1]' ".
				  "failed: [_2]",
				  $_[0], $@);
	MTAmazon3::Util::debug($err,"    >");
	return $app->error($err);
    } else {
	MTAmazon3::Util::debug("Template file successfully loaded.","    >");
    }

    $tmpl->param(plugin_name       => "MTAmazon");
    $tmpl->param(plugin_version    => $MTAmazon3::VERSION);
    $tmpl->param(plugin_author     => "Byrne Reese");
    $tmpl->param(page_titles       => [ reverse @{ $app->{breadcrumbs} } ]);

    return $tmpl;
}

1;
