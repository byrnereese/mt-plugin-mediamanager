package MediaManager::Upgrade;

use MT::Asset::Amazon;
use Amazon::Util qw(trim readconfig handle_expressions);

sub core_upgrade_functions {
    return {
        # < 2.0
#        'convert_status_to_tag' => {
#            version_limit => 2.0,
#            priority => 1,
#            updater => {
#                type => 'entry',
#                label => 'Converting statii into tags...',
#                code => sub {
#		    require MediaManager::Entry;
#		    my %terms;
#		    my %options;
#		    my $iter = MediaManager::Entry->load_iter( 
#							       \%terms,
#							       \%options,
#							       );
#		    
#		    while (my $entry = $iter->()) {
#			my @tags = ( $entry->status );
#			$entry->add_tags(@tags);
#			$entry->save;
#		    }
#                },
#            },
#	},
#        'convert_mm_entries' => {
#            version_limit => 3.03,
#            priority => 1,
#            updater => {
#                type => 'entry',
#                label => 'Migrating Media Manager entries to assets...',
#                code => sub {
#		    require MediaManager::Entry;
#		    require Amazon::Plugin;
#		    my $a = MT::Asset::Amazon->new;
#
#		    my %terms;
#		    my %options;
#		    my $iter = MediaManager::Entry->load_iter( 
#							       \%terms,
#							       \%options,
#							       );
#		    my @failures;
#		    while (my $entry = $iter->()) {
#			my $content_tree;
#			my $config = readconfig($entry->blog_id);
#			eval {
#			    require Amazon::Plugin;
#			    $content_tree = Amazon::Plugin::ItemLookupHelper(
#										$config,{
#										    itemid => $entry->isbn,
#										    responsegroup => 'Small,Images,OfferSummary',
#										});
#			};
#			if ($@) {
#			    push @failures,$entry->isbn;
#			    next;
#			}
#			my $item = $content_tree->{'Items'}->{'Item'};
#			my $a = MT::Asset::Amazon->new;
#
#			$a->label($entry->title);
#			$a->created_on($entry->created_on);
#			$a->created_by($entry->created_by);
#			$a->blog_id($entry->blog_id);
#			$a->asin($entry->isbn);
#
#			$a->url($item->{DetailPageURL});
#			$a->product_group($item->{ItemAttributes}->{ProductGroup});
#			$a->original_title($item->{ItemAttributes}->{Title});
#			$a->add_tags($entry->tags);
#			if ($item->{ItemAttributes}->{Author}) {
#			    $a->artist(ref $item->{ItemAttributes}->{Author} eq "ARRAY"
#					   ? join(", ", @{ $item->{ItemAttributes}->{Author} })
#					   : $item->{ItemAttributes}->{Author});
#			} elsif ($item->{ItemAttributes}->{Artist}) {
#			    $a->artist(ref $item->{ItemAttributes}->{Artist} eq "ARRAY"
#					   ? join(", ", @{ $item->{ItemAttributes}->{Artist} })
#					   : $item->{ItemAttributes}->{Artist});
#			}
#
#			$a->save;
#		    }
#		},
#	    },
#        },
    };
}

1;
