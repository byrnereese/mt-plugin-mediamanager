# -*- perl -*-
# !!! DO NOT EDIT !!!
# This file was automatically generated.
package Net::Amazon::Validate::Type::ItemLookup;

use 5.006;
use strict;
use warnings;

use constant RESPONSEGROUP_VALID_VALUES => {
    'Accessories' => 1,
    'AlternateVersions' => 1,
    'BrowseNodes' => 1,
    'Collections' => 1,
    'EditorialReview' => 1,
    'Images' => 1,
    'ItemAttributes' => 1,
    'ItemIds' => 1,
    'Large' => 1,
    'ListmaniaLists' => 1,
    'Medium' => 1,
    'MerchantItemAttributes' => 1,
    'OfferFull' => 1,
    'OfferListings' => 1,
    'OfferSummary' => 1,
    'Offers' => 1,
    'PromotionDetails' => 1,
    'PromotionSummary' => 1,
    'RelatedItems' => 1,
    'Reviews' => 1,
    'SalesRank' => 1,
    'Similarities' => 1,
    'Small' => 1,
    'Subjects' => 1,
    'TaggedGuides' => 1,
    'TaggedItems' => 1,
    'TaggedListmaniaLists' => 1,
    'Tags' => 1,
    'TagsSummary' => 1,
    'Tracks' => 1,
    'VariationImages' => 1,
    'VariationMatrix' => 1,
    'VariationMinimum' => 1,
    'VariationOffers' => 1,
    'VariationSummary' => 1,
    'Variations' => 1,
};

sub new {
    my ($class , %options) = @_;
    my $self = {
        %options,
    };
    bless $self, $class;
}

sub assert {
    my ($self, $value, $name, $href) = @_;
    die "Unknown type in Net::Amazon::Request constructor: $value" unless defined $href->{$value};
}

sub validate {
    my ($self, $value, $name, $href) = @_;
    if ( ref ($value) eq 'ARRAY' ) {
        $self->assert($_, $name, $href) for (@$value);
    } else {
        $self->assert($value, $name, $href);
    }
}

sub ResponseGroup {
    my ($self, $value) = @_;
    $self->validate($value, "ResponseGroup", (RESPONSEGROUP_VALID_VALUES));
}

1;
