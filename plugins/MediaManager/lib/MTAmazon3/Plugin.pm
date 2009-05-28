# MTAmazon Movable Type Plugin
#
# Copyright (C) 2006 Byrne Reese

package MTAmazon3::Plugin;

use strict;
use vars qw(@EXPORT_OK @EXPORT);
use base qw( Exporter );
use Exporter;
use MTAmazon3::Util qw(trim readconfig find_cached_item cache_item CallAmazon handle_expressions);

@EXPORT = qw(ItemLookupHelper ItemSearch ListLookup ListSearch);

sub ItemLookupHelper {
    my ($config,$args) = @_;
    my $content_tree;
    my $item;
    require XML::Simple;
    my $p = new XML::Simple;
    if ($item = find_cached_item($args->{'itemid'},$args->{'responsegroup'})) {
	$content_tree = $item->eval_data();
    } else {
	my $content = CallAmazon("ItemLookup",$config,$args);
	eval { $content_tree = $p->XMLin($content); };
	if ($content_tree && $content_tree->{'Error'}) {
	    die "Amazon returned the following error: " .
		$content_tree->{Error}->{Message};
	} elsif ($@) {
	    die "Error reading response from Amazon. It is " .
		"possible that Amazon returned an HTTP Status " .
		"of 500 due to an intermittent problem on their " .
		"end. Here is the content of their response: " .
		$content;
	}
	cache_item($args->{'itemid'},
		   $args->{'responsegroup'},
		   $content_tree);
    }
    return $content_tree;
}

1;

__END__

#<?xml version="1.0" encoding="UTF-8"?>
#<ItemLookupResponse xmlns="http://webservices.amazon.com/AWSECommerceService/2005-10-05">
#  <OperationRequest>
#    <HTTPHeaders>
#      <Header Name="UserAgent" Value="MTAmazon/3.0"></Header>
#    </HTTPHeaders>
#    <RequestId>0WACKY4EYNR9VMZAKZ7Q</RequestId>
#    <Arguments>
#      <Argument Name="Service" Value="AWSECommerceService"></Argument>
#      <Argument Name="AWSAccessKeyId" Value="1FNQS2WS91241WGETX82"></Argument>
#      <Argument Name="ItemId" Value="B00005JNOG"></Argument>
#      <Argument Name="Operation" Value="ItemLookup"></Argument>
#    </Arguments>
#    <RequestProcessingTime>0.00972390174865723</RequestProcessingTime>
#  </OperationRequest>
#  <Items>
#    <Request>
#      <IsValid>True</IsValid>
#      <ItemLookupRequest>
#        <ItemId>B00005JNOG</ItemId>
#      </ItemLookupRequest>
#    </Request>
#    <Item>
#      <ASIN>B00005JNOG</ASIN>
#      <DetailPageURL>...</DetailPageURL>
#      <SmallImage>
#        <URL>http://images.amazon.com/images/P/B00005JNOG.01._SCTHUMBZZZ_.jpg</URL>
#        <Height Units="pixels">75</Height>
#        <Width Units="pixels">53</Width>
#      </SmallImage>
#      <MediumImage>
#        <URL>http://images.amazon.com/images/P/B00005JNOG.01._SCMZZZZZZZ_.jpg</URL>
#        <Height Units="pixels">160</Height>
#        <Width Units="pixels">113</Width>
#      </MediumImage>
#      <LargeImage>
#        <URL>http://images.amazon.com/images/P/B00005JNOG.01._SCLZZZZZZZ_.jpg</URL>
#         <Height Units="pixels">500</Height>
#        <Width Units="pixels">353</Width>
#      </LargeImage>
#      <ImageSets>
#        <ImageSet Category="primary">
#          <SmallImage>
#            <URL>http://images.amazon.com/images/P/B00005JNOG.01._SCTHUMBZZZ_.jpg</URL>
#            <Height Units="pixels">75</Height>
#            <Width Units="pixels">53</Width>
#          </SmallImage>
#          <MediumImage>
#            <URL>http://images.amazon.com/images/P/B00005JNOG.01._SCMZZZZZZZ_.jpg</URL>
#            <Height Units="pixels">160</Height>
#            <Width Units="pixels">113</Width>
#          </MediumImage>
#          <LargeImage>
#            <URL>http://images.amazon.com/images/P/B00005JNOG.01._SCLZZZZZZZ_.jpg</URL>
#            <Height Units="pixels">500</Height>
#            <Width Units="pixels">353</Width>
#          </LargeImage>
#        </ImageSet>
#      </ImageSets>
#      <OfferSummary>
#        <LowestNewPrice>
#          <Amount>1249</Amount>
#          <CurrencyCode>USD</CurrencyCode>
#          <FormattedPrice>$12.49</FormattedPrice>
#        </LowestNewPrice>
#        <LowestUsedPrice>
#          <Amount>1043</Amount>
#          <CurrencyCode>USD</CurrencyCode>
#          <FormattedPrice>$10.43</FormattedPrice>
#        </LowestUsedPrice>
#        <LowestCollectiblePrice>
#          <Amount>1465</Amount>
#          <CurrencyCode>USD</CurrencyCode>
#          <FormattedPrice>$14.65</FormattedPrice>
#        </LowestCollectiblePrice>
#        <TotalNew>60</TotalNew>
#        <TotalUsed>58</TotalUsed>
#        <TotalCollectible>10</TotalCollectible>
#        <TotalRefurbished>0</TotalRefurbished>
#      </OfferSummary>
#      <Offers>
#        <TotalOffers>1</TotalOffers>
#        <TotalOfferPages>1</TotalOfferPages>
#        <Offer>
#          <Merchant>
#            <MerchantId>ATVPDKIKX0DER</MerchantId>
#            <GlancePage>http://www.amazon.com/gp/help/...</GlancePage>
#          </Merchant>
#          <OfferAttributes>
#            <Condition>New</Condition>
#          </OfferAttributes>
#          <OfferListing>
#            <OfferListingId>...</OfferListingId>
#            <Price>
#              <Amount>1798</Amount>
#              <CurrencyCode>USD</CurrencyCode>
#              <FormattedPrice>$17.98</FormattedPrice>
#            </Price>
#            <Availability>Usually ships in 24 hours</Availability>
#            <IsEligibleForSuperSaverShipping>1</IsEligibleForSuperSaverShipping>
#          </OfferListing>
#        </Offer>
#      </Offers>
#      <ItemAttributes>
#        <Director>Greg Yaitanes</Director>
#        <Director>Tucker Gates</Director>
#        <Director>Michael Zinberg</Director>
#        <Director>J.J. Abrams</Director>
#        <Director>Marita Grabiak</Director>
#        <Director>Alan Taylor</Director>
#        <ProductGroup>DVD</ProductGroup>
#        <Title>Lost - The Complete First Season</Title>
#      </ItemAttributes>
#    </Item>
#  </Items>
#</ItemLookupResponse>


<Item>
  <ASIN>B00005JLXH</ASIN>
</Item>
